-- =============================================================================
--  MojZEV — funkcionalni smoke test
-- =============================================================================
--  Pokriva: mjesečni obračun, uplatnice (QR + poziv na broj), append-only
--  knjigu, težinsko glasanje, zatvaranje glasanja, tajnost glasačkog listića,
--  RLS izolaciju između zgrada i zaštitu od eskalacije privilegija.
--
--  Pokretanje uz Supabase:
--      supabase db reset
--      psql "$DATABASE_URL" -f supabase/tests/01_smoke_test.sql
--
--  Pokretanje na golom PostgreSQL-u:
--      psql zevtest -f supabase/tests/00_supabase_stub.sql
--      psql zevtest -f schema.sql
--      psql zevtest -f supabase/tests/01_smoke_test.sql
--
--  Skripta puca sa greškom ako ijedna tvrdnja padne, pa je bezbjedno
--  koristiti je direktno u CI-ju.
-- =============================================================================

\set ON_ERROR_STOP on
\pset pager off
\timing off

-- --- Infrastruktura za tvrdnje ----------------------------------------------

create temporary table _rezultati (
  redni   serial primary key,
  opis    text,
  prosao  boolean,
  detalj  text
);

-- Dio testova se izvršava pod rolom `authenticated` (provjera RLS-a), pa
-- tabela rezultata mora biti upisiva i za nju.
grant all on _rezultati to public;
grant all on sequence _rezultati_redni_seq to public;

create or replace function pg_temp.tvrdi(
  p_opis   text,
  p_uslov  boolean,
  p_detalj text default null
) returns void
language plpgsql
as $$
begin
  insert into _rezultati (opis, prosao, detalj)
  values (p_opis, coalesce(p_uslov, false), p_detalj);

  if coalesce(p_uslov, false) then
    raise notice '  OK    %  %', rpad(p_opis, 54), coalesce(p_detalj, '');
  else
    raise warning '  PAO   %  %', rpad(p_opis, 54), coalesce(p_detalj, '');
  end if;
end;
$$;

-- Fiksni UUID-ovi radi predvidljivosti.
\set pred    '11111111-1111-1111-1111-111111111111'
\set st1     '22222222-2222-2222-2222-222222222222'
\set st2     '33333333-3333-3333-3333-333333333333'
\set stranac '44444444-4444-4444-4444-444444444444'
\set zgA     'aaaaaaaa-0000-0000-0000-000000000001'
\set zgB     'bbbbbbbb-0000-0000-0000-000000000002'
\set stanA1  'cccccccc-0000-0000-0000-000000000001'
\set stanA2  'cccccccc-0000-0000-0000-000000000002'
\set stanA3  'cccccccc-0000-0000-0000-000000000003'
\set stanB1  'dddddddd-0000-0000-0000-000000000001'
\set glas1   'eeeeeeee-0000-0000-0000-000000000001'
\set tajno_g 'eeeeeeee-0000-0000-0000-000000000002'

-- Rezultati upita se prigušuju: tvrdnje se ispisuju kroz NOTICE/WARNING
-- (stderr), pa je izlaz čitljiv. Sažetak na kraju vraća ispis.
\o /dev/null

\echo ''
\echo '=== PRIPREMA ================================================'

-- --- 1. Korisnici (simulira Supabase Auth registraciju) ---------------------

insert into auth.users (id, email, raw_user_meta_data) values
  (:'pred',    'predsjednik@test.ba', '{"ime":"Amir","prezime":"Hadzic"}'),
  (:'st1',     'stanar1@test.ba',     '{"ime":"Lejla","prezime":"Begic"}'),
  (:'st2',     'stanar2@test.ba',     '{"ime":"Marko","prezime":"Ilic"}'),
  (:'stranac', 'stranac@test.ba',     '{"ime":"Neko","prezime":"Drugi"}');

select pg_temp.tvrdi(
  '01 profil se kreira trigerom pri registraciji',
  (select count(*) from public.korisnici) = 4
);

