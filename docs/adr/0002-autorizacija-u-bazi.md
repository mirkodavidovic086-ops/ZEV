# ADR-0002: Autorizacija u bazi (RLS), bez aplikacijskog servera

- **Status:** prihvaćeno
- **Datum:** 2026-08-01

## Kontekst

Aplikacija drži dvije vrste podataka gdje greška u autorizaciji ima stvarnu
cijenu:

1. **Finansijske** — ako komšija vidi tuđi dug, to je povreda privatnosti koja
   se u maloj zajednici odmah osjeti.
2. **Izborne** — ako neko glasa u tuđe ime ili promijeni rezultat, cijeli
   proizvod gubi svrhu.

Trebalo je odlučiti gdje živi provjera "ko šta smije".

## Razmatrane opcije

### A) Aplikacijski server između klijenta i baze

Klasična troslojna arhitektura. Klijent zove REST/GraphQL API, server provjeri
ovlaštenja i razgovara sa bazom preko privilegovane konekcije.

**Za**
- Poznat obrazac, lako se zapošljava za njega.
- Logika u jeziku koji tim već zna.

**Protiv**
- Baza ostaje **otvorena** — svaka putanja koja zaobiđe server (migracija,
  skripta, buduća integracija, greška u ruti) vidi sve.
- Autorizacija se lako **duplira i raziđe**: provjera u kontroleru, pa opet u
  servisu, pa nešto treće u pozadinskom zadatku.
- Realtime bi tražio poseban mehanizam propagacije ovlaštenja.

### B) RLS u bazi, bez aplikacijskog servera

Klijent razgovara direktno sa PostgREST-om koristeći `anon` ključ i JWT.
Autorizacija je u RLS politikama.

**Za**
- **Nema puta do podataka koji zaobilazi provjeru.** Politika važi za
  PostgREST, Realtime, `psql`, migraciju — sve.
- Jedno mjesto istine za pravila pristupa.
- Realtime nasljeđuje RLS bez dodatnog rada.
- Manje pokretnih dijelova za održavanje.

**Protiv**
- Poslovna logika u PL/pgSQL-u — manje poznato, teže za debagovanje.
- RLS politike imaju svoje zamke (rekurzija, performanse).
- Testiranje traži pravu bazu, ne mockove.

## Odluka

**RLS u bazi.** Serverski sloj (Edge Functions) postoji samo za ono što u bazu
ne može: cron raspored, pozivi vanjskih HTTP servisa, buduće generisanje PDF-a.

Presudio je prvi argument: kod podataka ovog tipa, garancija da provjera ne
može biti zaobiđena vrijedi više od udobnosti pisanja logike u poznatom jeziku.

## Posljedice

### Obavezna pravila koja iz ovoga slijede

1. **Svaka tabela ima RLS.** Tabela bez politike je nepotpuna izmjena.
2. **`service_role` ključ nikad ne ide u klijent.** Živi samo u Edge Functions
   i CI secrets.
3. **RLS helperi su `SECURITY DEFINER` sa fiksnim `search_path`.** Bez toga
   politika nad `clanstva` koja čita `clanstva` daje
   `infinite recursion detected in policy`.
4. **Nikad politika koja u `USING`/`WITH CHECK` čita istu tabelu.** Umjesto
   toga helper funkcija ili triger.
5. **Svaka izmjena politike traži test izolacije** u
   `supabase/tests/01_smoke_test.sql`.

### Performanse

RLS politike se izvršavaju za svaki red. Ublaženo time što helperi vraćaju
`setof uuid` (`moje_zgrade()`, `moji_stanovi()`) i koriste se kroz `IN`, pa se
izvrše jednom po upitu, a ne po redu.

Ako se pojavi usko grlo, prvo mjesto za gledanje je `EXPLAIN ANALYZE` nad
upitom sa uključenim RLS-om — ne uklanjanje politike.

### Testiranje

Smoke test (`01_smoke_test.sql`) postavlja `auth.uid()` kroz session varijablu
i provjerava izolaciju iz perspektive četiri različita korisnika. Ovo je jedini
način da se dokaže da politike rade — mockovi ovdje ne pomažu.
