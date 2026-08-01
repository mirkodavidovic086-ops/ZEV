# CLAUDE.md — Smjernice za rad na projektu MojZEV

Ovaj fajl je ugovor između tebe (AI asistenta ili novog developera) i projekta.
Pročitaj ga prije prve izmjene koda.

---

## 1. Šta je MojZEV

SaaS aplikacija koja omogućava **stanarima da sami vode svoju Zajednicu etažnih
vlasnika (ZEV)**, bez posredovanja agencije.

Tri problema koja rješavamo — svaka odluka u kodu mora služiti bar jednom:

| Problem | Kako ga kod rješava |
|---|---|
| **Netransparentnost** — stanari ne znaju gdje ide njihov novac | Svaki član vidi **kompletnu** knjigu prihoda i rashoda zgrade (`troskovi_zev`). Nema skrivenih stavki. |
| **Visoke provizije agencija** | Uprava sama radi obračun i izdaje uplatnice — bez posrednika. |
| **Slaba izlaznost na skupštine** | Asinhrono glasanje iz telefona, otvoreno 7+ dana umjesto jednog termina u podrumu. |

> **Pravilo br. 1:** ako feature smanjuje transparentnost prema stanaru, nije
> feature — nego bug. Preispitaj ga prije implementacije.

---

## 2. Tehnološki stack

| Sloj | Tehnologija | Napomena |
|---|---|---|
| Klijent | **Flutter 3.x** (Dart 3) | Jedan kod za iOS, Android i Web. Vidi `docs/adr/0001-flutter-vs-react-native.md`. |
| State management | **Riverpod** | Bez `setState` u ekranima složenijim od jednog widgeta. |
| Rutiranje | **go_router** | Deklarativne rute, deep linking, auth guard. |
| Backend | **Supabase** (PostgreSQL 15+) | Auth, Realtime, Storage, Edge Functions. |
| Auth | **OTP bez lozinke** | SMS/Viber OTP + Email magic link. |
| Serverska logika | **Edge Functions** (Deno/TypeScript) | Samo ono što ne smije/ne može u bazu. |

---

## 3. Jezik i imenovanje — OBAVEZNO

Domenski model je na **lokalnom jeziku, bez dijakritika u identifikatorima**.
Razlog: naručilac, zakon i korisnici govore o "etažnim vlasnicima", ne o
"unit owners" — prevođenje unosi grešku.

```
✅ zgrade, stanovi, clanstva, glasanja, kvarovi, transakcije_uplatnice
❌ buildings, apartments, memberships, votes, issues
```

| Šta | Konvencija | Primjer |
|---|---|---|
| Tabele, kolone, enumi | `snake_case`, lokalni jezik, **bez dijakritika** | `poziv_na_broj`, `suvlasnicki_udio` |
| SQL funkcije | prefiks `fn_`; RLS helperi bez prefiksa | `fn_saldo_stana()`, `je_uprava()` |
| SQL trigeri | prefiks `trg_` | `trg_validiraj_glas` |
| Pogledi | prefiks `pogled_` | `pogled_stanje_stana` |
| Dart klase | `PascalCase`, lokalni jezik | `Zgrada`, `Kvar`, `TransakcijaUplatnica` |
| Dart fajlovi | `snake_case.dart` | `kvarovi_repository.dart` |
| Korisnički tekst | **ijekavica** (bs), sa dijakriticima | "Obavještenja", "Kvarovi" |

Komentari i dokumentacija: lokalni jezik. Ne miješaj engleski i lokalni u istoj
rečenici.

---

## 4. Sigurnost — nepregovarljiva pravila

Ovo je aplikacija koja drži **finansijske podatke i izborne rezultate**. Greška
u autorizaciji ovdje znači da komšija vidi tvoj dug ili da neko falsifikuje
glasanje.

### 4.1 RLS je uključen na SVAKOJ tabeli

Nova tabela bez `enable row level security` + politike je **nepotpuna izmjena**.
Nema izuzetaka. Kad dodaješ tabelu, u istom commitu dodaj i politike.