-- --- 2. Dvije zgrade (druga služi za provjeru izolacije) --------------------

insert into public.zgrade (id, naziv, kod, ulica, broj, grad, iban, naziv_primaoca,
                           fiksna_naknada, naknada_po_m2, dan_dospijeca)
values (:'zgA', 'ZEV Titova 15', 'ZEV-1001', 'Titova', '15', 'Sarajevo',
        'BA391290079401028494', 'ZEV Titova 15', 5.00, 0.35, 15);

insert into public.zgrade (id, naziv, kod, ulica, broj, grad, iban,
                           fiksna_naknada, naknada_po_m2)
values (:'zgB', 'ZEV Zmaja 4', 'ZEV-2002', 'Zmaja od Bosne', '4', 'Sarajevo',
        'BA391290079401099999', 10.00, 0.00);

-- --- 3. Stanovi -------------------------------------------------------------

insert into public.stanovi (id, zgrada_id, oznaka, sprat, kvadratura, suvlasnicki_udio) values
  (:'stanA1', :'zgA', '1', 1,  60.00,  60),
  (:'stanA2', :'zgA', '2', 1,  40.00,  40),
  (:'stanA3', :'zgA', '3', 2, 100.00, 100);
insert into public.stanovi (id, zgrada_id, oznaka, kvadratura) values
  (:'stanB1', :'zgB', '1', 50.00);

-- --- 4. Članstva ------------------------------------------------------------

insert into public.clanstva (korisnik_id, zgrada_id, stan_id, uloga_id) values
  (:'pred',    :'zgA', :'stanA1', 10),   -- predsjednik zgrade A
  (:'st1',     :'zgA', :'stanA2', 50),   -- vlasnik
  (:'st2',     :'zgA', :'stanA3', 50),   -- vlasnik
  (:'stranac', :'zgB', :'stanB1', 10);   -- predsjednik DRUGE zgrade

-- --- 5. Kompozitni FK sprječava miješanje tenanta ---------------------------

do $$
begin
  -- Stan iz zgrade B ne smije se vezati za članstvo u zgradi A.
  insert into public.clanstva (korisnik_id, zgrada_id, stan_id, uloga_id)
  values ('11111111-1111-1111-1111-111111111111',
          'aaaaaaaa-0000-0000-0000-000000000001',
          'dddddddd-0000-0000-0000-000000000001', 50);
  perform pg_temp.tvrdi('02 kompozitni FK cuva granicu tenanta', false,
                        'stan zgrade B vezan za clanstvo u zgradi A!');
exception when foreign_key_violation then
  perform pg_temp.tvrdi('02 kompozitni FK cuva granicu tenanta', true);
end $$;

\echo ''
\echo '=== FINANSIJE =============================================='

reset role;
select set_config('test.uid', :'pred', false);

select pg_temp.tvrdi(
  '03 mjesecni obracun kreira zaduzenje za svaki prostor',
  public.fn_obracunaj_mjesec(:'zgA', '2026-08-01') = 3
);

select pg_temp.tvrdi(
  '04 obracun je idempotentan (ponovni poziv ne duplira)',
  public.fn_obracunaj_mjesec(:'zgA', '2026-08-01') = 0
);

-- 5 KM fiksno + 0,35 KM/m² × 60 m² = 26,00 KM
select pg_temp.tvrdi(
  '05 iznos naknade po formuli zgrade',
  iznos = 26.00,
  'iznos = ' || iznos || ' KM'
) from public.transakcije_uplatnice
 where stan_id = :'stanA1' and tip = 'zaduzenje';

select pg_temp.tvrdi(
  '06 poziv na broj i QR payload su generisani',
  poziv_na_broj is not null and qr_sadrzaj like 'BCD%',
  'pnb = ' || poziv_na_broj
) from public.transakcije_uplatnice
 where stan_id = :'stanA1' and tip = 'zaduzenje';

