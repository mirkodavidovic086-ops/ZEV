-- =============================================================================
--  Demo podaci za lokalni razvoj
-- =============================================================================
--  Pokreće se automatski kroz `supabase db reset`.
--  NIKAD se ne primjenjuje na produkciju.
--
--  Korisnici se kreiraju direktno u `auth.users` da bi se izbjeglo slanje
--  stvarnih OTP kodova. Prijava u lokalnom razvoju ide preko test brojeva
--  definisanih u `config.toml` ([auth.sms.test_otp]).
-- =============================================================================

-- --- Korisnici ---------------------------------------------------------------

insert into auth.users (id, email, phone, raw_user_meta_data)
values
  ('11111111-1111-1111-1111-111111111111', 'amir@primjer.ba',  '38761000001',
   '{"ime":"Amir","prezime":"Hadžić"}'),
  ('22222222-2222-2222-2222-222222222222', 'lejla@primjer.ba', '38761000002',
   '{"ime":"Lejla","prezime":"Begić"}'),
  ('33333333-3333-3333-3333-333333333333', 'marko@primjer.ba', '38761000003',
   '{"ime":"Marko","prezime":"Ilić"}'),
  ('44444444-4444-4444-4444-444444444444', 'sanja@primjer.ba', '38761000004',
   '{"ime":"Sanja","prezime":"Kovač"}')
on conflict (id) do nothing;

-- --- Zgrada ------------------------------------------------------------------

insert into public.zgrade (
  id, naziv, kod, ulica, broj, grad, opstina, postanski_broj,
  naziv_primaoca, iban, banka, valuta,
  godina_izgradnje, broj_spratova, ima_lift,
  fiksna_naknada, naknada_po_m2, dan_dospijeca,
  podrazumijevani_nacin_glasanja, podrazumijevani_kvorum
) values (
  'aaaaaaaa-0000-0000-0000-000000000001',
  'ZEV Titova 15', 'ZEV-1001',
  'Maršala Tita', '15', 'Sarajevo', 'Centar', '71000',
  'ZEV Titova 15', 'BA391290079401028494', 'Raiffeisen Bank', 'BAM',
  1978, 5, true,
  5.00, 0.35, 15,
  'po_povrsini', 50.00
) on conflict (id) do nothing;

-- --- Stanovi -----------------------------------------------------------------

insert into public.stanovi (id, zgrada_id, oznaka, sprat, kvadratura, suvlasnicki_udio, tip)
values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '1',  1, 62.50, 62.50, 'stan'),
  ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', '2',  1, 44.00, 44.00, 'stan'),
  ('cccccccc-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000001', '3',  2, 78.20, 78.20, 'stan'),
  ('cccccccc-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000001', '4',  2, 44.00, 44.00, 'stan'),
  ('cccccccc-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000001', 'PP-1', 0, 95.00, 95.00, 'poslovni_prostor')
on conflict (id) do nothing;

-- --- Članstva ----------------------------------------------------------------
-- Amir je predsjednik, Lejla i Marko su vlasnici, Sanja je podstanar.

insert into public.clanstva (korisnik_id, zgrada_id, stan_id, uloga_id, tip, glasacko_pravo)
values
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001',
   'cccccccc-0000-0000-0000-000000000001', 10, 'vlasnik', true),
  ('22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0000-0000-0000-000000000001',
   'cccccccc-0000-0000-0000-000000000002', 50, 'vlasnik', true),
  ('33333333-3333-3333-3333-333333333333', 'aaaaaaaa-0000-0000-0000-000000000001',
   'cccccccc-0000-0000-0000-000000000003', 25, 'vlasnik', true),
  ('44444444-4444-4444-4444-444444444444', 'aaaaaaaa-0000-0000-0000-000000000001',
   'cccccccc-0000-0000-0000-000000000004', 60, 'podstanar', false)
on conflict do nothing;

-- --- Obavještenja ------------------------------------------------------------

insert into public.obavjestenja (zgrada_id, autor_id, tip, naslov, sadrzaj, zakaceno, objavljeno_at)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'hitno', 'Nestanak vode u srijedu',
   'Zbog radova na glavnoj instalaciji, voda neće raditi u srijedu od 9 do 14 sati. '
   || 'Molimo da na vrijeme obezbijedite zalihe.',
   true, now() - interval '1 day'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'obavjestenje', 'Zapisnik sa skupštine je objavljen',
   'Zapisnik sa skupštine održane prošlog mjeseca možete pogledati u sekciji '
   || 'Zgrada → Dokumenti.',
   false, now() - interval '5 days');

-- --- Kvarovi -----------------------------------------------------------------

insert into public.kvarovi (zgrada_id, prijavio_id, naslov, opis, kategorija, prioritet, status, lokacija)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222',
   'Ne radi lift', 'Lift stoji između 2. i 3. sprata i ne reaguje na pozive.',
   'lift', 'hitno', 'u_toku', '2.–3. sprat'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333',
   'Curi slavina u podrumu', 'Slavina kod zajedničkog vodomjera kaplje neprekidno.',
   'vodoinstalacije', 'srednji', 'prijavljen', 'Podrum');

-- --- Glasanje ----------------------------------------------------------------

insert into public.glasanja (
  id, zgrada_id, kreirao_id, naslov, opis, obrazlozenje,
  status, nacin, potrebna_vecina, kvorum_procenat,
  pocetak_at, kraj_at
) values (
  'eeeeeeee-0000-0000-0000-000000000001',
  'aaaaaaaa-0000-0000-0000-000000000001',
  '11111111-1111-1111-1111-111111111111',
  'Zamjena krovnog pokrivača',
  'Prijedlog za zamjenu dotrajalog krovnog pokrivača na cijeloj zgradi.',
  'Prikupljene su tri ponude (18.400 KM, 21.900 KM i 24.300 KM). '
  || 'Uprava predlaže najpovoljniju. Radovi bi trajali oko tri sedmice.',
  'aktivno', 'po_povrsini', 'dvije_trecine', 50.00,
  now() - interval '2 days', now() + interval '5 days'
) on conflict (id) do nothing;

-- --- Troškovi ZEV-a (transparentnost) ---------------------------------------

insert into public.troskovi_zev (zgrada_id, kreirao_id, smjer, kategorija, opis, iznos, datum, dobavljac)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'rashod', 'lift', 'Redovni servis lifta — juli', 180.00, current_date - 20, 'Lift servis d.o.o.'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'rashod', 'ciscenje', 'Čišćenje zajedničkih prostorija — juli', 240.00, current_date - 18, 'Čistoća d.o.o.'),
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'rashod', 'struja', 'Struja zajedničkih prostorija — juli', 96.40, current_date - 15, 'Elektroprivreda');

-- --- Kontakti ----------------------------------------------------------------

insert into public.kontakti (zgrada_id, naziv, kategorija, telefon, hitni, redoslijed)
values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Hitna pomoć',      'hitne_sluzbe', '124', true, 1),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Vatrogasci',       'hitne_sluzbe', '123', true, 2),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Policija',         'hitne_sluzbe', '122', true, 3),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Servis lifta',     'lift',   '033 123 456', false, 4),
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Vodoinstalater',   'majstor', '061 234 567', false, 5);

-- --- Obračun za tekući mjesec ------------------------------------------------
-- Poziv bez prijavljenog korisnika (auth.uid() je NULL) prolazi kao
-- service_role — vidi `fn_obracunaj_mjesec`.

select public.fn_obracunaj_mjesec('aaaaaaaa-0000-0000-0000-000000000001');
