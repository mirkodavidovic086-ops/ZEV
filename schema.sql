-- =============================================================================
--  MojZEV — Kompletna PostgreSQL / Supabase shema
-- =============================================================================
--  Aplikacija za samostalno vođenje Zajednica etažnih vlasnika (ZEV).
--
--  Ciljna platforma : PostgreSQL 15+ / Supabase
--  Karakter kodiranje: UTF-8
--  Konvencije       : snake_case, imena na lokalnom jeziku (bez dijakritika u
--                     identifikatorima), sve tabele u schemi `public`.
--
--  VAŽNO — redoslijed izvršavanja:
--    1. EKSTENZIJE
--    2. ENUM TIPOVI
--    3. POMOĆNE FUNKCIJE (bez zavisnosti na tabele)
--    4. TABELE + INDEKSI
--    5. FUNKCIJE NAD TABELAMA (RLS helperi, poslovna logika)
--    6. TRIGERI
--    7. POGLEDI (VIEWS)
--    8. RLS POLITIKE
--    9. STORAGE BUCKETS + POLITIKE
--   10. REALTIME PUBLIKACIJE
--   11. SEED PODACI (šifarnici)
--
--  Idempotentnost: skripta se može ponovo pokrenuti nad praznom bazom.
--  Za produkciju koristiti `supabase/migrations/` (vidi README.md).
-- =============================================================================


-- =============================================================================
-- 1. EKSTENZIJE
-- =============================================================================

-- Supabase drži ekstenzije u schemi `extensions`. Tipovi i operator klase se
-- zato eksplicitno kvalifikuju (`extensions.citext`, `extensions.gin_trgm_ops`)
-- kako skripta ne bi zavisila od `search_path`-a.
create extension if not exists "pgcrypto" with schema extensions;
create extension if not exists "citext"   with schema extensions;
create extension if not exists "pg_trgm"  with schema extensions;   -- fuzzy pretraga imenika

-- `gen_random_uuid()` je od PostgreSQL 13 dio jezgra (pg_catalog) i namjerno se
-- NE kvalifikuje schemom.


-- =============================================================================
-- 2. ENUM TIPOVI
-- =============================================================================

-- --- Zgrada / stanovi ---------------------------------------------------------