select pg_temp.tvrdi(
  '07 poziv na broj prolazi provjeru po modelu 97',
  public.fn_provjeri_poziv_na_broj(poziv_na_broj)
) from public.transakcije_uplatnice
 where stan_id = :'stanA1' and tip = 'zaduzenje';

select pg_temp.tvrdi(
  '08 neispravan poziv na broj se odbacuje',
  not public.fn_provjeri_poziv_na_broj('00ZEV10012026081')
);

insert into public.transakcije_uplatnice (zgrada_id, stan_id, tip, iznos, opis, datum_uplate)
values (:'zgA', :'stanA1', 'uplata', 20.00, 'Uplata na blagajni', current_date);

select pg_temp.tvrdi(
  '09 saldo = zaduzenje 26 - uplata 20 = 6',
  public.fn_saldo_stana(:'stanA1') = 6.00,
  'saldo = ' || public.fn_saldo_stana(:'stanA1')
);

-- Append-only: izmjena iznosa knjižene stavke mora pući.
do $$
begin
  update public.transakcije_uplatnice set iznos = 999
   where stan_id = 'cccccccc-0000-0000-0000-000000000001' and tip = 'zaduzenje';
  perform pg_temp.tvrdi('10 knjiga je append-only (izmjena iznosa)', false,
                        'izmjena je prosla!');
exception when integrity_constraint_violation then
  perform pg_temp.tvrdi('10 knjiga je append-only (izmjena iznosa)', true);
end $$;

-- Storno mora pokazivati na original.
do $$
begin
  insert into public.transakcije_uplatnice (zgrada_id, stan_id, tip, iznos, opis)
  values ('aaaaaaaa-0000-0000-0000-000000000001',
          'cccccccc-0000-0000-0000-000000000001', 'storno', 10.00, 'Storno bez veze');
  perform pg_temp.tvrdi('11 storno bez veze na original se odbija', false);
exception when check_violation then
  perform pg_temp.tvrdi('11 storno bez veze na original se odbija', true);
end $$;

\echo ''
\echo '=== GLASANJE ==============================================='

insert into public.glasanja (id, zgrada_id, kreirao_id, naslov, opis, status, nacin,
                             potrebna_vecina, kvorum_procenat, pocetak_at, kraj_at)
values (:'glas1', :'zgA', :'pred', 'Zamjena krova',
        'Prijedlog za zamjenu krovnog pokrivaca.',
        'aktivno', 'po_povrsini', 'dvije_trecine', 50.00,
        now() - interval '1 day', now() + interval '7 days');

-- Ukupno tijelo = 60 + 40 + 100 = 200
select pg_temp.tvrdi(
  '12 glasacko tijelo = zbir tezina svih prostora',
  public.fn_ukupno_glasacko_tijelo(:'glas1') = 200,
  'tijelo = ' || public.fn_ukupno_glasacko_tijelo(:'glas1')
);

select set_config('test.uid', :'pred', false);
insert into public.glasovi (glasanje_id, stan_id, korisnik_id, opcija)
values (:'glas1', :'stanA1', :'pred', 'za');          -- tezina 60

select set_config('test.uid', :'st2', false);
insert into public.glasovi (glasanje_id, stan_id, korisnik_id, opcija)
values (:'glas1', :'stanA3', :'st2', 'za');           -- tezina 100

select set_config('test.uid', :'st1', false);
insert into public.glasovi (glasanje_id, stan_id, korisnik_id, opcija)
values (:'glas1', :'stanA2', :'st1', 'protiv');       -- tezina 40

select pg_temp.tvrdi(
  '13 tezina glasa je snapshot iz stanova',
  (select sum(tezina) from public.glasovi where glasanje_id = :'glas1') = 200
);

-- Promjena kvadrature NE SMIJE promijeniti već predane glasove.
reset role;
update public.stanovi set kvadratura = 999, suvlasnicki_udio = 999 where id = :'stanA1';