### 4.2 Klijent nikad nije izvor istine

Ove stvari se **moraju** provjeravati u bazi (triger ili RLS), ne u Dart kodu:

- da li korisnik smije glasati za taj prostor → `fn_validiraj_glas()`
- težina glasa → snapshot u `glasovi.tezina`, nikad računat na klijentu
- da li je glasanje još otvoreno → `fn_validiraj_glas()`
- ko smije mijenjati ulogu → `fn_zastiti_clanstvo()`
- iznos zaduženja → `fn_obracunaj_mjesec()`

Provjere u Dart kodu služe **samo** za UX (sakrij dugme). Nikad kao zaštita.

### 4.3 RLS helperi su `SECURITY DEFINER` sa fiksnim `search_path`

```sql
create or replace function public.je_uprava(p_zgrada_id uuid)
returns boolean
language sql stable
security definer                    -- ← prekida RLS rekurziju
set search_path = public, pg_temp   -- ← obavezno, sprječava injection
as $$ ... $$;
```

Bez `security definer`, politika nad `clanstva` koja čita `clanstva` daje
`infinite recursion detected in policy`. Bez `set search_path`, funkcija je
ranjiva na podmetanje objekata.

**Nikad ne piši politiku koja u `USING`/`WITH CHECK` čita istu tabelu.**
Umjesto toga koristi helper funkciju ili triger (vidi `fn_zastiti_clanstvo`).

### 4.4 Knjiga je append-only

`transakcije_uplatnice` se **ne mijenja i ne briše**. Greška se ispravlja
`storno` stavkom koja pokazuje na original. Triger `trg_append_only_knjizenje`
to i tehnički sprječava.

Isto važi za `glasovi`: brisanje nije dozvoljeno nikome. Izmjena glasa je
dozvoljena samo ako `glasanja.dozvoli_izmjenu` i samo do isteka roka.

### 4.5 `service_role` ključ NIKAD ne ide u klijent

Flutter aplikacija koristi isključivo `anon` ključ. `service_role` živi samo u
Edge Functions i CI secrets. Ako ti treba operacija koja zaobilazi RLS —
to je Edge Function ili `SECURITY DEFINER` funkcija, ne klijentski poziv.

### 4.6 Tajno glasanje je stvarno tajno

Kad je `glasanja.tajno = true`, RLS politika `glasovi_select` ne otkriva
pojedinačne glasove **ni upravi**. Rezultat se dobija samo agregatom iz
`fn_rezultat_glasanja()`. Ne dodaji "admin može vidjeti" prečicu.

---

## 5. Model podataka — šta moraš znati prije izmjene

Puna dokumentacija: `docs/baza-podataka.md`. Ključne odluke:

**Tenant je zgrada.** Skoro svaka tabela ima `zgrada_id`. Izolacija podataka
počiva na tome. Nova tabela sa podacima zgrade **mora** imati `zgrada_id`.

**`clanstva` je srce modela pristupa.** Veza korisnik ↔ zgrada ↔ (opciono) stan
+ uloga. Korisnik može biti predsjednik u jednoj zgradi i običan stanar u
drugoj. Sve RLS politike se svode na upit nad ovom tabelom.

**Jedan glas po prostoru, ne po korisniku.** `glasovi` ima
`unique (glasanje_id, stan_id)`. Suvlasnici se dogovaraju van sistema.

**Težina glasa je snapshot.** Upisuje se u `glasovi.tezina` u trenutku glasanja.
Ako se kasnije promijeni kvadratura stana, **stari rezultati se ne mijenjaju**.
Ovo je namjerno i ne smije se "popraviti".

**Kompozitni FK-ovi čuvaju konzistentnost tenanta:**
```sql
foreign key (stan_id, zgrada_id) references public.stanovi(id, zgrada_id)
```
Ovo tehnički onemogućava da se članstvo u zgradi A veže za stan iz zgrade B.
Kad dodaješ tabelu koja referencira i zgradu i stan — koristi isti obrazac.

---