do $$ begin
  create type public.tip_prostora as enum (
    'stan',
    'poslovni_prostor',
    'garaza',
    'garazno_mjesto',
    'ostava',
    'potkrovlje',
    'ostalo'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.tip_clanstva as enum (
    'vlasnik',        -- etažni vlasnik, ima glasačko pravo
    'suvlasnik',      -- suvlasnik istog prostora
    'podstanar',      -- najmoprimac, bez glasačkog prava (osim po punomoći)
    'punomocnik',     -- glasa u ime vlasnika na osnovu punomoći
    'clan_domacinstva'-- ukućanin, samo uvid
  );
exception when duplicate_object then null; end $$;

-- --- Glasanje ----------------------------------------------------------------

do $$ begin
  create type public.status_glasanja as enum (
    'nacrt',       -- priprema, vidljivo samo upravi
    'zakazano',    -- objavljeno, ali još nije počelo
    'aktivno',     -- glasanje u toku
    'zavrseno',    -- isteklo/zatvoreno, rezultat prebrojan
    'ponisteno'    -- poništeno od strane uprave
  );
exception when duplicate_object then null; end $$;

do $$ begin
  -- Potrebna većina za usvajanje odluke.
  create type public.tip_vecine as enum (
    'prosta_vecina',              -- > 50% od izašlih
    'vecina_svih',                -- > 50% od ukupnog tijela
    'dvije_trecine',              -- >= 2/3
    'tri_cetvrtine',              -- >= 3/4
    'jednoglasno'                 -- 100%
  );
exception when duplicate_object then null; end $$;

do $$ begin
  -- Kako se računa težina jednog glasa.
  create type public.nacin_glasanja as enum (
    'po_stanu',      -- svaki prostor = 1 glas
    'po_povrsini',   -- težina = kvadratura / suvlasnički udio
    'po_glavi'       -- svaki vlasnik = 1 glas
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.opcija_glasa as enum ('za', 'protiv', 'uzdrzan');
exception when duplicate_object then null; end $$;

-- --- Kvarovi -----------------------------------------------------------------

do $$ begin
  create type public.kategorija_kvara as enum (
    'vodoinstalacije',
    'elektroinstalacije',
    'lift',
    'krov',
    'fasada',
    'stepeniste',
    'grijanje',
    'domofon',
    'rasvjeta',
    'ciscenje',
    'dvoriste',
    'parking',
    'vandalizam',
    'ostalo'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.prioritet_kvara as enum ('nizak', 'srednji', 'visok', 'hitno');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.status_kvara as enum (
    'prijavljen',
    'prihvacen',
    'ceka_ponudu',
    'u_toku',
    'rijesen',
    'odbijen',
    'duplikat'
  );
exception when duplicate_object then null; end $$;

-- --- Finansije ---------------------------------------------------------------

do $$ begin
  -- Predznak u knjizi: zaduzenje/kamata povećavaju dug, uplata/popust/storno ga smanjuju.
  create type public.tip_transakcije as enum (
    'zaduzenje',   -- mjesečna naknada, vanredni namet
    'uplata',      -- uplata stanara
    'kamata',      -- zatezna kamata
    'popust',      -- odobrenje / umanjenje
    'storno'       -- ispravka ranije stavke
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.status_uplatnice as enum (
    'nacrt',
    'izdata',
    'djelimicno_placena',
    'placena',
    'dospjela',
    'otkazana'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  -- Standard za generisanje QR koda na uplatnici. Razlikuje se po državi/banci.
  create type public.qr_standard as enum (
    'EPC069_12',  -- SEPA EPC QR (evropski standard, podržan od većine banaka)
    'IPS_QR',     -- NBS IPS QR (Srbija)
    'HUB3A',      -- HUB-3A (Hrvatska)
    'BEZ_QR'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.smjer_novca as enum ('prihod', 'rashod');
exception when duplicate_object then null; end $$;

-- --- Oglasna tabla / obavještenja --------------------------------------------

do $$ begin
  create type public.tip_obavjestenja as enum (
    'obavjestenje',  -- obična objava na oglasnoj tabli
    'hitno',         -- push + banner na vrhu Početne
    'dogadjaj',      -- npr. zakazana skupština, radovi
    'odluka',        -- rezultat glasanja / odluka uprave
    'dokument'       -- objavljen novi dokument
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.kanal_dostave as enum ('push', 'sms', 'viber', 'email', 'in_app');
exception when duplicate_object then null; end $$;


-- =============================================================================
-- 3. POMOĆNE FUNKCIJE (bez zavisnosti na tabele)
-- =============================================================================

-- Automatsko održavanje kolone `azurirano_at`.
create or replace function public.fn_touch_azurirano_at()
returns trigger
language plpgsql
as $$
begin
  new.azurirano_at := now();
  return new;
end;
$$;

-- Normalizacija telefonskog broja u E.164-sličan oblik (uklanja razmake, crtice,
-- zagrade). Ne validira državni pozivni broj — to radi aplikacijski sloj.
create or replace function public.fn_normalizuj_telefon(p_telefon text)
returns text
language sql
immutable
as $$
  select nullif(regexp_replace(coalesce(p_telefon, ''), '[^0-9+]', '', 'g'), '');
$$;

-- Izračun kontrolnog broja po ISO 7064 MOD 97-10 (koristi se za IBAN validaciju
-- i za "poziv na broj" model 97).
create or replace function public.fn_mod97(p_ulaz text)
returns integer
language plpgsql
immutable
as $$
declare
  v_ostatak integer := 0;
  v_znak    text;
  v_i       integer;
  v_vrijednost text;
begin
  for v_i in 1..length(p_ulaz) loop
    v_znak := substr(upper(p_ulaz), v_i, 1);
    if v_znak between '0' and '9' then
      v_vrijednost := v_znak;
    elsif v_znak between 'A' and 'Z' then
      v_vrijednost := (ascii(v_znak) - 55)::text;   -- A=10 ... Z=35
    else
      continue;                                      -- ignoriši razmake i separatore
    end if;
    v_ostatak := (v_ostatak::bigint * power(10, length(v_vrijednost))::bigint
                  + v_vrijednost::bigint) % 97;
  end loop;
  return v_ostatak;
end;
$$;


-- =============================================================================
-- 4. TABELE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 4.1  ULOGE — šifarnik uloga (globalni, ne po zgradi)
-- -----------------------------------------------------------------------------
--  `nivo` definiše hijerarhiju: manji broj = veća ovlaštenja.
--  RLS helperi porede `nivo` umjesto da nabrajaju kodove.
-- -----------------------------------------------------------------------------

create table if not exists public.uloge (
  id            smallint      primary key,
  kod           text          not null unique,
  naziv         text          not null,
  opis          text,
  nivo          smallint      not null,
  -- Deklarativne dozvole; aplikacija ih koristi za sakrivanje UI elemenata.
  -- RLS se NE oslanja na ovo polje (izvor istine je `nivo`).
  dozvole       jsonb         not null default '{}'::jsonb,
  sistemska     boolean       not null default true,
  kreirano_at   timestamptz   not null default now(),

  constraint uloge_nivo_chk check (nivo between 0 and 100)
);

comment on table  public.uloge      is 'Šifarnik uloga u sistemu. Nivo: 0=sistem admin ... 60=podstanar.';
comment on column public.uloge.nivo is 'Hijerarhija ovlaštenja. Manji broj = veća prava. Uprava = nivo <= 30.';


-- -----------------------------------------------------------------------------
-- 4.2  KORISNICI — profil vezan 1:1 na auth.users
-- -----------------------------------------------------------------------------
--  Supabase Auth drži kredencijale (OTP/magic link) u `auth.users`.
--  Ovdje živi sve što aplikacija prikazuje. Red se kreira triggerom
--  `on_auth_user_created` (vidi sekciju 6).
-- -----------------------------------------------------------------------------

create table if not exists public.korisnici (
  id                 uuid        primary key references auth.users(id) on delete cascade,
  ime                text,
  prezime            text,
  -- Puno ime kao generisana kolona — koristi se za sortiranje imenika.
  puno_ime           text        generated always as (
                                   btrim(coalesce(ime, '') || ' ' || coalesce(prezime, ''))
                                 ) stored,
  email              extensions.citext,
  telefon            text,
  telefon_normalizovan text     generated always as (
                                   nullif(regexp_replace(coalesce(telefon, ''), '[^0-9+]', '', 'g'), '')
                                 ) stored,
  avatar_url         text,
  jezik              text        not null default 'bs',
  -- Korisnik može isključiti pojedine kanale obavještavanja.
  postavke_notifikacija jsonb    not null default
    '{"push": true, "email": true, "sms": false, "viber": false, "hitno_uvijek": true}'::jsonb,
  -- Sistemski administrator platforme (support/nas tim), NE predsjednik zgrade.
  je_sistem_admin    boolean     not null default false,
  aktivan            boolean     not null default true,
  zadnja_prijava_at  timestamptz,
  kreirano_at        timestamptz not null default now(),
  azurirano_at       timestamptz not null default now(),

  constraint korisnici_jezik_chk check (jezik in ('bs', 'hr', 'sr', 'en'))
);

create index if not exists idx_korisnici_telefon on public.korisnici (telefon_normalizovan)
  where telefon_normalizovan is not null;
create index if not exists idx_korisnici_email   on public.korisnici (email)
  where email is not null;
create index if not exists idx_korisnici_ime_trgm on public.korisnici
  using gin (puno_ime extensions.gin_trgm_ops);

comment on table public.korisnici is 'Profil korisnika. 1:1 sa auth.users, popunjava se triggerom pri registraciji.';


-- -----------------------------------------------------------------------------
-- 4.3  ZGRADE — tenant (jedna ZEV = jedan tenant)
-- -----------------------------------------------------------------------------

create table if not exists public.zgrade (
  id                    uuid        primary key default gen_random_uuid(),
  naziv                 text        not null,
  -- Kratki kod za pozivnice i poziv-na-broj (npr. "ZEV-1234").
  kod                   text        not null unique,

  -- Adresa ------------------------------------------------------------------
  ulica                 text        not null,
  broj                  text        not null,
  grad                  text        not null,
  opstina               text,
  postanski_broj        text,
  drzava                text        not null default 'BA',
  geo_lat               numeric(9,6),
  geo_lng               numeric(9,6),

  -- Pravni podaci ZEV-a ------------------------------------------------------
  jib                   text,        -- jedinstveni identifikacioni broj
  maticni_broj          text,
  datum_registracije    date,

  -- Bankovni podaci za uplatnice --------------------------------------------
  naziv_primaoca        text,        -- kako se ispisuje na uplatnici
  iban                  text,
  swift                 text,
  banka                 text,
  valuta                char(3)     not null default 'BAM',
  qr_standard           public.qr_standard not null default 'EPC069_12',

  -- Fizičke karakteristike ---------------------------------------------------
  godina_izgradnje      smallint,
  broj_ulaza            smallint    not null default 1,
  broj_spratova         smallint,
  ima_lift              boolean     not null default false,
  ukupna_povrsina       numeric(10,2),

  -- Finansijska pravila ------------------------------------------------------
  -- Mjesečna naknada = fiksni_dio + (naknada_po_m2 * kvadratura prostora).
  fiksna_naknada        numeric(10,2) not null default 0,
  naknada_po_m2         numeric(10,4) not null default 0,
  dan_dospijeca         smallint    not null default 15,
  zatezna_kamata_godisnje numeric(5,2) not null default 0,

  -- Pravila glasanja (podrazumijevana, pojedino glasanje ih može pregaziti) ---
  podrazumijevani_nacin_glasanja public.nacin_glasanja not null default 'po_povrsini',
  podrazumijevani_kvorum         numeric(5,2)          not null default 50.00,

  -- SaaS / pretplata ---------------------------------------------------------
  plan                  text        not null default 'besplatan',
  pretplata_do          date,
  aktivna               boolean     not null default true,

  logo_url              text,
  napomena              text,
  kreirano_at           timestamptz not null default now(),
  azurirano_at          timestamptz not null default now(),

  constraint zgrade_kod_chk            check (kod ~ '^[A-Z0-9-]{4,20}$'),
  constraint zgrade_dan_dospijeca_chk  check (dan_dospijeca between 1 and 28),
  constraint zgrade_kvorum_chk         check (podrazumijevani_kvorum between 0 and 100),
  constraint zgrade_valuta_chk         check (valuta ~ '^[A-Z]{3}$'),
  constraint zgrade_naknade_chk        check (fiksna_naknada >= 0 and naknada_po_m2 >= 0),
  constraint zgrade_plan_chk           check (plan in ('besplatan', 'standard', 'premium'))
);

create index if not exists idx_zgrade_grad   on public.zgrade (grad);
create index if not exists idx_zgrade_aktivna on public.zgrade (aktivna) where aktivna;

comment on table  public.zgrade     is 'Zajednica etažnih vlasnika — tenant aplikacije. Svi ostali podaci su particionisani po zgrada_id.';
comment on column public.zgrade.kod is 'Javni kod zgrade, koristi se u pozivnicama i pozivu na broj.';


-- -----------------------------------------------------------------------------
-- 4.4  STANOVI — pojedinačni etažni dijelovi
-- -----------------------------------------------------------------------------

create table if not exists public.stanovi (
  id                uuid        primary key default gen_random_uuid(),
  zgrada_id         uuid        not null references public.zgrade(id) on delete cascade,

  oznaka            text        not null,        -- "12", "PP-1", "G-4"
  ulaz              text,                        -- "A", "B" ili broj ulaza
  sprat             smallint,                    -- 0 = prizemlje, -1 = suteren
  tip               public.tip_prostora not null default 'stan',

  kvadratura        numeric(8,2),
  broj_soba         numeric(3,1),
  -- Suvlasnički udio u zajedničkim dijelovima (iz etažnog elaborata).
  -- Ako je NULL, težina glasa se izvodi iz kvadrature.
  suvlasnicki_udio  numeric(10,6),

  broj_ukucana      smallint,
  aktivan           boolean     not null default true,
  napomena          text,

  kreirano_at       timestamptz not null default now(),
  azurirano_at      timestamptz not null default now(),

  -- NULLS NOT DISTINCT: bez ovoga bi dva prostora sa `ulaz IS NULL` i istom
  -- oznakom prošla kroz ograničenje (NULL <> NULL u standardnom UNIQUE).
  constraint stanovi_oznaka_uniq   unique nulls not distinct (zgrada_id, ulaz, oznaka),
  constraint stanovi_kvadratura_chk check (kvadratura is null or kvadratura > 0),
  constraint stanovi_udio_chk       check (suvlasnicki_udio is null or suvlasnicki_udio > 0),
  -- Kompozitni ključ omogućava FK-ovima da garantuju da stan i članstvo
  -- pripadaju ISTOJ zgradi (vidi `clanstva`).
  constraint stanovi_id_zgrada_uniq unique (id, zgrada_id)
);

create index if not exists idx_stanovi_zgrada on public.stanovi (zgrada_id) where aktivan;

comment on column public.stanovi.suvlasnicki_udio is
  'Udio u zajedničkim dijelovima iz etažnog elaborata. Osnov za težinsko glasanje i raspodjelu troškova.';


-- -----------------------------------------------------------------------------
-- 4.5  CLANSTVA — veza korisnik ↔ zgrada (opciono ↔ stan) + uloga
-- -----------------------------------------------------------------------------
--  Ovo je srce modela pristupa. Jedan korisnik može:
--    • biti vlasnik više stanova u istoj ili različitim zgradama,
--    • biti predsjednik u zgradi A i običan stanar u zgradi B,
--    • imati ulogu na nivou zgrade bez vezanog stana (npr. angažovani upravnik).
-- -----------------------------------------------------------------------------

create table if not exists public.clanstva (
  id              uuid        primary key default gen_random_uuid(),
  korisnik_id     uuid        not null references public.korisnici(id) on delete cascade,
  zgrada_id       uuid        not null references public.zgrade(id)    on delete cascade,
  stan_id         uuid,
  uloga_id        smallint    not null references public.uloge(id),
  tip             public.tip_clanstva not null default 'vlasnik',

  -- Glasačko pravo se izvodi iz tipa, ali se može ručno pregaziti
  -- (npr. podstanar sa punomoći vlasnika).
  glasacko_pravo  boolean     not null default true,
  -- Udio u vlasništvu nad prostorom kad ima više suvlasnika (0..1).
  udio            numeric(5,4) not null default 1.0,

  -- Ovaj kontakt je vidljiv u imeniku zgrade (Modul 5).
  vidljiv_u_imeniku boolean   not null default true,

  vazi_od         date        not null default current_date,
  vazi_do         date,
  aktivno         boolean     not null default true,

  kreirano_at     timestamptz not null default now(),
  azurirano_at    timestamptz not null default now(),

  -- Garantuje da stan pripada istoj zgradi kao i članstvo.
  constraint clanstva_stan_ista_zgrada_fk
    foreign key (stan_id, zgrada_id)
    references public.stanovi(id, zgrada_id) on delete cascade,

  constraint clanstva_udio_chk    check (udio > 0 and udio <= 1),
  constraint clanstva_period_chk  check (vazi_do is null or vazi_do >= vazi_od),
  -- Jedan korisnik ne može imati dva članstva za isti stan.
  -- NULLS NOT DISTINCT pokriva i članstva bez stana (uloga na nivou zgrade),
  -- i neophodan je da `ON CONFLICT` u `fn_iskoristi_pozivnicu()` radi.
  constraint clanstva_jedinstveno unique nulls not distinct (korisnik_id, zgrada_id, stan_id)
);

create index if not exists idx_clanstva_korisnik on public.clanstva (korisnik_id) where aktivno;
create index if not exists idx_clanstva_zgrada   on public.clanstva (zgrada_id)   where aktivno;
create index if not exists idx_clanstva_stan     on public.clanstva (stan_id)     where aktivno;

comment on table public.clanstva is
  'Veza korisnik↔zgrada↔stan sa ulogom. Osnova za sve RLS politike u sistemu.';


-- -----------------------------------------------------------------------------
-- 4.6  POZIVNICE — onboarding stanara bez lozinke
-- -----------------------------------------------------------------------------

create table if not exists public.pozivnice (
  id            uuid        primary key default gen_random_uuid(),
  zgrada_id     uuid        not null references public.zgrade(id) on delete cascade,
  stan_id       uuid,
  uloga_id      smallint    not null references public.uloge(id),
  tip           public.tip_clanstva not null default 'vlasnik',

  -- Jednokratni kod koji stanar unosi u aplikaciji.
  kod           text        not null unique,
  email         extensions.citext,
  telefon       text,

  kreirao_id    uuid        references public.korisnici(id) on delete set null,
  iskoristio_id uuid        references public.korisnici(id) on delete set null,
  iskoriscena_at timestamptz,
  istice_at     timestamptz not null default (now() + interval '30 days'),
  kreirano_at   timestamptz not null default now(),

  constraint pozivnice_stan_ista_zgrada_fk
    foreign key (stan_id, zgrada_id)
    references public.stanovi(id, zgrada_id) on delete cascade,
  constraint pozivnice_kod_chk check (char_length(kod) between 6 and 32)
);

create index if not exists idx_pozivnice_zgrada on public.pozivnice (zgrada_id);
create index if not exists idx_pozivnice_kod    on public.pozivnice (kod)
  where iskoriscena_at is null;


-- -----------------------------------------------------------------------------
-- 4.7  OBAVJESTENJA — Modul 1: Oglasna tabla i hitna obavještenja
-- -----------------------------------------------------------------------------

create table if not exists public.obavjestenja (
  id            uuid        primary key default gen_random_uuid(),
  zgrada_id     uuid        not null references public.zgrade(id) on delete cascade,
  autor_id      uuid        references public.korisnici(id) on delete set null,

  tip           public.tip_obavjestenja not null default 'obavjestenje',
  naslov        text        not null,
  sadrzaj       text        not null,

  -- Zakačeno obavještenje stoji na vrhu Početne.
  zakaceno      boolean     not null default false,
  -- Hitna obavještenja idu push/SMS kanalom odmah po objavi.
  objavljeno_at timestamptz,
  vazi_do       timestamptz,

  -- Ako je obavještenje vezano za konkretan događaj/objekat.
  glasanje_id   uuid,
  kvar_id       uuid,

  broj_pregleda integer     not null default 0,
  dozvoli_komentare boolean not null default true,

  kreirano_at   timestamptz not null default now(),
  azurirano_at  timestamptz not null default now(),

  constraint obavjestenja_naslov_chk check (char_length(btrim(naslov)) between 3 and 200)
);

create index if not exists idx_obavjestenja_zgrada
  on public.obavjestenja (zgrada_id, objavljeno_at desc nulls last);
create index if not exists idx_obavjestenja_zakaceno
  on public.obavjestenja (zgrada_id) where zakaceno;


-- -----------------------------------------------------------------------------
-- 4.8  GLASANJA — Modul 3: digitalna skupština (asinhrono glasanje)
-- -----------------------------------------------------------------------------

create table if not exists public.glasanja (
  id                uuid        primary key default gen_random_uuid(),
  zgrada_id         uuid        not null references public.zgrade(id) on delete cascade,
  kreirao_id        uuid        references public.korisnici(id) on delete set null,

  naslov            text        not null,
  opis              text        not null,
  obrazlozenje      text,                     -- detaljno obrazloženje prijedloga

  status            public.status_glasanja not null default 'nacrt',
  nacin             public.nacin_glasanja  not null default 'po_povrsini',
  potrebna_vecina   public.tip_vecine      not null default 'prosta_vecina',
  kvorum_procenat   numeric(5,2)           not null default 50.00,

  -- Ako `je_visestruko`, glasa se izborom jedne od `glasanje_opcije`;
  -- inače je klasično ZA / PROTIV / UZDRŽAN.
  je_visestruko     boolean     not null default false,
  tajno             boolean     not null default false,   -- skriva ko je kako glasao
  dozvoli_izmjenu   boolean     not null default true,    -- glas se može promijeniti do isteka

  pocetak_at        timestamptz not null,
  kraj_at           timestamptz not null,

  -- Denormalizovan snapshot rezultata; popunjava `fn_zatvori_glasanje()`.
  rezultat          jsonb,
  usvojeno          boolean,
  zatvoreno_at      timestamptz,

  kreirano_at       timestamptz not null default now(),
  azurirano_at      timestamptz not null default now(),

  constraint glasanja_period_chk  check (kraj_at > pocetak_at),
  constraint glasanja_kvorum_chk  check (kvorum_procenat between 0 and 100),
  constraint glasanja_naslov_chk  check (char_length(btrim(naslov)) between 3 and 200),
  -- Rezultat i `usvojeno` postoje samo za zatvorena glasanja.
  constraint glasanja_rezultat_chk check (
    (status = 'zavrseno' and zatvoreno_at is not null)
    or (status <> 'zavrseno')
  )
);

create index if not exists idx_glasanja_zgrada  on public.glasanja (zgrada_id, kraj_at desc);
create index if not exists idx_glasanja_aktivna on public.glasanja (status, kraj_at)
  where status in ('zakazano', 'aktivno');

comment on column public.glasanja.tajno is
  'Tajno glasanje: identitet glasača se ne prikazuje ni upravi, samo agregat.';


-- Opcije za višestruki izbor -------------------------------------------------

create table if not exists public.glasanje_opcije (
  id            uuid        primary key default gen_random_uuid(),
  glasanje_id   uuid        not null references public.glasanja(id) on delete cascade,
  redoslijed    smallint    not null default 0,
  tekst         text        not null,
  opis          text,

  constraint glasanje_opcije_uniq unique (glasanje_id, redoslijed),
  -- Kompozitni ključ da `glasovi` mogu garantovati da opcija pripada glasanju.
  constraint glasanje_opcije_id_glasanje_uniq unique (id, glasanje_id)
);

create index if not exists idx_glasanje_opcije_glasanje on public.glasanje_opcije (glasanje_id);


-- -----------------------------------------------------------------------------
-- 4.9  GLASOVI — pojedinačni glasovi
-- -----------------------------------------------------------------------------
--  Ključno pravilo: JEDAN GLAS PO PROSTORU (stanu), ne po korisniku.
--  Suvlasnici se dogovaraju van sistema; prvi koji glasa "troši" glas stana,
--  a `dozvoli_izmjenu` određuje da li se glas može mijenjati do isteka roka.
-- -----------------------------------------------------------------------------

create table if not exists public.glasovi (
  id            uuid        primary key default gen_random_uuid(),
  glasanje_id   uuid        not null references public.glasanja(id) on delete cascade,
  stan_id       uuid        not null references public.stanovi(id)  on delete cascade,
  korisnik_id   uuid        not null references public.korisnici(id) on delete cascade,

  -- Za klasično glasanje popunjen je `opcija`; za višestruko `opcija_id`.
  opcija        public.opcija_glasa,
  opcija_id     uuid,

  -- Snapshot težine u trenutku glasanja — kasnija promjena kvadrature
  -- ili suvlasničkog udjela NE smije retroaktivno mijenjati rezultat.
  tezina        numeric(12,6) not null default 1,
  obrazlozenje  text,

  -- Trag za reviziju (bez čuvanja pune IP adrese — GDPR minimizacija).
  hash_uredjaja text,
  glasano_at    timestamptz not null default now(),
  izmijenjeno_at timestamptz,

  constraint glasovi_jedan_po_stanu unique (glasanje_id, stan_id),
  constraint glasovi_tezina_chk     check (tezina > 0),
  -- Tačno jedan od `opcija` / `opcija_id` mora biti postavljen.
  constraint glasovi_izbor_chk check (
    (opcija is not null and opcija_id is null)
    or (opcija is null and opcija_id is not null)
  ),
  -- Garantuje da izabrana opcija pripada ovom glasanju.
  constraint glasovi_opcija_isto_glasanje_fk
    foreign key (opcija_id, glasanje_id)
    references public.glasanje_opcije(id, glasanje_id) on delete cascade
);

create index if not exists idx_glasovi_glasanje on public.glasovi (glasanje_id);
create index if not exists idx_glasovi_korisnik on public.glasovi (korisnik_id);


-- -----------------------------------------------------------------------------
-- 4.10  KVAROVI — Modul 4: ticketing sistem
-- -----------------------------------------------------------------------------

create table if not exists public.kvarovi (
  id              uuid        primary key default gen_random_uuid(),
  zgrada_id       uuid        not null references public.zgrade(id) on delete cascade,
  prijavio_id     uuid        references public.korisnici(id) on delete set null,
  stan_id         uuid,                        -- ako je kvar vezan za konkretan prostor

  -- Čitljiv broj tiketa unutar zgrade: #1, #2, ... (popunjava trigger).
  broj            integer     not null,

  naslov          text        not null,
  opis            text        not null,
  kategorija      public.kategorija_kvara not null default 'ostalo',
  prioritet       public.prioritet_kvara  not null default 'srednji',
  status          public.status_kvara     not null default 'prijavljen',
  lokacija        text,                        -- "3. sprat, hodnik kod lifta"

  -- Obrada
  dodijeljen_id   uuid        references public.korisnici(id) on delete set null,
  izvodjac        text,                        -- naziv firme/majstora
  izvodjac_kontakt text,
  procijenjeni_trosak numeric(12,2),
  stvarni_trosak  numeric(12,2),
  rok_at          timestamptz,
  rijeseno_at     timestamptz,
  rjesenje        text,

  -- Ako je duplikat, pokazuje na originalni tiket.
  duplikat_od_id  uuid        references public.kvarovi(id) on delete set null,
  broj_potvrda    integer     not null default 0,   -- "i mene muči isto" glasovi

  kreirano_at     timestamptz not null default now(),
  azurirano_at    timestamptz not null default now(),

  constraint kvarovi_broj_uniq  unique (zgrada_id, broj),
  constraint kvarovi_naslov_chk check (char_length(btrim(naslov)) between 3 and 200),
  constraint kvarovi_trosak_chk check (
    (procijenjeni_trosak is null or procijenjeni_trosak >= 0)
    and (stvarni_trosak is null or stvarni_trosak >= 0)
  ),
  -- SET NULL sa listom kolona: brisanje prostora smije poništiti samo `stan_id`.
  -- Bez liste bi PostgreSQL pokušao i `zgrada_id := NULL` i prekršio NOT NULL.
  constraint kvarovi_stan_ista_zgrada_fk
    foreign key (stan_id, zgrada_id)
    references public.stanovi(id, zgrada_id) on delete set null (stan_id),
  -- Riješen tiket mora imati datum rješavanja.
  constraint kvarovi_rijeseno_chk check (
    (status = 'rijesen') = (rijeseno_at is not null)
  )
);

create index if not exists idx_kvarovi_zgrada   on public.kvarovi (zgrada_id, kreirano_at desc);
create index if not exists idx_kvarovi_status   on public.kvarovi (zgrada_id, status)
  where status not in ('rijesen', 'odbijen', 'duplikat');
create index if not exists idx_kvarovi_prijavio on public.kvarovi (prijavio_id);


-- Potvrde ("i ja imam isti problem") ------------------------------------------

create table if not exists public.kvar_potvrde (
  kvar_id      uuid        not null references public.kvarovi(id)   on delete cascade,
  korisnik_id  uuid        not null references public.korisnici(id) on delete cascade,
  kreirano_at  timestamptz not null default now(),
  primary key (kvar_id, korisnik_id)
);


-- -----------------------------------------------------------------------------
-- 4.11  KOMENTARI — zajednički za obavještenja i kvarove
-- -----------------------------------------------------------------------------

create table if not exists public.komentari (
  id              uuid        primary key default gen_random_uuid(),
  zgrada_id       uuid        not null references public.zgrade(id) on delete cascade,
  autor_id        uuid        references public.korisnici(id) on delete set null,

  obavjestenje_id uuid        references public.obavjestenja(id) on delete cascade,
  kvar_id         uuid        references public.kvarovi(id)      on delete cascade,

  sadrzaj         text        not null,
  interni         boolean     not null default false,   -- vidljivo samo upravi
  obrisan         boolean     not null default false,

  kreirano_at     timestamptz not null default now(),
  azurirano_at    timestamptz not null default now(),

  -- Komentar mora pripadati tačno jednom roditelju.
  constraint komentari_roditelj_chk check (
    (obavjestenje_id is not null and kvar_id is null)
    or (obavjestenje_id is null and kvar_id is not null)
  ),
  constraint komentari_sadrzaj_chk check (char_length(btrim(sadrzaj)) > 0)
);

create index if not exists idx_komentari_obavjestenje
  on public.komentari (obavjestenje_id, kreirano_at) where obavjestenje_id is not null;
create index if not exists idx_komentari_kvar
  on public.komentari (kvar_id, kreirano_at) where kvar_id is not null;


-- -----------------------------------------------------------------------------
-- 4.12  TRANSAKCIJE_UPLATNICE — Modul 2: finansije stanara
-- -----------------------------------------------------------------------------
--  Jedinstvena knjiga (ledger) po prostoru. Zaduženja i uplate su redovi u
--  istoj tabeli — saldo se izvodi kao suma `iznos_predznakom`.
--
--  Tabela je APPEND-ONLY po dizajnu: greška se ispravlja `storno` stavkom,
--  nikad UPDATE-om ili DELETE-om (vidi RLS politike i triger `fn_zabrani_izmjenu_knjizenja`).
-- -----------------------------------------------------------------------------

create table if not exists public.transakcije_uplatnice (
  id                uuid        primary key default gen_random_uuid(),
  zgrada_id         uuid        not null references public.zgrade(id) on delete cascade,
  stan_id           uuid        not null,
  kreirao_id        uuid        references public.korisnici(id) on delete set null,

  tip               public.tip_transakcije not null,
  status            public.status_uplatnice not null default 'izdata',

  -- Iznos je UVIJEK pozitivan; predznak određuje `tip`.
  iznos             numeric(12,2) not null,
  valuta            char(3)       not null default 'BAM',
  -- Generisana kolona: + povećava dug, − smanjuje dug.
  iznos_predznakom  numeric(12,2) generated always as (
                      case
                        when tip in ('zaduzenje', 'kamata') then iznos
                        else -iznos
                      end
                    ) stored,

  -- Period na koji se stavka odnosi (za mjesečne naknade).
  period_od         date,
  period_do         date,
  opis              text        not null,
  datum_dokumenta   date        not null default current_date,
  datum_dospijeca   date,
  datum_uplate      date,

  -- Podaci uplatnice --------------------------------------------------------
  broj_uplatnice    text,                       -- npr. "ZEV-1234-2026-08-0012"
  primalac          text,
  racun_primaoca    text,                       -- IBAN
  poziv_na_broj     text,
  sifra_placanja    text,
  model             text,
  qr_sadrzaj        text,                       -- payload za QR (vidi fn_generisi_qr)

  -- Uparivanje sa izvodom banke ---------------------------------------------
  referenca_banke   text,
  izvod_broj        text,
  upareno_at        timestamptz,

  -- Storno veza -------------------------------------------------------------
  storno_od_id      uuid        references public.transakcije_uplatnice(id) on delete restrict,

  napomena          text,
  kreirano_at       timestamptz not null default now(),
  azurirano_at      timestamptz not null default now(),

  constraint tu_iznos_chk        check (iznos > 0),
  constraint tu_valuta_chk       check (valuta ~ '^[A-Z]{3}$'),
  constraint tu_period_chk       check (period_do is null or period_od is null or period_do >= period_od),
  constraint tu_broj_uniq        unique (zgrada_id, broj_uplatnice),
  constraint tu_storno_chk       check ((tip = 'storno') = (storno_od_id is not null)),
  constraint tu_stan_ista_zgrada_fk
    foreign key (stan_id, zgrada_id)
    references public.stanovi(id, zgrada_id) on delete cascade
);

create index if not exists idx_tu_stan
  on public.transakcije_uplatnice (stan_id, datum_dokumenta desc);
create index if not exists idx_tu_zgrada
  on public.transakcije_uplatnice (zgrada_id, datum_dokumenta desc);
create index if not exists idx_tu_dospjele
  on public.transakcije_uplatnice (zgrada_id, datum_dospijeca)
  where tip = 'zaduzenje' and status in ('izdata', 'djelimicno_placena', 'dospjela');
create index if not exists idx_tu_period
  on public.transakcije_uplatnice (stan_id, period_od);

comment on table public.transakcije_uplatnice is
  'Knjiga zaduženja i uplata po prostoru. Append-only: ispravke idu kroz storno stavku.';


-- -----------------------------------------------------------------------------
-- 4.13  TROSKOVI_ZEV — transparentnost računa zajednice (Modul 2)
-- -----------------------------------------------------------------------------
--  Ovo je knjiga ZGRADE (ne stanara): iz čega se sastoji zajednički fond,
--  gdje je novac potrošen. Vidljivo SVIM članovima — to je ključna vrijednost
--  aplikacije naspram agencijskog modela.
-- -----------------------------------------------------------------------------

create table if not exists public.troskovi_zev (
  id              uuid        primary key default gen_random_uuid(),
  zgrada_id       uuid        not null references public.zgrade(id) on delete cascade,
  kreirao_id      uuid        references public.korisnici(id) on delete set null,

  smjer           public.smjer_novca not null default 'rashod',
  kategorija      text        not null,       -- 'odrzavanje', 'lift', 'ciscenje', 'struja', ...
  opis            text        not null,
  iznos           numeric(12,2) not null,
  valuta          char(3)     not null default 'BAM',
  datum           date        not null default current_date,

  dobavljac       text,
  broj_racuna     text,
  kvar_id         uuid        references public.kvarovi(id) on delete set null,
  -- Odluka skupštine kojom je trošak odobren (transparentnost).
  glasanje_id     uuid        references public.glasanja(id) on delete set null,

  kreirano_at     timestamptz not null default now(),
  azurirano_at    timestamptz not null default now(),

  constraint troskovi_iznos_chk check (iznos > 0)
);

create index if not exists idx_troskovi_zgrada on public.troskovi_zev (zgrada_id, datum desc);


-- -----------------------------------------------------------------------------
-- 4.14  DOKUMENTI i PRILOZI
-- -----------------------------------------------------------------------------

create table if not exists public.dokumenti (
  id            uuid        primary key default gen_random_uuid(),
  zgrada_id     uuid        not null references public.zgrade(id) on delete cascade,
  postavio_id   uuid        references public.korisnici(id) on delete set null,

  naziv         text        not null,
  kategorija    text        not null default 'ostalo',  -- 'zapisnik', 'ugovor', 'racun', ...
  putanja       text        not null,                   -- ključ u Supabase Storage
  mime_tip      text,
  velicina_b    bigint,
  -- Javni dokumenti su vidljivi svim članovima; ostali samo upravi.
  javni         boolean     not null default true,

  kreirano_at   timestamptz not null default now(),

  constraint dokumenti_velicina_chk check (velicina_b is null or velicina_b >= 0)
);

create index if not exists idx_dokumenti_zgrada on public.dokumenti (zgrada_id, kreirano_at desc);


-- Generički prilozi (slike kvarova, skenovi uplatnica, prilozi uz glasanje).
create table if not exists public.prilozi (
  id              uuid        primary key default gen_random_uuid(),
  zgrada_id       uuid        not null references public.zgrade(id) on delete cascade,
  postavio_id     uuid        references public.korisnici(id) on delete set null,

  kvar_id         uuid        references public.kvarovi(id)      on delete cascade,
  obavjestenje_id uuid        references public.obavjestenja(id) on delete cascade,
  glasanje_id     uuid        references public.glasanja(id)     on delete cascade,
  transakcija_id  uuid        references public.transakcije_uplatnice(id) on delete cascade,

  putanja         text        not null,
  mime_tip        text,
  velicina_b      bigint,
  redoslijed      smallint    not null default 0,
  kreirano_at     timestamptz not null default now(),

  -- Prilog mora pripadati tačno jednom roditelju.
  constraint prilozi_roditelj_chk check (
    (kvar_id is not null)::int
    + (obavjestenje_id is not null)::int
    + (glasanje_id is not null)::int
    + (transakcija_id is not null)::int = 1
  )
);

create index if not exists idx_prilozi_kvar on public.prilozi (kvar_id) where kvar_id is not null;


-- -----------------------------------------------------------------------------
-- 4.15  KONTAKTI — Modul 5: imenik hitnih i servisnih kontakata
-- -----------------------------------------------------------------------------

create table if not exists public.kontakti (
  id            uuid        primary key default gen_random_uuid(),
  zgrada_id     uuid        not null references public.zgrade(id) on delete cascade,

  naziv         text        not null,
  kategorija    text        not null default 'ostalo',  -- 'hitne_sluzbe', 'majstor', 'lift', ...
  telefon       text,
  email         extensions.citext,
  napomena      text,
  redoslijed    smallint    not null default 0,
  hitni         boolean     not null default false,     -- prikazuje se na vrhu

  kreirano_at   timestamptz not null default now(),
  azurirano_at  timestamptz not null default now()
);

create index if not exists idx_kontakti_zgrada on public.kontakti (zgrada_id, redoslijed);


-- -----------------------------------------------------------------------------
-- 4.16  PUSH TOKENI i DNEVNIK OBAVJEŠTAVANJA
-- -----------------------------------------------------------------------------

create table if not exists public.push_tokeni (
  id            uuid        primary key default gen_random_uuid(),
  korisnik_id   uuid        not null references public.korisnici(id) on delete cascade,
  token         text        not null unique,
  platforma     text        not null,          -- 'ios' | 'android' | 'web'
  uredjaj       text,
  aktivan       boolean     not null default true,
  kreirano_at   timestamptz not null default now(),
  koristen_at   timestamptz not null default now(),

  constraint push_tokeni_platforma_chk check (platforma in ('ios', 'android', 'web'))
);

create index if not exists idx_push_tokeni_korisnik on public.push_tokeni (korisnik_id) where aktivan;


create table if not exists public.dnevnik_obavjestavanja (
  id            uuid        primary key default gen_random_uuid(),
  zgrada_id     uuid        references public.zgrade(id) on delete cascade,
  korisnik_id   uuid        references public.korisnici(id) on delete set null,
  kanal         public.kanal_dostave not null,
  naslov        text,
  sadrzaj       text,
  uspjesno      boolean     not null default true,
  greska        text,
  poslato_at    timestamptz not null default now()
);

create index if not exists idx_dnevnik_korisnik on public.dnevnik_obavjestavanja (korisnik_id, poslato_at desc);


-- -----------------------------------------------------------------------------
-- 4.17  AUDIT_LOG — trag revizije za osjetljive radnje
-- -----------------------------------------------------------------------------

create table if not exists public.audit_log (
  id            bigint      generated always as identity primary key,
  zgrada_id     uuid,
  korisnik_id   uuid,
  tabela        text        not null,
  zapis_id      text,
  radnja        text        not null,          -- 'INSERT' | 'UPDATE' | 'DELETE'
  stare_vrijednosti jsonb,
  nove_vrijednosti  jsonb,
  kreirano_at   timestamptz not null default now()
);

create index if not exists idx_audit_zgrada on public.audit_log (zgrada_id, kreirano_at desc);
create index if not exists idx_audit_tabela on public.audit_log (tabela, zapis_id);


-- Odgođeni FK-ovi (tabele referencirane prije nego što su definisane) ---------

alter table public.obavjestenja
  drop constraint if exists obavjestenja_glasanje_fk,
  add  constraint obavjestenja_glasanje_fk
       foreign key (glasanje_id) references public.glasanja(id) on delete set null;

alter table public.obavjestenja
  drop constraint if exists obavjestenja_kvar_fk,
  add  constraint obavjestenja_kvar_fk
       foreign key (kvar_id) references public.kvarovi(id) on delete set null;


-- =============================================================================
-- 5. FUNKCIJE NAD TABELAMA
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 5.1  RLS HELPERI
-- -----------------------------------------------------------------------------
--  Sve su SECURITY DEFINER sa fiksiranim `search_path`. Razlog: politika nad
--  `clanstva` koja i sama čita `clanstva` izazvala bi beskonačnu rekurziju.
--  SECURITY DEFINER zaobilazi RLS unutar funkcije i prekida ciklus.
--  Funkcije su namjerno uske — vraćaju samo boolean/uuid, nikad podatke.
-- -----------------------------------------------------------------------------

-- Siguran cast teksta u uuid: vraća NULL umjesto da baci grešku.
-- Koristi se u Storage politikama, gdje prvi segment putanje NIJE garantovano
-- validan uuid — neuspio cast bi inače srušio cijeli upit.
create or replace function public.fn_u_uuid(p_tekst text)
returns uuid
language plpgsql
immutable
as $$
begin
  return p_tekst::uuid;
exception when others then
  return null;
end;
$$;

create or replace function public.je_sistem_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(
    (select k.je_sistem_admin from public.korisnici k where k.id = auth.uid()),
    false
  );
$$;

-- Sve zgrade u kojima prijavljeni korisnik ima aktivno članstvo.
create or replace function public.moje_zgrade()
returns setof uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select distinct c.zgrada_id
  from public.clanstva c
  where c.korisnik_id = auth.uid()
    and c.aktivno
    and (c.vazi_do is null or c.vazi_do >= current_date);
$$;

-- Da li je korisnik član (bilo koje uloge) date zgrade.
create or replace function public.je_clan(p_zgrada_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.je_sistem_admin()
      or exists (
        select 1
        from public.clanstva c
        where c.korisnik_id = auth.uid()
          and c.zgrada_id   = p_zgrada_id
          and c.aktivno
          and (c.vazi_do is null or c.vazi_do >= current_date)
      );
$$;

-- Da li korisnik pripada upravi zgrade (predsjednik / član UO / blagajnik /
-- upravnik → nivo <= 30).
create or replace function public.je_uprava(p_zgrada_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.je_sistem_admin()
      or exists (
        select 1
        from public.clanstva c
        join public.uloge u on u.id = c.uloga_id
        where c.korisnik_id = auth.uid()
          and c.zgrada_id   = p_zgrada_id
          and c.aktivno
          and u.nivo <= 30
          and (c.vazi_do is null or c.vazi_do >= current_date)
      );
$$;

-- Da li je korisnik predsjednik ZEV-a (nivo <= 10) — za najosjetljivije radnje.
create or replace function public.je_predsjednik(p_zgrada_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select public.je_sistem_admin()
      or exists (
        select 1
        from public.clanstva c
        join public.uloge u on u.id = c.uloga_id
        where c.korisnik_id = auth.uid()
          and c.zgrada_id   = p_zgrada_id
          and c.aktivno
          and u.nivo <= 10
          and (c.vazi_do is null or c.vazi_do >= current_date)
      );
$$;

-- Prostori na koje prijavljeni korisnik ima pravo uvida (svoji stanovi).
create or replace function public.moji_stanovi()
returns setof uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select distinct c.stan_id
  from public.clanstva c
  where c.korisnik_id = auth.uid()
    and c.stan_id is not null
    and c.aktivno
    and (c.vazi_do is null or c.vazi_do >= current_date);
$$;

-- Prostori za koje korisnik smije glasati.
create or replace function public.moji_glasacki_stanovi()
returns setof uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select distinct c.stan_id
  from public.clanstva c
  where c.korisnik_id = auth.uid()
    and c.stan_id is not null
    and c.aktivno
    and c.glasacko_pravo
    and (c.vazi_do is null or c.vazi_do >= current_date);
$$;


-- -----------------------------------------------------------------------------
-- 5.2  POSLOVNA LOGIKA — GLASANJE
-- -----------------------------------------------------------------------------

-- Težina glasa jednog prostora, prema načinu glasanja.
create or replace function public.fn_tezina_glasa(
  p_stan_id uuid,
  p_nacin   public.nacin_glasanja
)
returns numeric
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select case p_nacin
    when 'po_stanu'    then 1::numeric
    when 'po_glavi'    then 1::numeric
    when 'po_povrsini' then coalesce(s.suvlasnicki_udio, s.kvadratura, 1)::numeric
  end
  from public.stanovi s
  where s.id = p_stan_id;
$$;

-- Ukupno glasačko tijelo (zbir težina svih prostora sa glasačkim pravom).
create or replace function public.fn_ukupno_glasacko_tijelo(p_glasanje_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(sum(public.fn_tezina_glasa(s.id, g.nacin)), 0)
  from public.glasanja g
  join public.stanovi s on s.zgrada_id = g.zgrada_id and s.aktivan
  where g.id = p_glasanje_id
    and exists (
      select 1 from public.clanstva c
      where c.stan_id = s.id and c.aktivno and c.glasacko_pravo
    );
$$;

-- Prebrojavanje i ocjena rezultata. Vraća JSONB snapshot.
create or replace function public.fn_rezultat_glasanja(p_glasanje_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  g                record;
  v_ukupno         numeric;
  v_izaslo         numeric;
  v_za             numeric;
  v_protiv         numeric;
  v_uzdrzan        numeric;
  v_odziv          numeric;
  v_baza           numeric;
  v_prag           numeric;
  v_kvorum_ispunjen boolean;
  v_usvojeno       boolean;
  v_opcije         jsonb;
begin
  select * into g from public.glasanja where id = p_glasanje_id;
  if not found then
    raise exception 'Glasanje % ne postoji', p_glasanje_id
      using errcode = 'no_data_found';
  end if;

  v_ukupno := public.fn_ukupno_glasacko_tijelo(p_glasanje_id);

  select coalesce(sum(tezina), 0)
    into v_izaslo
    from public.glasovi where glasanje_id = p_glasanje_id;

  v_odziv := case when v_ukupno > 0 then round(100 * v_izaslo / v_ukupno, 2) else 0 end;
  v_kvorum_ispunjen := v_odziv >= g.kvorum_procenat;

  if g.je_visestruko then
    -- Višestruki izbor: nema ZA/PROTIV, samo raspodjela po opcijama.
    select coalesce(jsonb_agg(t.x order by t.redoslijed), '[]'::jsonb)
      into v_opcije
      from (
        select o.redoslijed,
               jsonb_build_object(
                 'opcija_id',    o.id,
                 'tekst',        o.tekst,
                 'redoslijed',   o.redoslijed,
                 'tezina',       coalesce(sum(gl.tezina), 0),
                 'broj_glasova', count(gl.id),
                 'procenat',     case when v_izaslo > 0
                                      then round(100 * coalesce(sum(gl.tezina), 0) / v_izaslo, 2)
                                      else 0 end
               ) as x
        from public.glasanje_opcije o
        left join public.glasovi gl on gl.opcija_id = o.id
        where o.glasanje_id = p_glasanje_id
        group by o.id, o.tekst, o.redoslijed
      ) t;

    return jsonb_build_object(
      'tip',              'visestruko',
      'ukupno_tijelo',    v_ukupno,
      'izaslo',           v_izaslo,
      'odziv_procenat',   v_odziv,
      'kvorum_procenat',  g.kvorum_procenat,
      'kvorum_ispunjen',  v_kvorum_ispunjen,
      'opcije',           v_opcije,
      'obracunato_at',    now()
    );
  end if;

  select
    coalesce(sum(tezina) filter (where opcija = 'za'), 0),
    coalesce(sum(tezina) filter (where opcija = 'protiv'), 0),
    coalesce(sum(tezina) filter (where opcija = 'uzdrzan'), 0)
    into v_za, v_protiv, v_uzdrzan
    from public.glasovi where glasanje_id = p_glasanje_id;

  -- `vecina_svih` se računa u odnosu na cijelo tijelo; ostalo u odnosu na izašle.
  v_baza := case when g.potrebna_vecina = 'vecina_svih' then v_ukupno else v_izaslo end;

  v_prag := case g.potrebna_vecina
              when 'prosta_vecina' then 50.0
              when 'vecina_svih'   then 50.0
              when 'dvije_trecine' then 200.0 / 3.0    -- 66.666…%
              when 'tri_cetvrtine' then 75.0
              when 'jednoglasno'   then 100.0
            end;

  -- Kod 'prosta_vecina' / 'vecina_svih' traži se STROGO više od 50%;
  -- kod kvalifikovanih većina prag se dostiže (>=).
  v_usvojeno := v_kvorum_ispunjen
    and v_baza > 0
    and case
          when g.potrebna_vecina in ('prosta_vecina', 'vecina_svih')
            then (100 * v_za / v_baza) >  v_prag
          -- Tolerancija pokriva periodični razlomak kod 2/3 (66.666…%).
          else (100 * v_za / v_baza) >= v_prag - 0.000001
        end;

  return jsonb_build_object(
    'tip',              'jednostavno',
    'ukupno_tijelo',    v_ukupno,
    'izaslo',           v_izaslo,
    'odziv_procenat',   v_odziv,
    'kvorum_procenat',  g.kvorum_procenat,
    'kvorum_ispunjen',  v_kvorum_ispunjen,
    'za',               v_za,
    'protiv',           v_protiv,
    'uzdrzan',          v_uzdrzan,
    'za_procenat',      case when v_baza > 0 then round(100 * v_za / v_baza, 2) else 0 end,
    'potrebna_vecina',  g.potrebna_vecina,
    'prag_procenat',    round(v_prag::numeric, 2),
    'usvojeno',         v_usvojeno,
    'obracunato_at',    now()
  );
end;
$$;

-- Zatvara glasanje: prebrojava, upisuje snapshot i objavljuje odluku.
-- Poziva se iz cron-a (pg_cron ili Edge Function `zatvori-glasanje`).
create or replace function public.fn_zatvori_glasanje(p_glasanje_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_rezultat jsonb;
  v_usvojeno boolean;
  v_naslov   text;
  v_zgrada   uuid;
begin
  select naslov, zgrada_id into v_naslov, v_zgrada
    from public.glasanja where id = p_glasanje_id for update;

  v_rezultat := public.fn_rezultat_glasanja(p_glasanje_id);
  v_usvojeno := coalesce((v_rezultat->>'usvojeno')::boolean, false);

  update public.glasanja
     set status       = 'zavrseno',
         rezultat     = v_rezultat,
         usvojeno     = v_usvojeno,
         zatvoreno_at = now()
   where id = p_glasanje_id
     and status <> 'zavrseno';

  -- Automatska objava odluke na oglasnoj tabli (transparentnost).
  insert into public.obavjestenja (zgrada_id, tip, naslov, sadrzaj, glasanje_id, objavljeno_at)
  values (
    v_zgrada,
    'odluka',
    'Rezultat glasanja: ' || v_naslov,
    case when v_usvojeno then 'Prijedlog je USVOJEN. ' else 'Prijedlog NIJE usvojen. ' end
      || 'Odziv: ' || (v_rezultat->>'odziv_procenat') || '%.',
    p_glasanje_id,
    now()
  );

  return v_rezultat;
end;
$$;

-- Prelazak 'zakazano' → 'aktivno' i 'aktivno' → 'zavrseno' po isteku roka.
create or replace function public.fn_obradi_istekla_glasanja()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_id    uuid;
  v_broj  integer := 0;
begin
  update public.glasanja
     set status = 'aktivno'
   where status = 'zakazano' and pocetak_at <= now();

  for v_id in
    select id from public.glasanja
     where status = 'aktivno' and kraj_at <= now()
  loop
    perform public.fn_zatvori_glasanje(v_id);
    v_broj := v_broj + 1;
  end loop;

  return v_broj;
end;
$$;


-- -----------------------------------------------------------------------------
-- 5.3  POSLOVNA LOGIKA — FINANSIJE
-- -----------------------------------------------------------------------------

-- Saldo prostora: pozitivno = dug, negativno = pretplata.
create or replace function public.fn_saldo_stana(p_stan_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select coalesce(sum(iznos_predznakom), 0)
  from public.transakcije_uplatnice
  where stan_id = p_stan_id
    and status <> 'otkazana';
$$;

-- Mjesečna naknada za prostor prema pravilima zgrade.
create or replace function public.fn_mjesecna_naknada(p_stan_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select round(z.fiksna_naknada + z.naknada_po_m2 * coalesce(s.kvadratura, 0), 2)
  from public.stanovi s
  join public.zgrade  z on z.id = s.zgrada_id
  where s.id = p_stan_id;
$$;

-- Poziv na broj po modelu 97: <kod zgrade bez crtica><godina><mjesec><oznaka stana>
-- sa dvocifrenom kontrolom na početku.
create or replace function public.fn_poziv_na_broj(
  p_zgrada_kod  text,
  p_stan_oznaka text,
  p_period      date
)
returns text
language plpgsql
immutable
as $$
declare
  v_baza     text;
  v_kontrola integer;
begin
  v_baza := regexp_replace(upper(p_zgrada_kod), '[^A-Z0-9]', '', 'g')
         || to_char(p_period, 'YYYYMM')
         || regexp_replace(upper(p_stan_oznaka), '[^A-Z0-9]', '', 'g');

  -- ISO 7064 MOD 97-10: kontrola = 98 - (baza||'00' mod 97)
  v_kontrola := 98 - public.fn_mod97(v_baza || '00');

  -- Po regionalnoj konvenciji modela 97 kontrolni broj ide NA POČETAK.
  -- Provjera se zato radi nad `baza || kontrola` (vidi fn_provjeri_poziv_na_broj).
  return lpad(v_kontrola::text, 2, '0') || v_baza;
end;
$$;

-- Validacija poziva na broj po modelu 97. Vraća true ako je kontrolni broj
-- ispravan. Koristi se pri ručnom unosu uplate i pri uvozu izvoda banke.
create or replace function public.fn_provjeri_poziv_na_broj(p_poziv text)
returns boolean
language sql
immutable
as $$
  select case
    when p_poziv is null or char_length(btrim(p_poziv)) < 3 then false
    -- Kontrolne cifre se premjeste na kraj; ispravan broj daje ostatak 1.
    else public.fn_mod97(substr(btrim(p_poziv), 3) || substr(btrim(p_poziv), 1, 2)) = 1
  end;
$$;

-- Generisanje QR payload-a za uplatnicu.
--
-- NAPOMENA ZA IMPLEMENTATORA: tačan format QR koda je stvar dogovora sa bankom
-- i razlikuje se po državi. Ovdje su implementirana dva raširena standarda:
--   • EPC069_12 — SEPA EPC QR (podrazumijevani; prihvata ga većina banaka
--                 koje podržavaju "scan-to-pay" u regionu)
--   • IPS_QR    — NBS IPS QR (Srbija)
-- Prije puštanja u produkciju OBAVEZNO validirati payload sa bankom ZEV-a
-- (`zgrade.qr_standard` je zato konfigurabilan po zgradi).
create or replace function public.fn_generisi_qr(
  p_standard      public.qr_standard,
  p_primalac      text,
  p_iban          text,
  p_iznos         numeric,
  p_valuta        text,
  p_poziv_na_broj text,
  p_svrha         text,
  p_swift         text default null
)
returns text
language plpgsql
immutable
as $$
declare
  v_iban text := regexp_replace(coalesce(p_iban, ''), '\s', '', 'g');
begin
  if p_standard = 'BEZ_QR' or v_iban = '' then
    return null;
  end if;

  if p_standard = 'IPS_QR' then
    -- K:PR|V:01|C:1|R:<racun>|N:<primalac>|I:<valuta><iznos>|SF:189|S:<svrha>|RO:97<poziv>
    return concat_ws('|',
      'K:PR', 'V:01', 'C:1',
      'R:' || v_iban,
      'N:' || left(coalesce(p_primalac, ''), 70),
      'I:' || upper(p_valuta) || replace(to_char(p_iznos, 'FM999999990.00'), '.', ','),
      'SF:189',
      'S:' || left(coalesce(p_svrha, ''), 35),
      'RO:97' || coalesce(p_poziv_na_broj, '')
    );
  end if;

  -- EPC069-12 (verzija 002, UTF-8, SCT). Redoslijed linija je dio standarda.
  return concat_ws(E'\n',
    'BCD',                                    -- Service Tag
    '002',                                    -- Version
    '1',                                      -- Character set: 1 = UTF-8
    'SCT',                                    -- Identification
    coalesce(p_swift, ''),                    -- BIC (opciono u v002)
    left(coalesce(p_primalac, ''), 70),       -- Ime primaoca
    v_iban,                                   -- IBAN
    upper(p_valuta) || to_char(p_iznos, 'FM999999990.00'),  -- npr. BAM45.50
    '',                                       -- Purpose code
    coalesce(p_poziv_na_broj, ''),            -- Structured remittance
    '',                                       -- Unstructured remittance
    left(coalesce(p_svrha, ''), 70)           -- Beneficiary to originator info
  );
end;
$$;

-- Masovni obračun mjesečne naknade za jednu zgradu i period.
-- Idempotentno: preskače prostore koji već imaju zaduženje za taj period.
create or replace function public.fn_obracunaj_mjesec(
  p_zgrada_id uuid,
  p_period    date default date_trunc('month', current_date)::date
)
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  z        record;
  s        record;
  v_iznos  numeric;
  v_pnb    text;
  v_broj   integer := 0;
  v_od     date := date_trunc('month', p_period)::date;
  v_do     date := (date_trunc('month', p_period) + interval '1 month' - interval '1 day')::date;
  v_dosp   date;
begin
  -- Kad postoji prijavljeni korisnik, mora biti u upravi. Kad ga nema
  -- (`auth.uid()` je NULL), poziv dolazi od cron-a / service_role ključa —
  -- takav poziv je već autorizovan na nivou infrastrukture.
  if auth.uid() is not null and not public.je_uprava(p_zgrada_id) then
    raise exception 'Nemate ovlaštenje za obračun u ovoj zgradi'
      using errcode = 'insufficient_privilege';
  end if;

  select * into z from public.zgrade where id = p_zgrada_id;
  if not found then
    raise exception 'Zgrada % ne postoji', p_zgrada_id using errcode = 'no_data_found';
  end if;

  v_dosp := v_od + (z.dan_dospijeca - 1);

  for s in
    select * from public.stanovi
     where zgrada_id = p_zgrada_id and aktivan
     order by oznaka
  loop
    -- Idempotentnost: ne dupliraj zaduženje za isti period.
    if exists (
      select 1 from public.transakcije_uplatnice
       where stan_id = s.id and tip = 'zaduzenje' and period_od = v_od
         and status <> 'otkazana'
    ) then
      continue;
    end if;

    v_iznos := round(z.fiksna_naknada + z.naknada_po_m2 * coalesce(s.kvadratura, 0), 2);
    if v_iznos <= 0 then
      continue;
    end if;

    v_pnb := public.fn_poziv_na_broj(z.kod, s.oznaka, v_od);

    insert into public.transakcije_uplatnice (
      zgrada_id, stan_id, kreirao_id, tip, status,
      iznos, valuta, period_od, period_do, opis,
      datum_dokumenta, datum_dospijeca,
      broj_uplatnice, primalac, racun_primaoca, poziv_na_broj, model, sifra_placanja,
      qr_sadrzaj
    ) values (
      p_zgrada_id, s.id, auth.uid(), 'zaduzenje', 'izdata',
      v_iznos, z.valuta, v_od, v_do,
      'Mjesečna naknada za održavanje — ' || to_char(v_od, 'MM/YYYY'),
      current_date, v_dosp,
      z.kod || '-' || to_char(v_od, 'YYYYMM') || '-' || s.oznaka,
      coalesce(z.naziv_primaoca, z.naziv), z.iban, v_pnb, '97', '189',
      public.fn_generisi_qr(
        z.qr_standard,
        coalesce(z.naziv_primaoca, z.naziv),
        z.iban,
        v_iznos,
        z.valuta,
        v_pnb,
        'Naknada ' || to_char(v_od, 'MM/YYYY') || ' stan ' || s.oznaka,
        z.swift
      )
    );

    v_broj := v_broj + 1;
  end loop;

  return v_broj;
end;
$$;


-- -----------------------------------------------------------------------------
-- 5.4  ONBOARDING — iskorištavanje pozivnice
-- -----------------------------------------------------------------------------

create or replace function public.fn_iskoristi_pozivnicu(p_kod text)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  p          record;
  v_clanstvo uuid;
begin
  if auth.uid() is null then
    raise exception 'Niste prijavljeni' using errcode = 'insufficient_privilege';
  end if;

  select * into p
    from public.pozivnice
   where upper(kod) = upper(btrim(p_kod))
   for update;

  if not found then
    raise exception 'Pozivnica ne postoji' using errcode = 'no_data_found';
  end if;
  if p.iskoriscena_at is not null then
    raise exception 'Pozivnica je već iskorištena' using errcode = 'invalid_parameter_value';
  end if;
  if p.istice_at < now() then
    raise exception 'Pozivnica je istekla' using errcode = 'invalid_parameter_value';
  end if;

  insert into public.clanstva (korisnik_id, zgrada_id, stan_id, uloga_id, tip)
  values (auth.uid(), p.zgrada_id, p.stan_id, p.uloga_id, p.tip)
  on conflict (korisnik_id, zgrada_id, stan_id)
  do update set aktivno = true, azurirano_at = now()
  returning id into v_clanstvo;

  update public.pozivnice
     set iskoriscena_at = now(), iskoristio_id = auth.uid()
   where id = p.id;

  return v_clanstvo;
end;
$$;


-- =============================================================================
-- 6. TRIGERI
-- =============================================================================

-- 6.1  `azurirano_at` na svim tabelama koje ga imaju ---------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'korisnici', 'zgrade', 'stanovi', 'clanstva', 'obavjestenja', 'glasanja',
    'kvarovi', 'komentari', 'transakcije_uplatnice', 'troskovi_zev', 'kontakti'
  ] loop
    execute format(
      'drop trigger if exists trg_touch_%1$s on public.%1$I;
       create trigger trg_touch_%1$s before update on public.%1$I
       for each row execute function public.fn_touch_azurirano_at();', t
    );
  end loop;
end $$;


-- 6.2  Kreiranje profila pri registraciji -------------------------------------
--  Supabase Auth upisuje red u `auth.users`; ovdje pravimo prateći profil.
--  Metapodaci sa klijenta stižu kroz `raw_user_meta_data`.

create or replace function public.fn_novi_korisnik()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.korisnici (id, email, telefon, ime, prezime)
  values (
    new.id,
    new.email,
    new.phone,
    nullif(new.raw_user_meta_data->>'ime', ''),
    nullif(new.raw_user_meta_data->>'prezime', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.fn_novi_korisnik();


-- 6.3  Redni broj tiketa po zgradi --------------------------------------------

create or replace function public.fn_dodijeli_broj_kvara()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.broj is null or new.broj = 0 then
    -- Zaključavanje reda zgrade serijalizuje istovremene prijave.
    perform 1 from public.zgrade where id = new.zgrada_id for update;
    select coalesce(max(broj), 0) + 1 into new.broj
      from public.kvarovi where zgrada_id = new.zgrada_id;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_broj_kvara on public.kvarovi;
create trigger trg_broj_kvara
  before insert on public.kvarovi
  for each row execute function public.fn_dodijeli_broj_kvara();


-- 6.4  Brojač potvrda kvara ---------------------------------------------------

create or replace function public.fn_osvjezi_broj_potvrda()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_kvar uuid := coalesce(new.kvar_id, old.kvar_id);
begin
  update public.kvarovi
     set broj_potvrda = (select count(*) from public.kvar_potvrde where kvar_id = v_kvar)
   where id = v_kvar;
  return null;
end;
$$;

drop trigger if exists trg_broj_potvrda on public.kvar_potvrde;
create trigger trg_broj_potvrda
  after insert or delete on public.kvar_potvrde
  for each row execute function public.fn_osvjezi_broj_potvrda();


-- 6.5  Validacija i težina glasa ----------------------------------------------
--  Provjerava se u BAZI, ne samo u aplikaciji: glasanje mora biti aktivno,
--  korisnik mora imati glasačko pravo za taj prostor, a težina se snima
--  kao snapshot.

create or replace function public.fn_validiraj_glas()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  g record;
begin
  select * into g from public.glasanja where id = new.glasanje_id;
  if not found then
    raise exception 'Glasanje ne postoji' using errcode = 'no_data_found';
  end if;

  if g.status <> 'aktivno' then
    raise exception 'Glasanje nije aktivno (status: %)', g.status
      using errcode = 'invalid_parameter_value';
  end if;
  if now() < g.pocetak_at or now() > g.kraj_at then
    raise exception 'Glasanje je izvan predviđenog roka'
      using errcode = 'invalid_parameter_value';
  end if;

  -- Glas se uvijek pripisuje prijavljenom korisniku — klijent ne može
  -- glasati u tuđe ime. Kod uvoza preko service_role ključa (`auth.uid()`
  -- je NULL) zadržava se proslijeđeni korisnik.
  new.korisnik_id := coalesce(auth.uid(), new.korisnik_id);

  if not exists (
    select 1 from public.clanstva c
     where c.korisnik_id   = auth.uid()
       and c.stan_id       = new.stan_id
       and c.zgrada_id     = g.zgrada_id
       and c.aktivno
       and c.glasacko_pravo
       and (c.vazi_do is null or c.vazi_do >= current_date)
  ) then
    raise exception 'Nemate glasačko pravo za ovaj prostor'
      using errcode = 'insufficient_privilege';
  end if;

  if g.je_visestruko and new.opcija_id is null then
    raise exception 'Ovo glasanje zahtijeva izbor jedne od ponuđenih opcija'
      using errcode = 'invalid_parameter_value';
  end if;
  if not g.je_visestruko and new.opcija is null then
    raise exception 'Odaberite ZA, PROTIV ili UZDRŽAN'
      using errcode = 'invalid_parameter_value';
  end if;

  if tg_op = 'INSERT' then
    new.tezina := public.fn_tezina_glasa(new.stan_id, g.nacin);
  else
    if not g.dozvoli_izmjenu then
      raise exception 'Izmjena glasa nije dozvoljena za ovo glasanje'
        using errcode = 'insufficient_privilege';
    end if;
    -- Težina ostaje snapshot iz trenutka prvog glasanja.
    new.tezina         := old.tezina;
    new.stan_id        := old.stan_id;
    new.glasanje_id    := old.glasanje_id;
    new.izmijenjeno_at := now();
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validiraj_glas on public.glasovi;
create trigger trg_validiraj_glas
  before insert or update on public.glasovi
  for each row execute function public.fn_validiraj_glas();


-- 6.6  Knjiženje je append-only ------------------------------------------------
--  Dozvoljena su samo polja koja opisuju NAPLATU (status, uparivanje sa izvodom),
--  nikad iznos, tip ili prostor. Ispravka ide isključivo kroz `storno` stavku.

create or replace function public.fn_zabrani_izmjenu_knjizenja()
returns trigger
language plpgsql
as $$
begin
  if new.iznos    is distinct from old.iznos
  or new.tip      is distinct from old.tip
  or new.stan_id  is distinct from old.stan_id
  or new.zgrada_id is distinct from old.zgrada_id
  or new.period_od is distinct from old.period_od then
    raise exception
      'Knjižena stavka se ne smije mijenjati. Napravite storno stavku umjesto izmjene.'
      using errcode = 'integrity_constraint_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_append_only_knjizenje on public.transakcije_uplatnice;
create trigger trg_append_only_knjizenje
  before update on public.transakcije_uplatnice
  for each row execute function public.fn_zabrani_izmjenu_knjizenja();


-- 6.7  Automatsko popunjavanje QR podataka na uplatnici ------------------------

create or replace function public.fn_popuni_uplatnicu()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  z record;
  s record;
begin
  if new.tip <> 'zaduzenje' then
    return new;
  end if;

  select * into z from public.zgrade  where id = new.zgrada_id;
  select * into s from public.stanovi where id = new.stan_id;

  new.primalac       := coalesce(new.primalac, z.naziv_primaoca, z.naziv);
  new.racun_primaoca := coalesce(new.racun_primaoca, z.iban);
  new.model          := coalesce(new.model, '97');
  new.sifra_placanja := coalesce(new.sifra_placanja, '189');
  new.poziv_na_broj  := coalesce(
    new.poziv_na_broj,
    public.fn_poziv_na_broj(z.kod, s.oznaka, coalesce(new.period_od, new.datum_dokumenta))
  );
  new.qr_sadrzaj := coalesce(
    new.qr_sadrzaj,
    public.fn_generisi_qr(
      z.qr_standard, new.primalac, new.racun_primaoca,
      new.iznos, new.valuta, new.poziv_na_broj, new.opis, z.swift
    )
  );

  return new;
end;
$$;

drop trigger if exists trg_popuni_uplatnicu on public.transakcije_uplatnice;
create trigger trg_popuni_uplatnicu
  before insert on public.transakcije_uplatnice
  for each row execute function public.fn_popuni_uplatnicu();


-- 6.8  Zaštita članstva od eskalacije privilegija ------------------------------
--  Ako korisnik ažurira svoj red članstva, a NIJE u upravi te zgrade, sva
--  osjetljiva polja se vraćaju na stare vrijednosti. Stanar tako ne može sam
--  sebi dodijeliti ulogu predsjednika ili glasačko pravo.

create or replace function public.fn_zastiti_clanstvo()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if public.je_uprava(old.zgrada_id) then
    return new;                      -- uprava smije mijenjati sve
  end if;

  new.uloga_id       := old.uloga_id;
  new.zgrada_id      := old.zgrada_id;
  new.stan_id        := old.stan_id;
  new.tip            := old.tip;
  new.glasacko_pravo := old.glasacko_pravo;
  new.udio           := old.udio;
  new.aktivno        := old.aktivno;
  new.vazi_od        := old.vazi_od;
  new.vazi_do        := old.vazi_do;

  return new;
end;
$$;

drop trigger if exists trg_zastiti_clanstvo on public.clanstva;
create trigger trg_zastiti_clanstvo
  before update on public.clanstva
  for each row execute function public.fn_zastiti_clanstvo();


-- 6.9  Audit trag za osjetljive tabele ----------------------------------------

create or replace function public.fn_audit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_zgrada uuid;
  v_zapis  text;
begin
  v_zgrada := case
    when tg_op = 'DELETE' then (to_jsonb(old)->>'zgrada_id')::uuid
    else (to_jsonb(new)->>'zgrada_id')::uuid
  end;
  v_zapis := case when tg_op = 'DELETE' then to_jsonb(old)->>'id' else to_jsonb(new)->>'id' end;

  insert into public.audit_log (
    zgrada_id, korisnik_id, tabela, zapis_id, radnja, stare_vrijednosti, nove_vrijednosti
  ) values (
    v_zgrada, auth.uid(), tg_table_name, v_zapis, tg_op,
    case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end,
    case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end
  );

  return coalesce(new, old);
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'glasanja', 'transakcije_uplatnice', 'troskovi_zev', 'clanstva', 'stanovi'
  ] loop
    execute format(
      'drop trigger if exists trg_audit_%1$s on public.%1$I;
       create trigger trg_audit_%1$s after insert or update or delete on public.%1$I
       for each row execute function public.fn_audit();', t
    );
  end loop;
end $$;


-- =============================================================================
-- 7. POGLEDI (VIEWS)
-- =============================================================================
--  Pogledi nasljeđuju RLS osnovnih tabela jer su definisani sa
--  `security_invoker = true` (PostgreSQL 15+). Bez toga bi pogled radio sa
--  ovlaštenjima vlasnika i procurio podatke drugih zgrada.

-- 7.1  Stanje po prostoru -----------------------------------------------------

create or replace view public.pogled_stanje_stana
with (security_invoker = true) as
select
  s.id                                        as stan_id,
  s.zgrada_id,
  s.oznaka,
  s.ulaz,
  s.kvadratura,
  coalesce(sum(t.iznos_predznakom), 0)        as saldo,
  coalesce(sum(t.iznos) filter (where t.tip = 'zaduzenje'), 0) as ukupno_zaduzeno,
  coalesce(sum(t.iznos) filter (where t.tip = 'uplata'),    0) as ukupno_placeno,
  coalesce(sum(t.iznos_predznakom) filter (
    where t.tip in ('zaduzenje', 'kamata')
      and t.datum_dospijeca < current_date
      and t.status <> 'placena'
  ), 0)                                       as dospjeli_dug,
  max(t.datum_uplate) filter (where t.tip = 'uplata') as zadnja_uplata
from public.stanovi s
left join public.transakcije_uplatnice t
       on t.stan_id = s.id and t.status <> 'otkazana'
group by s.id, s.zgrada_id, s.oznaka, s.ulaz, s.kvadratura;


-- 7.2  Finansijski pregled zgrade (transparentnost fonda) ---------------------

create or replace view public.pogled_stanje_zgrade
with (security_invoker = true) as
select
  z.id                                        as zgrada_id,
  z.naziv,
  z.valuta,
  (select coalesce(sum(t.iznos), 0)
     from public.transakcije_uplatnice t
    where t.zgrada_id = z.id and t.tip = 'uplata' and t.status <> 'otkazana')
                                              as ukupno_prihod_stanari,
  (select coalesce(sum(tz.iznos), 0)
     from public.troskovi_zev tz
    where tz.zgrada_id = z.id and tz.smjer = 'prihod')
                                              as ukupno_ostali_prihodi,
  (select coalesce(sum(tz.iznos), 0)
     from public.troskovi_zev tz
    where tz.zgrada_id = z.id and tz.smjer = 'rashod')
                                              as ukupno_rashodi,
  (select coalesce(sum(t.iznos_predznakom), 0)
     from public.transakcije_uplatnice t
    where t.zgrada_id = z.id and t.status <> 'otkazana')
                                              as ukupna_potrazivanja,
  (select count(*) from public.stanovi s where s.zgrada_id = z.id and s.aktivan)
                                              as broj_prostora
from public.zgrade z;


-- 7.3  Imenik zgrade ----------------------------------------------------------

create or replace view public.pogled_imenik
with (security_invoker = true) as
select
  c.zgrada_id,
  c.stan_id,
  s.oznaka        as stan_oznaka,
  s.ulaz,
  s.sprat,
  k.id            as korisnik_id,
  k.puno_ime,
  k.avatar_url,
  case when c.vidljiv_u_imeniku then k.telefon else null end as telefon,
  case when c.vidljiv_u_imeniku then k.email   else null end as email,
  u.kod           as uloga_kod,
  u.naziv         as uloga_naziv,
  c.tip           as tip_clanstva
from public.clanstva c
join public.korisnici k on k.id = c.korisnik_id
join public.uloge     u on u.id = c.uloga_id
left join public.stanovi s on s.id = c.stan_id
where c.aktivno;


-- 7.4  Pregled glasanja sa uživo rezultatom -----------------------------------

create or replace view public.pogled_glasanja
with (security_invoker = true) as
select
  g.*,
  (select count(*) from public.glasovi gl where gl.glasanje_id = g.id) as broj_glasova,
  exists (
    select 1 from public.glasovi gl
     where gl.glasanje_id = g.id and gl.korisnik_id = auth.uid()
  ) as ja_glasao,
  case
    when g.status = 'zavrseno' then g.rezultat
    when g.tajno then null                       -- kod tajnog glasanja nema uživo rezultata
    else public.fn_rezultat_glasanja(g.id)
  end as trenutni_rezultat
from public.glasanja g;


-- =============================================================================
-- 8. ROW LEVEL SECURITY
-- =============================================================================
--  Model: sve je zabranjeno dok se eksplicitno ne dozvoli.
--    • ČITANJE  — svi aktivni članovi zgrade
--    • PISANJE  — uprava (nivo <= 30), uz izuzetke (stanar prijavljuje kvar,
--                 stanar glasa, stanar mijenja svoj profil)
--    • FINANSIJE — stanar vidi SAMO svoje stavke; uprava vidi sve
-- -----------------------------------------------------------------------------

alter table public.uloge                  enable row level security;
alter table public.korisnici              enable row level security;
alter table public.zgrade                 enable row level security;
alter table public.stanovi                enable row level security;
alter table public.clanstva               enable row level security;
alter table public.pozivnice              enable row level security;
alter table public.obavjestenja           enable row level security;
alter table public.glasanja               enable row level security;
alter table public.glasanje_opcije        enable row level security;
alter table public.glasovi                enable row level security;
alter table public.kvarovi                enable row level security;
alter table public.kvar_potvrde           enable row level security;
alter table public.komentari              enable row level security;
alter table public.transakcije_uplatnice  enable row level security;
alter table public.troskovi_zev           enable row level security;
alter table public.dokumenti              enable row level security;
alter table public.prilozi                enable row level security;
alter table public.kontakti               enable row level security;
alter table public.push_tokeni            enable row level security;
alter table public.dnevnik_obavjestavanja enable row level security;
alter table public.audit_log              enable row level security;


-- 8.1  ULOGE — šifarnik, svi prijavljeni čitaju ------------------------------

drop policy if exists uloge_select on public.uloge;
create policy uloge_select on public.uloge
  for select to authenticated using (true);


-- 8.2  KORISNICI --------------------------------------------------------------
--  Korisnik vidi sebe + sve sa kojima dijeli zgradu (potrebno za imenik).

drop policy if exists korisnici_select on public.korisnici;
create policy korisnici_select on public.korisnici
  for select to authenticated
  using (
    id = auth.uid()
    or public.je_sistem_admin()
    or exists (
      select 1 from public.clanstva c
      where c.korisnik_id = korisnici.id
        and c.aktivno
        and c.zgrada_id in (select public.moje_zgrade())
    )
  );

drop policy if exists korisnici_update_self on public.korisnici;
create policy korisnici_update_self on public.korisnici
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());


-- 8.3  ZGRADE -----------------------------------------------------------------

drop policy if exists zgrade_select on public.zgrade;
create policy zgrade_select on public.zgrade
  for select to authenticated
  using (id in (select public.moje_zgrade()) or public.je_sistem_admin());

-- Svaki prijavljeni korisnik može osnovati novu ZEV (postaje predsjednik —
-- vidi `fn_osnuj_zev` u aplikacijskom sloju / Edge Function).
drop policy if exists zgrade_insert on public.zgrade;
create policy zgrade_insert on public.zgrade
  for insert to authenticated with check (true);

drop policy if exists zgrade_update on public.zgrade;
create policy zgrade_update on public.zgrade
  for update to authenticated
  using (public.je_uprava(id))
  with check (public.je_uprava(id));

drop policy if exists zgrade_delete on public.zgrade;
create policy zgrade_delete on public.zgrade
  for delete to authenticated
  using (public.je_predsjednik(id));


-- 8.4  STANOVI ----------------------------------------------------------------

drop policy if exists stanovi_select on public.stanovi;
create policy stanovi_select on public.stanovi
  for select to authenticated using (public.je_clan(zgrada_id));

drop policy if exists stanovi_write on public.stanovi;
create policy stanovi_write on public.stanovi
  for all to authenticated
  using (public.je_uprava(zgrada_id))
  with check (public.je_uprava(zgrada_id));


-- 8.5  CLANSTVA ---------------------------------------------------------------

drop policy if exists clanstva_select on public.clanstva;
create policy clanstva_select on public.clanstva
  for select to authenticated
  using (korisnik_id = auth.uid() or public.je_clan(zgrada_id));

drop policy if exists clanstva_write on public.clanstva;
create policy clanstva_write on public.clanstva
  for all to authenticated
  using (public.je_uprava(zgrada_id))
  with check (public.je_uprava(zgrada_id));

-- Stanar smije ažurirati SVOJ red članstva (praktično: vidljivost u imeniku).
--
-- Zaštita od eskalacije privilegija NIJE u ovoj politici nego u trigeru
-- `trg_zastiti_clanstvo` (sekcija 6.8). Razlog: politika koja bi u WITH CHECK-u
-- čitala staru vrijednost iz `public.clanstva` rekurzivno pokreće samu sebe i
-- PostgreSQL javlja "infinite recursion detected in policy for relation".
drop policy if exists clanstva_update_self on public.clanstva;
create policy clanstva_update_self on public.clanstva
  for update to authenticated
  using (korisnik_id = auth.uid())
  with check (korisnik_id = auth.uid());


-- 8.6  POZIVNICE --------------------------------------------------------------
--  Namjerno NEMA SELECT politike za obične korisnike: kod se ne smije moći
--  pobrojati. Iskorištavanje ide isključivo kroz `fn_iskoristi_pozivnicu()`
--  (SECURITY DEFINER), koja traži tačan kod.

drop policy if exists pozivnice_uprava on public.pozivnice;
create policy pozivnice_uprava on public.pozivnice
  for all to authenticated
  using (public.je_uprava(zgrada_id))
  with check (public.je_uprava(zgrada_id));


-- 8.7  OBAVJESTENJA -----------------------------------------------------------

drop policy if exists obavjestenja_select on public.obavjestenja;
create policy obavjestenja_select on public.obavjestenja
  for select to authenticated
  using (
    public.je_clan(zgrada_id)
    and (objavljeno_at is not null or public.je_uprava(zgrada_id))
  );

drop policy if exists obavjestenja_write on public.obavjestenja;
create policy obavjestenja_write on public.obavjestenja
  for all to authenticated
  using (public.je_uprava(zgrada_id))
  with check (public.je_uprava(zgrada_id));


-- 8.8  GLASANJA ---------------------------------------------------------------
--  Nacrt vidi samo uprava — inače bi stanari vidjeli prijedloge prije objave.

drop policy if exists glasanja_select on public.glasanja;
create policy glasanja_select on public.glasanja
  for select to authenticated
  using (
    public.je_clan(zgrada_id)
    and (status <> 'nacrt' or public.je_uprava(zgrada_id))
  );

drop policy if exists glasanja_write on public.glasanja;
create policy glasanja_write on public.glasanja
  for all to authenticated
  using (public.je_uprava(zgrada_id))
  with check (public.je_uprava(zgrada_id));

drop policy if exists glasanje_opcije_select on public.glasanje_opcije;
create policy glasanje_opcije_select on public.glasanje_opcije
  for select to authenticated
  using (exists (
    select 1 from public.glasanja g
     where g.id = glasanje_opcije.glasanje_id
       and public.je_clan(g.zgrada_id)
       and (g.status <> 'nacrt' or public.je_uprava(g.zgrada_id))
  ));

drop policy if exists glasanje_opcije_write on public.glasanje_opcije;
create policy glasanje_opcije_write on public.glasanje_opcije
  for all to authenticated
  using (exists (
    select 1 from public.glasanja g
     where g.id = glasanje_opcije.glasanje_id and public.je_uprava(g.zgrada_id)
  ))
  with check (exists (
    select 1 from public.glasanja g
     where g.id = glasanje_opcije.glasanje_id and public.je_uprava(g.zgrada_id)
  ));


-- 8.9  GLASOVI ----------------------------------------------------------------
--  Kod TAJNOG glasanja niko ne vidi tuđe glasove — ni uprava. Rezultat se
--  dobija isključivo agregatom kroz `fn_rezultat_glasanja()` (SECURITY DEFINER).
--  Kod javnog glasanja svi članovi vide ko je kako glasao (transparentnost).

drop policy if exists glasovi_select on public.glasovi;
create policy glasovi_select on public.glasovi
  for select to authenticated
  using (
    korisnik_id = auth.uid()
    or exists (
      select 1 from public.glasanja g
       where g.id = glasovi.glasanje_id
         and not g.tajno
         and public.je_clan(g.zgrada_id)
    )
  );

drop policy if exists glasovi_insert on public.glasovi;
create policy glasovi_insert on public.glasovi
  for insert to authenticated
  with check (
    korisnik_id = auth.uid()
    and stan_id in (select public.moji_glasacki_stanovi())
  );

drop policy if exists glasovi_update on public.glasovi;
create policy glasovi_update on public.glasovi
  for update to authenticated
  using (korisnik_id = auth.uid())
  with check (korisnik_id = auth.uid());

-- Brisanje glasa NIJE dozvoljeno nikome — integritet izborne evidencije.


-- 8.10  KVAROVI ---------------------------------------------------------------

drop policy if exists kvarovi_select on public.kvarovi;
create policy kvarovi_select on public.kvarovi
  for select to authenticated using (public.je_clan(zgrada_id));

-- Svaki član smije prijaviti kvar.
drop policy if exists kvarovi_insert on public.kvarovi;
create policy kvarovi_insert on public.kvarovi
  for insert to authenticated
  with check (public.je_clan(zgrada_id) and prijavio_id = auth.uid());

-- Uprava mijenja sve; prijavitelj smije dopuniti opis dok je tiket još u
-- statusu 'prijavljen'.
drop policy if exists kvarovi_update on public.kvarovi;
create policy kvarovi_update on public.kvarovi
  for update to authenticated
  using (
    public.je_uprava(zgrada_id)
    or (prijavio_id = auth.uid() and status = 'prijavljen')
  )
  with check (
    public.je_uprava(zgrada_id)
    or (prijavio_id = auth.uid() and status = 'prijavljen')
  );

drop policy if exists kvarovi_delete on public.kvarovi;
create policy kvarovi_delete on public.kvarovi
  for delete to authenticated using (public.je_uprava(zgrada_id));

drop policy if exists kvar_potvrde_select on public.kvar_potvrde;
create policy kvar_potvrde_select on public.kvar_potvrde
  for select to authenticated
  using (exists (
    select 1 from public.kvarovi k
     where k.id = kvar_potvrde.kvar_id and public.je_clan(k.zgrada_id)
  ));

drop policy if exists kvar_potvrde_write on public.kvar_potvrde;
create policy kvar_potvrde_write on public.kvar_potvrde
  for all to authenticated
  using (korisnik_id = auth.uid())
  with check (
    korisnik_id = auth.uid()
    and exists (
      select 1 from public.kvarovi k
       where k.id = kvar_potvrde.kvar_id and public.je_clan(k.zgrada_id)
    )
  );


-- 8.11  KOMENTARI -------------------------------------------------------------

drop policy if exists komentari_select on public.komentari;
create policy komentari_select on public.komentari
  for select to authenticated
  using (
    public.je_clan(zgrada_id)
    and not obrisan
    and (not interni or public.je_uprava(zgrada_id))
  );

drop policy if exists komentari_insert on public.komentari;
create policy komentari_insert on public.komentari
  for insert to authenticated
  with check (
    public.je_clan(zgrada_id)
    and autor_id = auth.uid()
    and (not interni or public.je_uprava(zgrada_id))
  );

drop policy if exists komentari_update on public.komentari;
create policy komentari_update on public.komentari
  for update to authenticated
  using (autor_id = auth.uid() or public.je_uprava(zgrada_id))
  with check (autor_id = auth.uid() or public.je_uprava(zgrada_id));


-- 8.12  TRANSAKCIJE_UPLATNICE -------------------------------------------------
--  Najosjetljivija tabela: stanar NE SMIJE vidjeti dugove komšija.

drop policy if exists tu_select on public.transakcije_uplatnice;
create policy tu_select on public.transakcije_uplatnice
  for select to authenticated
  using (
    stan_id in (select public.moji_stanovi())
    or public.je_uprava(zgrada_id)
  );

drop policy if exists tu_insert on public.transakcije_uplatnice;
create policy tu_insert on public.transakcije_uplatnice
  for insert to authenticated
  with check (public.je_uprava(zgrada_id));

drop policy if exists tu_update on public.transakcije_uplatnice;
create policy tu_update on public.transakcije_uplatnice
  for update to authenticated
  using (public.je_uprava(zgrada_id))
  with check (public.je_uprava(zgrada_id));

-- Brisanje knjiženja nije dozvoljeno nikome (append-only knjiga).


-- 8.13  TROSKOVI_ZEV — transparentnost: SVI članovi vide sve troškove ---------

drop policy if exists troskovi_select on public.troskovi_zev;
create policy troskovi_select on public.troskovi_zev
  for select to authenticated using (public.je_clan(zgrada_id));

drop policy if exists troskovi_write on public.troskovi_zev;
create policy troskovi_write on public.troskovi_zev
  for all to authenticated
  using (public.je_uprava(zgrada_id))
  with check (public.je_uprava(zgrada_id));


-- 8.14  DOKUMENTI i PRILOZI ---------------------------------------------------

drop policy if exists dokumenti_select on public.dokumenti;
create policy dokumenti_select on public.dokumenti
  for select to authenticated
  using (public.je_clan(zgrada_id) and (javni or public.je_uprava(zgrada_id)));

drop policy if exists dokumenti_write on public.dokumenti;
create policy dokumenti_write on public.dokumenti
  for all to authenticated
  using (public.je_uprava(zgrada_id))
  with check (public.je_uprava(zgrada_id));

drop policy if exists prilozi_select on public.prilozi;
create policy prilozi_select on public.prilozi
  for select to authenticated
  using (
    public.je_clan(zgrada_id)
    and (
      transakcija_id is null                    -- prilozi uz finansije su privatni
      or public.je_uprava(zgrada_id)
      or exists (
        select 1 from public.transakcije_uplatnice t
         where t.id = prilozi.transakcija_id
           and t.stan_id in (select public.moji_stanovi())
      )
    )
  );

drop policy if exists prilozi_insert on public.prilozi;
create policy prilozi_insert on public.prilozi
  for insert to authenticated
  with check (public.je_clan(zgrada_id) and postavio_id = auth.uid());

drop policy if exists prilozi_delete on public.prilozi;
create policy prilozi_delete on public.prilozi
  for delete to authenticated
  using (postavio_id = auth.uid() or public.je_uprava(zgrada_id));


-- 8.15  KONTAKTI --------------------------------------------------------------

drop policy if exists kontakti_select on public.kontakti;
create policy kontakti_select on public.kontakti
  for select to authenticated using (public.je_clan(zgrada_id));

drop policy if exists kontakti_write on public.kontakti;
create policy kontakti_write on public.kontakti
  for all to authenticated
  using (public.je_uprava(zgrada_id))
  with check (public.je_uprava(zgrada_id));


-- 8.16  PUSH TOKENI i DNEVNIK -------------------------------------------------

drop policy if exists push_tokeni_own on public.push_tokeni;
create policy push_tokeni_own on public.push_tokeni
  for all to authenticated
  using (korisnik_id = auth.uid())
  with check (korisnik_id = auth.uid());

drop policy if exists dnevnik_select on public.dnevnik_obavjestavanja;
create policy dnevnik_select on public.dnevnik_obavjestavanja
  for select to authenticated
  using (korisnik_id = auth.uid() or public.je_uprava(zgrada_id));


-- 8.17  AUDIT_LOG — samo čitanje, samo uprava ---------------------------------

drop policy if exists audit_select on public.audit_log;
create policy audit_select on public.audit_log
  for select to authenticated
  using (zgrada_id is not null and public.je_uprava(zgrada_id));


-- =============================================================================
-- 9. STORAGE — bucketi i politike
-- =============================================================================
--  Konvencija putanje: <bucket>/<zgrada_id>/<entitet>/<uuid>.<ext>
--  Prvi segment putanje je UVIJEK zgrada_id — na njemu se zasniva izolacija.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('kvarovi',    'kvarovi',    false, 10485760,
   array['image/jpeg', 'image/png', 'image/webp', 'image/heic']),
  ('dokumenti',  'dokumenti',  false, 26214400,
   array['application/pdf', 'image/jpeg', 'image/png',
         'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
         'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
  ('avatari',    'avatari',    true,   2097152,
   array['image/jpeg', 'image/png', 'image/webp']),
  ('logotipi',   'logotipi',   true,   2097152,
   array['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'])
on conflict (id) do nothing;


-- Članovi zgrade čitaju fajlove svoje zgrade.
drop policy if exists storage_zgrada_select on storage.objects;
create policy storage_zgrada_select on storage.objects
  for select to authenticated
  using (
    bucket_id in ('kvarovi', 'dokumenti')
    and public.je_clan(public.fn_u_uuid((storage.foldername(name))[1]))
  );

-- Članovi zgrade postavljaju slike kvarova.
drop policy if exists storage_kvarovi_insert on storage.objects;
create policy storage_kvarovi_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'kvarovi'
    and public.je_clan(public.fn_u_uuid((storage.foldername(name))[1]))
  );

-- Dokumente postavlja samo uprava.
drop policy if exists storage_dokumenti_insert on storage.objects;
create policy storage_dokumenti_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'dokumenti'
    and public.je_uprava(public.fn_u_uuid((storage.foldername(name))[1]))
  );

-- Brisanje: uprava zgrade.
drop policy if exists storage_zgrada_delete on storage.objects;
create policy storage_zgrada_delete on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('kvarovi', 'dokumenti')
    and public.je_uprava(public.fn_u_uuid((storage.foldername(name))[1]))
  );

-- Avatar: korisnik upravlja svojim folderom <korisnik_id>/...
drop policy if exists storage_avatar_write on storage.objects;
create policy storage_avatar_write on storage.objects
  for all to authenticated
  using (bucket_id = 'avatari' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatari' and (storage.foldername(name))[1] = auth.uid()::text);


-- =============================================================================
-- 10. REALTIME
-- =============================================================================
--  Realtime poštuje RLS, pa je sigurno objaviti ove tabele. Namjerno NISU
--  uključene `transakcije_uplatnice` (nema potrebe za live-om, a smanjuje
--  površinu izloženosti) ni `audit_log`.

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table
      public.obavjestenja, public.kvarovi, public.komentari,
      public.glasanja, public.glasovi, public.kvar_potvrde;
  end if;
exception when duplicate_object then
  null;   -- tabele su već u publikaciji
end $$;

-- REPLICA IDENTITY FULL je potreban da Realtime šalje `old_record` kod UPDATE/DELETE.
alter table public.kvarovi      replica identity full;
alter table public.glasanja     replica identity full;
alter table public.obavjestenja replica identity full;


-- =============================================================================
-- 11. SEED — šifarnik uloga
-- =============================================================================

insert into public.uloge (id, kod, naziv, opis, nivo, dozvole) values
  (1,  'sistem_admin', 'Sistem administrator',
       'Administrator platforme (MojZEV tim). Pristup svim zgradama.', 0,
       '{"sve": true}'::jsonb),
  (10, 'predsjednik',  'Predsjednik ZEV-a',
       'Zakonski zastupnik zajednice. Puna prava nad zgradom.', 10,
       '{"zgrada": ["citaj","pisi","brisi"], "finansije": ["citaj","pisi"], "glasanja": ["citaj","pisi"], "kvarovi": ["citaj","pisi"], "clanovi": ["citaj","pisi"]}'::jsonb),
  (20, 'clan_uo',      'Član upravnog odbora',
       'Član UO. Upravlja obavještenjima, glasanjima i kvarovima.', 20,
       '{"zgrada": ["citaj","pisi"], "finansije": ["citaj","pisi"], "glasanja": ["citaj","pisi"], "kvarovi": ["citaj","pisi"], "clanovi": ["citaj","pisi"]}'::jsonb),
  (25, 'blagajnik',    'Blagajnik',
       'Vodi finansije: zaduženja, uplate, uplatnice, troškovi.', 25,
       '{"finansije": ["citaj","pisi"], "kvarovi": ["citaj"], "clanovi": ["citaj"]}'::jsonb),
  (30, 'upravnik',     'Upravnik',
       'Angažovani profesionalni upravnik (opciono).', 30,
       '{"zgrada": ["citaj","pisi"], "finansije": ["citaj"], "kvarovi": ["citaj","pisi"]}'::jsonb),
  (50, 'vlasnik',      'Etažni vlasnik',
       'Vlasnik prostora. Glasa, prijavljuje kvarove, vidi svoje finansije.', 50,
       '{"zgrada": ["citaj"], "finansije": ["citaj_svoje"], "glasanja": ["citaj","glasaj"], "kvarovi": ["citaj","prijavi"]}'::jsonb),
  (60, 'podstanar',    'Podstanar',
       'Najmoprimac. Bez glasačkog prava, vidi obavještenja i prijavljuje kvarove.', 60,
       '{"zgrada": ["citaj"], "glasanja": ["citaj"], "kvarovi": ["citaj","prijavi"]}'::jsonb)
on conflict (id) do update set
  naziv   = excluded.naziv,
  opis    = excluded.opis,
  nivo    = excluded.nivo,
  dozvole = excluded.dozvole;


-- =============================================================================
-- 12. DOZVOLE ZA API ULOGE
-- =============================================================================
--  Supabase PostgREST koristi role `anon` i `authenticated`. RLS je stvarna
--  kontrola pristupa; GRANT samo otvara tabelu za API.

grant usage on schema public to anon, authenticated;

grant select on all tables    in schema public to authenticated;
grant insert, update, delete on all tables in schema public to authenticated;
grant usage  on all sequences in schema public to authenticated;
grant execute on all functions in schema public to authenticated;

-- Anonimni korisnik nema pristup ničemu osim šifarnika uloga (za registracioni ekran).
grant select on public.uloge to anon;

alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public
  grant usage on sequences to authenticated;


-- =============================================================================
--  KRAJ SHEME
-- =============================================================================