select pg_temp.tvrdi(
  '14 kasnija promjena kvadrature ne mijenja predani glas',
  (select tezina from public.glasovi
    where glasanje_id = :'glas1' and stan_id = :'stanA1') = 60
);

update public.stanovi set kvadratura = 60, suvlasnicki_udio = 60 where id = :'stanA1';

-- ZA = 160 / 200 = 80% ≥ 66,67% → usvojeno
select pg_temp.tvrdi(
  '15 dvotrecinska vecina ispravno prebrojana',
  (r->>'usvojeno')::boolean,
  'za = ' || (r->>'za_procenat') || '%, odziv = ' || (r->>'odziv_procenat') || '%'
) from (select public.fn_rezultat_glasanja(:'glas1') r) x;

-- Glasanje bez prava / jedan glas po prostoru.
do $$
begin
  perform set_config('test.uid', '44444444-4444-4444-4444-444444444444', false);
  insert into public.glasovi (glasanje_id, stan_id, korisnik_id, opcija)
  values ('eeeeeeee-0000-0000-0000-000000000001',
          'cccccccc-0000-0000-0000-000000000001',
          '44444444-4444-4444-4444-444444444444', 'protiv');
  perform pg_temp.tvrdi('16 stranac ne moze glasati za tudji prostor', false,
                        'glas je prosao!');
exception
  when insufficient_privilege then
    perform pg_temp.tvrdi('16 stranac ne moze glasati za tudji prostor', true);
  when unique_violation then
    perform pg_temp.tvrdi('16 stranac ne moze glasati za tudji prostor', true,
                          'blokirano pravilom jedan glas po prostoru');
end $$;

-- Trigger uvijek pripisuje glas prijavljenom korisniku.
do $$
declare v_vlasnik uuid;
begin
  perform set_config('test.uid', '22222222-2222-2222-2222-222222222222', false);
  update public.glasovi set opcija = 'uzdrzan'
   where glasanje_id = 'eeeeeeee-0000-0000-0000-000000000001'
     and stan_id = 'cccccccc-0000-0000-0000-000000000002';

  select korisnik_id into v_vlasnik from public.glasovi
   where glasanje_id = 'eeeeeeee-0000-0000-0000-000000000001'
     and stan_id = 'cccccccc-0000-0000-0000-000000000002';

  perform pg_temp.tvrdi('17 izmjena glasa ostaje vezana za glasaca',
                        v_vlasnik = '22222222-2222-2222-2222-222222222222');
end $$;

reset role;
select set_config('test.uid', :'pred', false);

select pg_temp.tvrdi(
  '18 zatvaranje glasanja upisuje rezultat',
  (public.fn_zatvori_glasanje(:'glas1')->>'usvojeno')::boolean
);

select pg_temp.tvrdi(
  '19 odluka se automatski objavljuje na oglasnoj tabli',
  (select count(*) from public.obavjestenja
    where glasanje_id = :'glas1' and tip = 'odluka') = 1
);

select pg_temp.tvrdi(
  '20 glasanje je preslo u status zavrseno',
  (select status from public.glasanja where id = :'glas1') = 'zavrseno'
);

-- Zatvoreno glasanje više ne prima glasove.
do $$
begin
  perform set_config('test.uid', '11111111-1111-1111-1111-111111111111', false);
  insert into public.glasovi (glasanje_id, stan_id, korisnik_id, opcija)
  values ('eeeeeeee-0000-0000-0000-000000000001',
          'cccccccc-0000-0000-0000-000000000002',
          '11111111-1111-1111-1111-111111111111', 'za');
  perform pg_temp.tvrdi('21 zatvoreno glasanje ne prima nove glasove', false);
exception when others then
  perform pg_temp.tvrdi('21 zatvoreno glasanje ne prima nove glasove', true);
end $$;

\echo ''
\echo '=== KVAROVI ================================================'