## 6. Struktura Flutter koda

Feature-first, sa slojevima unutar feature-a:

```
lib/features/<modul>/
├── data/           # Supabase pozivi, DTO mapiranje, repository implementacije
├── domain/         # Modeli i apstraktni repozitoriji (bez Supabase importa!)
└── presentation/   # Ekrani, widgeti, Riverpod kontroleri
```

Pravila:

1. **`domain/` ne smije importovati `supabase_flutter`.** Ako mora — dizajn je
   pogrešan.
2. **Ekrani ne zovu Supabase direktno.** Uvijek kroz repository.
3. **Jedan feature = jedan folder u `lib/features/`.** Ne stvaraj `utils/`
   smetlište; zajedničko ide u `lib/core/` ili `lib/shared/`.
4. Svi tekstovi kroz `lib/l10n/` — nema hardkodovanih stringova u widgetima.

---

## 7. Rad sa bazom

### Migracije

Shema se mijenja **isključivo** kroz novu migraciju:

```bash
supabase migration new opis_izmjene
# uredi supabase/migrations/<timestamp>_opis_izmjene.sql
supabase db reset          # lokalna provjera od nule
```

`schema.sql` u korijenu je **referentni, čitljivi snapshot** cijele sheme —
služi za pregled i onboarding. Kad promijeniš migraciju, osvježi i njega.
Nikad ne mijenjaj već primijenjenu migraciju.

### Testiranje sheme

Postoji izvršni smoke test koji pokriva obračun, glasanje, RLS izolaciju i
zaštitu od eskalacije privilegija:

```bash
supabase db reset
psql "$DATABASE_URL" -f supabase/tests/01_smoke_test.sql
```

Na golom PostgreSQL-u (bez Supabase-a) prvo učitaj `supabase/tests/00_supabase_stub.sql`.

**Svaka izmjena RLS politike zahtijeva test u `01_smoke_test.sql`** koji dokazuje
da stanar iz zgrade A ne vidi podatke zgrade B.

---

## 8. Šta NE raditi

- ❌ Ne dodavati tabelu bez RLS politika.
- ❌ Ne pisati politiku koja čita samu tabelu koju štiti (rekurzija).
- ❌ Ne raditi `UPDATE`/`DELETE` nad `transakcije_uplatnice` — samo storno.
- ❌ Ne računati iznose ili težine glasova na klijentu.
- ❌ Ne stavljati `service_role` ključ u Flutter kod ni u `.env` koji se commituje.
- ❌ Ne prevoditi domenske pojmove na engleski.
- ❌ Ne uvoditi novi state management uz Riverpod.
- ❌ Ne brisati `audit_log` zapise.
- ❌ Ne dodavati "admin vidi sve" prečicu kod tajnog glasanja.

---

## 9. Commit i grane

```
<tip>(<modul>): <opis u imperativu>

feat(glasanje): dodaj podrsku za visestruki izbor
fix(finansije): ispravi obracun kamate za prijestupnu godinu
db(rls): ogranici uvid u uplatnice na vlastite stanove
```

Tipovi: `feat`, `fix`, `db`, `docs`, `refactor`, `test`, `chore`.
Moduli: `pocetna`, `finansije`, `glasanje`, `kvarovi`, `zgrada`, `auth`, `rls`, `core`.

Grane: `feature/<opis>`, `fix/<opis>`, `db/<opis>`.

---

## 10. Definicija završenog (Definition of Done)

Izmjena je gotova tek kad:

- [ ] Kod se kompajlira: `flutter analyze` bez upozorenja
- [ ] Testovi prolaze: `flutter test`
- [ ] Ako dira bazu: nova migracija + osvježen `schema.sql`
- [ ] Ako dira bazu: `supabase db reset` prolazi od nule
- [ ] Ako dira RLS: dodan test izolacije u `01_smoke_test.sql`
- [ ] Nema hardkodovanih stringova (sve kroz `l10n`)
- [ ] Nema `print()` — koristi `AppLogger`
- [ ] Provjereno na Android + Web (minimum)
