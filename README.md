# 🏢 MojZEV

**Samostalno vođenje Zajednice etažnih vlasnika — bez agencije, bez skrivenih troškova.**

MojZEV je SaaS aplikacija koja stanarima daje alat da sami vode svoju zgradu:
transparentne finansije, digitalnu skupštinu sa asinhronim glasanjem, prijavu
kvarova i oglasnu tablu — sve iz telefona.

---

## 📑 Sadržaj

- [Problem](#-problem)
- [Moduli](#-moduli)
- [Tehnološki stack](#-tehnološki-stack)
- [Struktura projekta](#-struktura-projekta)
- [Model podataka](#-model-podataka)
- [Sigurnosni model](#-sigurnosni-model)
- [Pokretanje](#-pokretanje)
- [Testiranje](#-testiranje)
- [Status i roadmap](#-status-i-roadmap)

---

## 🎯 Problem

| Problem | Posljedica | Rješenje u MojZEV-u |
|---|---|---|
| **Netransparentnost** | Stanari ne znaju gdje ide novac sa računa ZEV-a | Svaki član vidi kompletnu knjigu prihoda i rashoda |
| **Visoke provizije agencija** | 10–20% naknade odlazi posredniku | Uprava sama obračunava i izdaje uplatnice sa QR kodom |
| **Slaba izlaznost na skupštine** | Nema kvoruma → nema odluka → zgrada propada | Asinhrono glasanje otvoreno danima, iz telefona |

---

## 📱 Moduli

Aplikacija ima **pet modula** u donjoj navigaciji:

### 1. 🏠 Početna — oglasna tabla i hitna obavještenja
Hronološki prikaz objava uprave. Hitna obavještenja se zakače na vrh i šalju
push notifikaciju odmah. Komentari ispod objava.

> Tabele: `obavjestenja`, `komentari`

### 2. 💳 Finansije — dug, uplatnice, račun ZEV-a
Dva pogleda:
- **Moje stanje** — saldo, historija zaduženja i uplata, uplatnica sa **QR kodom**
  za skeniranje u mobilnoj banci (poziv na broj po modelu 97).
- **Račun zgrade** — kompletni prihodi i rashodi zajednice. Vidljivo **svima**,
  jer je to glavna vrijednost naspram agencijskog modela.

> Tabele: `transakcije_uplatnice`, `troskovi_zev`
> Pogledi: `pogled_stanje_stana`, `pogled_stanje_zgrade`

### 3. 🗳️ Glasanje — digitalna skupština
Asinhrono glasanje sa podrškom za:
- **Težinu glasa**: po stanu, po površini/suvlasničkom udjelu, ili po glavi
- **Tipove većine**: prosta, 2/3, 3/4, jednoglasno, većina svih
- **Kvorum** sa automatskom provjerom
- **Tajno glasanje** (identitet skriven i od uprave)
- **Izmjenu glasa** do isteka roka (opciono)

Po zatvaranju se rezultat automatski prebroji i objavi na oglasnoj tabli.

> Tabele: `glasanja`, `glasanje_opcije`, `glasovi`
> Funkcije: `fn_rezultat_glasanja()`, `fn_zatvori_glasanje()`

### 4. 🛠️ Kvarovi — ticketing sa slikama
Prijava kvara sa fotografijama, kategorijom i prioritetom. Statusi od
`prijavljen` do `rijesen`. Stanari mogu potvrditi tuđu prijavu ("i mene muči
isto") umjesto da otvaraju duplikat. Trošak popravke se veže na knjigu ZEV-a.

> Tabele: `kvarovi`, `kvar_potvrde`, `prilozi`

### 5. 🏢 Zgrada & Profil — imenik, kontakti, uloge
Podaci o zgradi, imenik stanara (uz kontrolu vidljivosti), hitni kontakti,
dokumenti (zapisnici, ugovori), upravljanje članstvima i ulogama.

> Tabele: `zgrade`, `stanovi`, `clanstva`, `uloge`, `kontakti`, `dokumenti`, `pozivnice`

---

## 🏗️ Tehnološki stack

| Sloj | Izbor | Zašto |
|---|---|---|
| **Klijent** | Flutter 3.x (Dart 3) | Jedan kod za iOS + Android + Web. [ADR-0001](docs/adr/0001-flutter-vs-react-native.md) |
| **State** | Riverpod | Testabilno, bez `BuildContext` zavisnosti |
| **Rute** | go_router | Deep linking + auth guard |
| **Backend** | Supabase (PostgreSQL 16) | Auth + Realtime + Storage + RLS u jednom |
| **Auth** | SMS/Viber OTP, Email magic link | Bez lozinki — starija populacija ih gubi |
| **Serverska logika** | Edge Functions (Deno) | Samo ono što ne može u bazu |
| **QR uplatnice** | EPC069-12 / IPS QR | Konfigurabilno po zgradi |

---

## 📁 Struktura projekta

```
mojzev/
├── CLAUDE.md                   # Pravila razvoja — pročitaj prvo
├── README.md                   # Ovaj fajl
├── schema.sql                  # Referentni snapshot kompletne baze
├── .env.example                # Konfiguracija za Supabase CLI / Edge Functions
├── env.example.json            # Konfiguracija za Flutter aplikaciju
│
├── docs/
│   ├── arhitektura.md          # Pregled sistema, tokovi podataka
│   ├── baza-podataka.md        # Detaljan opis tabela i odluka
│   ├── rls-politike.md         # Matrica pristupa po ulogama
│   └── adr/                    # Architecture Decision Records
│
├── supabase/
│   ├── config.toml
│   ├── migrations/             # Verzionirane migracije (izvor istine)
│   ├── functions/              # Edge Functions (Deno)
│   │   ├── _shared/
│   │   ├── generisi-uplatnicu/ # PDF + QR uplatnica
│   │   ├── obracun-zaduzenja/  # Mjesečni cron obračun
│   │   ├── posalji-otp/        # Viber/SMS OTP
│   │   └── zatvori-glasanje/   # Cron: zatvaranje isteklih glasanja
│   ├── seed.sql                # Demo podaci za lokalni razvoj
│   └── tests/
│       ├── 00_supabase_stub.sql
│       └── 01_smoke_test.sql   # 42 tvrdnje: obračun, glasanje, tajnost, RLS
│
└── app/                        # Flutter aplikacija
    ├── pubspec.yaml
    ├── lib/
    │   ├── main.dart
    │   ├── app.dart
    │   ├── core/               # Infrastruktura (tema, rute, Supabase, greške)
    │   │   ├── config/
    │   │   ├── errors/
    │   │   ├── router/
    │   │   ├── supabase/
    │   │   ├── theme/
    │   │   ├── utils/
    │   │   └── widgets/
    │   ├── features/           # Feature-first organizacija
    │   │   ├── auth/           #   data/ domain/ presentation/
    │   │   ├── pocetna/
    │   │   ├── finansije/
    │   │   ├── glasanje/
    │   │   ├── kvarovi/
    │   │   ├── zgrada/
    │   │   └── profil/
    │   ├── shared/             # Modeli i servisi zajednički za više modula
    │   └── l10n/               # Prevodi (bs, hr, sr, en)
    ├── assets/
    ├── test/
    └── integration_test/
```

Unutar svakog `features/<modul>/`:

```
data/          Supabase pozivi, DTO mapiranje, implementacije repozitorija
domain/        Modeli i apstraktni repozitoriji — BEZ Supabase importa
presentation/  Ekrani, widgeti, Riverpod kontroleri
```

---

## 🗄️ Model podataka

21 tabela, 4 pogleda, 30 funkcija. Puna dokumentacija: [`docs/baza-podataka.md`](docs/baza-podataka.md).

### Osnovne tabele

| Tabela | Uloga |
|---|---|
| `uloge` | Šifarnik uloga sa hijerarhijom (`nivo`: 0 = sistem admin … 60 = podstanar) |
| `korisnici` | Profil, 1:1 sa `auth.users`, popunjava se triggerom pri registraciji |
| `zgrade` | **Tenant.** ZEV sa adresom, bankovnim podacima i pravilima obračuna |
| `stanovi` | Etažni dijelovi: stan, poslovni prostor, garaža… + suvlasnički udio |
| `clanstva` | **Srce modela pristupa.** korisnik ↔ zgrada ↔ (stan) + uloga |
| `glasanja` | Prijedlog odluke: način glasanja, potrebna većina, kvorum, rok |
| `glasanje_opcije` | Opcije kod višestrukog izbora |
| `glasovi` | Pojedinačni glas + **snapshot težine** |
| `kvarovi` | Ticketi sa kategorijom, prioritetom, statusom, troškom |
| `transakcije_uplatnice` | **Append-only knjiga** zaduženja i uplata po prostoru |

### Prateće tabele

`obavjestenja`, `komentari`, `troskovi_zev`, `dokumenti`, `prilozi`, `kontakti`,
`pozivnice`, `kvar_potvrde`, `push_tokeni`, `dnevnik_obavjestavanja`, `audit_log`

### Ključne odluke u modelu

**Tenant je zgrada.** Skoro svaka tabela nosi `zgrada_id`; na njemu počiva
izolacija podataka.

**Kompozitni FK-ovi garantuju konzistentnost tenanta.** Nemoguće je vezati
članstvo u zgradi A za stan iz zgrade B:
```sql
foreign key (stan_id, zgrada_id) references public.stanovi(id, zgrada_id)
```

**Jedan glas po prostoru**, ne po korisniku — `unique (glasanje_id, stan_id)`.

**Težina glasa je snapshot.** Kasnija promjena kvadrature ne mijenja stare
rezultate retroaktivno.

**Knjiga je append-only.** Ispravke idu isključivo `storno` stavkom; triger
`trg_append_only_knjizenje` blokira izmjenu iznosa, tipa i prostora.

### Ključne funkcije

| Funkcija | Šta radi |
|---|---|
| `fn_obracunaj_mjesec(zgrada, period)` | Idempotentan mjesečni obračun + generisanje uplatnica |
| `fn_generisi_qr(...)` | QR payload po EPC069-12 ili IPS standardu |
| `fn_poziv_na_broj(...)` / `fn_provjeri_poziv_na_broj(...)` | Model 97 sa kontrolnim brojem |
| `fn_rezultat_glasanja(glasanje)` | Prebrojavanje sa kvorumom i tipom većine |
| `fn_zatvori_glasanje(glasanje)` | Zatvara, snima snapshot, objavljuje odluku |
| `fn_saldo_stana(stan)` | Saldo: pozitivno = dug |
| `fn_iskoristi_pozivnicu(kod)` | Onboarding stanara preko koda |

---

## 🔐 Sigurnosni model

**Row Level Security je uključen na svim 21 tabeli.** Detaljna matrica:
[`docs/rls-politike.md`](docs/rls-politike.md).

### Uloge

| Nivo | Kod | Prava |
|---|---|---|
| 0 | `sistem_admin` | Platforma (MojZEV tim) |
| 10 | `predsjednik` | Puna prava nad zgradom |
| 20 | `clan_uo` | Obavještenja, glasanja, kvarovi, članovi |
| 25 | `blagajnik` | Finansije |
| 30 | `upravnik` | Angažovani profesionalni upravnik |
| 50 | `vlasnik` | Glasa, prijavljuje kvarove, vidi **svoje** finansije |
| 60 | `podstanar` | Bez glasačkog prava |

"Uprava" = nivo ≤ 30, provjerava se kroz `je_uprava(zgrada_id)`.

### Osnovna pravila

| Podatak | Ko vidi |
|---|---|
| Obavještenja, kvarovi, imenik, kontakti | Svi članovi zgrade |
| **Troškovi ZEV-a** | **Svi članovi** — transparentnost je poenta proizvoda |
| Zaduženja i uplate | Vlasnik **svog** prostora + uprava |
| Glasanje u statusu `nacrt` | Samo uprava |
| Pojedinačni glasovi kod `tajno = true` | **Niko** — ni uprava; samo agregat |

### Zaštita od eskalacije privilegija

Stanar može ažurirati svoj red u `clanstva` (npr. vidljivost u imeniku), ali
triger `fn_zastiti_clanstvo()` vraća `uloga_id`, `glasacko_pravo`, `zgrada_id`
i `stan_id` na stare vrijednosti ako korisnik nije u upravi.

> Ovo je namjerno riješeno trigerom, a ne RLS politikom: politika koja bi u
> `WITH CHECK` čitala staru vrijednost iz iste tabele izaziva
> `infinite recursion detected in policy`.

### Storage

Bucketi: `kvarovi`, `dokumenti` (privatni), `avatari`, `logotipi` (javni).
Konvencija putanje — **prvi segment je uvijek `zgrada_id`**, na njemu počiva izolacija:

```
kvarovi/<zgrada_id>/<kvar_id>/<uuid>.jpg
```

---

## 🚀 Pokretanje

Dva puta. Ako samo želiš **vidjeti** aplikaciju, uzmi A — ne traži nikakvu
instalaciju na tvom računaru.

### A. Hostovana Web verzija (bez instalacije)

`.github/workflows/deploy-web.yml` gradi Flutter Web i objavljuje ga besplatno
na GitHub Pages pri svakom pushu na `main` ili `claude/**`:

```
https://<vlasnik>.github.io/ZEV/
```

Jednokratno podešavanje — **mora ga uraditi vlasnik repozitorija kroz GitHub
interfejs**, ne može se postići iz koda:

1. `Settings` → `Pages` → `Build and deployment` → Source: **GitHub Actions**
2. `Settings` → `Secrets and variables` → `Actions` → dodaj dva secreta:
   `SUPABASE_URL` i `SUPABASE_ANON_KEY` (iz Supabase → Project Settings → API,
   ključ `anon public`)

Dok korak 2 nije podešen, build prolazi i stranica se otvori, ali ostaje
**prazna (bijela)**. `main()` zove `SupabaseServis.inicijalizuj()` →
`Okruzenje.provjeri()` **prije** `runApp()`, i nema `try/catch`, pa
`StateError: Nedostaje SUPABASE_URL` pukne prije nego se išta nacrta — poruka
ide samo u konzolu browsera (F12), ne na ekran. Prazna stranica ovdje znači
„nedostaju ključevi", ne „deploy je pukao". Lokalni
`supabase start` sluša na `127.0.0.1` i **nije** vidljiv hostovanoj stranici; za
ovaj put koristi Supabase u cloudu.

Šemu na cloud projekat možeš primijeniti bez ikakvog alata: Supabase →
`SQL Editor` → zalijepi `schema.sql` → `Run`. (`schema.sql` sam kreira
ekstenzije `pgcrypto`, `citext` i `pg_trgm`.) Za demo podatke zalijepi i
`supabase/seed.sql`.

> ⚠️ **Prva prijava na cloudu te ostavi u praznoj aplikaciji.** Test OTP brojevi
> rade samo lokalno, pa se na cloudu prijavljuješ magic linkom na email —
> a to kreira **novog** korisnika sa novim UUID-om, koji nema zapis u
> `clanstva`. RLS tada ispravno ne pokazuje ništa, a aplikacija trenutno
> **nema ekran za unos pozivnice** (postoji samo tekst „Zatražite pozivnicu od
> uprave"), pa nema načina da sam uđeš u zgradu.
>
> Dok se taj ekran ne doda, nakon prve prijave pokreni u `SQL Editor`-u:
>
> ```sql
> insert into public.clanstva (korisnik_id, zgrada_id, stan_id, uloga_id)
> select u.id,
>        'aaaaaaaa-0000-0000-0000-000000000001',
>        'cccccccc-0000-0000-0000-000000000001',
>        10                                     -- 10 = predsjednik
>   from auth.users u
>  where u.email = 'tvoj@email.ba';             -- email kojim si se prijavio
> ```

### B. Lokalno, na svom računaru

#### Preduslovi

```bash
flutter --version     # >= 3.24
supabase --version    # >= 1.200
```

#### 1. Backend

```bash
supabase start                 # Postgres + Auth + Storage + Studio lokalno
supabase db reset              # primijeni migracije + seed
```

Studio: http://localhost:54323

#### 2. Konfiguracija

Dva odvojena fajla — ne miješaj ih:

| Fajl | Čita ga | Format |
|---|---|---|
| `.env` | Supabase CLI i Edge Functions | `KLJUC=vrijednost` |
| `.env.json` | **Flutter aplikacija** | JSON |

```bash
cp .env.example .env            # backend / CLI
cp env.example.json .env.json   # aplikacija
# popuni oba iz izlaza `supabase status`
```

> ⚠️ Flutter **ne čita** `.env` — projekat namjerno nema `flutter_dotenv`.
> Konfiguracija ide kroz `String.fromEnvironment`, dakle kroz
> `--dart-define-from-file`. Zato uz `.env` postoji i `.env.json`.

> ⚠️ `service_role` ključ nikad ne ide ni u `.env.json` ni u `.env` aplikacije —
> samo u Edge Functions i CI secrets. Vidi CLAUDE.md, sekcija 4.5.

#### 3. Aplikacija

`app/web/`, `app/android/` i `app/ios/` se **ne čuvaju u repozitoriju** (vidi
`.gitignore`) — generišu se svježi za tačnu verziju tvog SDK-a:

```bash
cd app
flutter create --platforms=web,android --project-name mojzev .
flutter pub get

flutter run -d chrome  --dart-define-from-file=../.env.json
flutter run -d android --dart-define-from-file=../.env.json
```

`flutter create` nad postojećim projektom **ne prepisuje** `pubspec.yaml` ni
`lib/`. Bez `--dart-define-from-file` aplikacija puca na startu sa
`StateError: Nedostaje SUPABASE_URL...` — to je namjerno, vidi
`Okruzenje.provjeri()`.

#### 4. Prijava u testu (bez stvarnog SMS-a)

`supabase db reset` primijeni i `supabase/seed.sql`, koji kreira demo zgradu,
stanove i četiri korisnika **sa članstvima** — pa odmah imaš šta gledati.

Prijava ide preko test brojeva iz `supabase/config.toml`
(`[auth.sms.test_otp]`) — nikakav SMS se ne šalje:

| Broj telefona | OTP kod | Uloga u demo zgradi |
|---|---|---|
| `38761000001` | `123456` | **Predsjednik ZEV-a** — Amir (vidi sve, može mijenjati) |
| `38761000002` | `123456` | **Etažni vlasnik** — Lejla (vidi samo svoj stan) |

Prijavi se oba puta da vidiš razliku Predsjednik vs Etažni vlasnik — to je
najkorisniji test, jer pokazuje RLS na djelu: isti ekran Finansije pokazuje
cijelu knjigu zgrade predsjedniku, a samo vlastita zaduženja vlasniku.

> Test OTP radi **samo** na lokalnom Supabase-u. Vidi napomenu u sekciji A za
> hostovanu verziju.

#### 5. Edge Functions

```bash
supabase functions serve
supabase functions deploy zatvori-glasanje
```

---

## 🧪 Testiranje

### Baza

Smoke test pokriva 42 tvrdnje: mjesečni obračun, idempotentnost, QR i poziv na
broj, append-only zaštitu, težinsko glasanje sa 2/3 većinom, zatvaranje
glasanja, **tajnost glasačkog listića**, **RLS izolaciju između dvije zgrade**
i zaštitu od eskalacije privilegija.

```bash
supabase db reset
psql "$DATABASE_URL" -f supabase/tests/01_smoke_test.sql
```

Na golom PostgreSQL-u (bez Supabase-a) prvo učitaj stub:

```bash
createdb zevtest
psql zevtest -f supabase/tests/00_supabase_stub.sql
psql zevtest -f schema.sql
psql zevtest -f supabase/tests/01_smoke_test.sql
```

Skripta puca sa greškom (exit code 3) i imenuje tvrdnju koja je pala, pa se
može koristiti direktno u CI-ju.

### Aplikacija

```bash
cd app
flutter analyze
flutter test
flutter test integration_test
```

---

## 📌 Status i roadmap

Trenutno stanje: **arhitektura i baza su kompletne i testirane; Flutter sloj je
skelet.**

| | Stavka | Status |
|---|---|---|
| ✅ | Shema baze (21 tabela, 4 pogleda, 30 funkcija) | Gotovo, testirano |
| ✅ | RLS politike (46) i sigurnosni model | Gotovo, testirano |
| ✅ | Obračun, uplatnice, QR, poziv na broj | Gotovo, testirano |
| ✅ | Logika glasanja i prebrojavanja | Gotovo, testirano |
| ✅ | Flutter skelet: navigacija, tema, rute, Supabase klijent | Gotovo |
| 🔨 | Ekrani modula (Početna, Finansije, Glasanje, Kvarovi, Zgrada) | Skelet |
| 🔨 | Edge Functions | Skelet + TODO |
| ⬜ | Viber/SMS OTP integracija sa provajderom | Nije započeto |
| ⬜ | PDF uplatnica | Nije započeto |
| ⬜ | Uvoz izvoda banke i automatsko uparivanje uplata | Nije započeto |
| ⬜ | Push notifikacije (FCM) | Nije započeto |
| ⬜ | SaaS naplata pretplate | Nije započeto |

### Otvorena pitanja za proizvod

1. **QR standard** — `fn_generisi_qr()` podržava EPC069-12 i IPS QR, i
   konfigurabilan je po zgradi (`zgrade.qr_standard`). Tačan format **mora se
   potvrditi sa bankom** prije produkcije.
2. **Pravni okvir** — pravila kvoruma i većine su parametrizovana po glasanju
   jer se zakonodavstvo razlikuje po entitetu/državi. Podrazumijevane
   vrijednosti treba uskladiti sa važećim zakonom o održavanju zgrada.
3. **Punomoć** — model podržava `tip_clanstva = 'punomocnik'`, ali tok
   dodjele/opoziva punomoći nije definisan.

---

## 📄 Dokumentacija

- [`CLAUDE.md`](CLAUDE.md) — pravila razvoja, sigurnosna pravila, DoD
- [`docs/arhitektura.md`](docs/arhitektura.md) — pregled sistema i tokovi
- [`docs/baza-podataka.md`](docs/baza-podataka.md) — detaljan opis modela
- [`docs/rls-politike.md`](docs/rls-politike.md) — matrica pristupa
- [`docs/adr/`](docs/adr/) — zapisi arhitektonskih odluka