reset role;
insert into public.kvarovi (zgrada_id, prijavio_id, naslov, opis, kategorija, prioritet)
values (:'zgA', :'st1', 'Ne radi lift', 'Lift stoji izmedju 2. i 3. sprata.', 'lift', 'hitno'),
       (:'zgA', :'st2', 'Curi slavina', 'U podrumu.', 'vodoinstalacije', 'srednji');

select pg_temp.tvrdi(
  '22 tiketi dobijaju redni broj unutar zgrade',
  (select array_agg(broj order by broj) from public.kvarovi where zgrada_id = :'zgA')
    = array[1, 2]
);

\echo ''
\echo '=== RLS IZOLACIJA =========================================='

set role authenticated;

-- --- Perspektiva stanara ----------------------------------------------------
select set_config('test.uid', :'st1', false);

select pg_temp.tvrdi(
  '23 stanar vidi finansije SAMO svog prostora',
  (select count(distinct stan_id) from public.transakcije_uplatnice) = 1
);

select pg_temp.tvrdi(
  '24 stanar vidi samo svoju zgradu',
  (select count(*) from public.zgrade) = 1
);

select pg_temp.tvrdi(
  '25 stanar vidi sve kvarove svoje zgrade',
  (select count(*) from public.kvarovi) = 2
);

-- --- Perspektiva uprave -----------------------------------------------------
select set_config('test.uid', :'pred', false);

select pg_temp.tvrdi(
  '26 uprava vidi finansije svih prostora',
  (select count(distinct stan_id) from public.transakcije_uplatnice) = 3
);

-- --- Perspektiva stranca iz druge zgrade ------------------------------------
select set_config('test.uid', :'stranac', false);

select pg_temp.tvrdi(
  '27 stranac NE vidi tudju zgradu',
  (select count(*) = 1 and max(kod) = 'ZEV-2002' from public.zgrade)
);

select pg_temp.tvrdi(
  '28 stranac NE vidi tudje kvarove',
  (select count(*) from public.kvarovi) = 0
);

select pg_temp.tvrdi(
  '29 stranac NE vidi tudje finansije',
  (select count(*) from public.transakcije_uplatnice) = 0
);

select pg_temp.tvrdi(
  '30 stranac NE vidi tudja glasanja',
  (select count(*) from public.glasanja) = 0
);

select pg_temp.tvrdi(
  '31 stranac NE vidi tudje stanare u imeniku',
  (select count(*) from public.korisnici) = 1
);

select pg_temp.tvrdi(
  '32 stranac NE vidi tudje glasove',
  (select count(*) from public.glasovi) = 0
);

\echo ''
\echo '=== ESKALACIJA PRIVILEGIJA ================================='

select set_config('test.uid', :'st1', false);
update public.clanstva
   set uloga_id = 10, glasacko_pravo = true, vidljiv_u_imeniku = false
 where korisnik_id = :'st1';

reset role;

select pg_temp.tvrdi(
  '33 stanar ne moze sam sebi dodijeliti ulogu predsjednika',
  (select uloga_id from public.clanstva where korisnik_id = :'st1') = 50
);

select pg_temp.tvrdi(
  '34 ali smije promijeniti svoju vidljivost u imeniku',
  (select not vidljiv_u_imeniku from public.clanstva where korisnik_id = :'st1')
);

\echo ''
\echo '=== TAJNO GLASANJE ========================================='

-- CLAUDE.md §4.6: kad je `glasanja.tajno`, pojedinačni glas ne vidi niko osim
-- samog glasača — ni uprava. Rezultat postoji isključivo kao agregat.
-- Bez ovih tvrdnji, "admin vidi sve" prečica u `glasovi_select` prošla bi
-- nezapaženo: sve ostale tvrdnje bi i dalje bile zelene.

insert into public.glasanja (id, zgrada_id, kreirao_id, naslov, opis, status,
                             nacin, tajno, pocetak_at, kraj_at)
values (:'tajno_g', :'zgA', :'pred', 'Tajno: povjerenje upravi',
        'Provjera tajnosti glasackog listica', 'aktivno', 'po_povrsini', true,
        now() - interval '1 day', now() + interval '7 days');

set role authenticated;

select set_config('test.uid', :'st1', false);
insert into public.glasovi (glasanje_id, stan_id, korisnik_id, opcija)
values (:'tajno_g', :'stanA2', :'st1', 'za');

select set_config('test.uid', :'st2', false);
insert into public.glasovi (glasanje_id, stan_id, korisnik_id, opcija)
values (:'tajno_g', :'stanA3', :'st2', 'protiv');

select set_config('test.uid', :'st1', false);

select pg_temp.tvrdi(
  '35 glasac vidi vlastiti glas i kad je glasanje tajno',
  (select count(*) from public.glasovi where glasanje_id = :'tajno_g') = 1
);

select set_config('test.uid', :'pred', false);

select pg_temp.tvrdi(
  '36 uprava NE vidi pojedinacne glasove tajnog glasanja',
  (select count(*) from public.glasovi where glasanje_id = :'tajno_g') = 0
);

-- Kontrola: dokazuje da tvrdnja 36 nije lažno pozitivna zbog toga što uprava
-- ionako ne bi vidjela nijedan glas.
select pg_temp.tvrdi(
  '37 uprava vidi pojedinacne glasove JAVNOG glasanja',
  (select count(*) from public.glasovi where glasanje_id = :'glas1') = 3
);

-- Tajnost ne smije ukinuti mjerljivost rezultata.
select set_config('test.uid', :'st1', false);
delete from public.glasovi where glasanje_id = :'tajno_g';

reset role;

select pg_temp.tvrdi(
  '38 brisanje glasa nije dozvoljeno ni vlastitog',
  (select count(*) from public.glasovi where glasanje_id = :'tajno_g') = 2
);

select pg_temp.tvrdi(
  '39 agregat tajnog glasanja ostaje tacan',
  (r ->> 'za')::numeric = 40 and (r ->> 'protiv')::numeric = 100,
  'za = ' || (r ->> 'za') || ', protiv = ' || (r ->> 'protiv')
) from (select public.fn_rezultat_glasanja(:'tajno_g') as r) s;

\echo ''
\echo '=== POGLEDI I POZIVNICE ===================================='

select pg_temp.tvrdi(
  '40 pogled_stanje_stana racuna saldo',
  saldo = 6.00,
  'saldo = ' || saldo
) from public.pogled_stanje_stana where stan_id = :'stanA1';

insert into public.pozivnice (zgrada_id, stan_id, uloga_id, kod)
values (:'zgA', :'stanA2', 60, 'POZIV-ABC123');

select set_config('test.uid', :'stranac', false);

select pg_temp.tvrdi(
  '41 pozivnica kreira clanstvo (neosjetljiva na velicinu slova)',
  public.fn_iskoristi_pozivnicu('poziv-abc123') is not null
);

do $$
begin
  perform public.fn_iskoristi_pozivnicu('POZIV-ABC123');
  perform pg_temp.tvrdi('42 pozivnica se ne moze iskoristiti dvaput', false);
exception when others then
  perform pg_temp.tvrdi('42 pozivnica se ne moze iskoristiti dvaput', true);
end $$;

-- =============================================================================
--  SAŽETAK
-- =============================================================================

\o

\echo ''
\echo '=== SAZETAK ================================================'

select
  count(*)                           as ukupno,
  count(*) filter (where prosao)     as proslo,
  count(*) filter (where not prosao) as palo
from _rezultati;

select redni, opis, detalj from _rezultati where not prosao order by redni;

do $$
declare v_palo integer;
begin
  select count(*) into v_palo from _rezultati where not prosao;
  if v_palo > 0 then
    raise exception 'SMOKE TEST NIJE PROSAO: % tvrdnji palo', v_palo
      using errcode = 'assert_failure';
  end if;
  raise notice 'SVE TVRDNJE PROSLE.';
end $$;
