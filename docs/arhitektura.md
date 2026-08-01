# Arhitektura sistema

## 1. Pregled

MojZEV je **klijent–baza** arhitektura sa tankim serverskim slojem. Flutter
aplikacija razgovara direktno sa Supabase-om (PostgREST + Realtime + Storage),
a autorizaciju obavljaju **RLS politike u bazi** — ne aplikacijski server.

```
┌─────────────────────────────────────────────────────────┐
│                  Flutter (iOS / Android / Web)          │
│  presentation → Riverpod kontroleri                     │
│  domain       → apstraktni repozitoriji                 │
│  data         → Supabase klijent (anon ključ)           │
└───────────────┬─────────────────────────────────────────┘
                │ HTTPS + JWT (auth.uid())
┌───────────────▼─────────────────────────────────────────┐
│                       Supabase                          │
│  ┌───────────┬────────────┬───────────┬───────────────┐ │
│  │ PostgREST │  Realtime  │  Storage  │ Edge Functions│ │
│  └─────┬─────┴──────┬─────┴─────┬─────┴───────┬───────┘ │
│        │            │           │             │         │
│  ┌─────▼────────────▼───────────▼─────────────▼───────┐ │
│  │            PostgreSQL 15+                          │ │
│  │  • RLS politike        ← stvarna autorizacija      │ │
│  │  • Trigeri             ← validacija i integritet   │ │
│  │  • SQL funkcije        ← poslovna logika           │ │
│  └────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

### Zašto bez aplikacijskog servera

Klasična troslojna arhitektura bi ovdje dodala sloj koji ne radi ništa osim što
proslijeđuje upite i duplira autorizaciju. Umjesto toga:

- **Autorizacija je u bazi.** Nemoguće ju je zaobići jer nema puta do podataka
  koji je ne prolazi.
- **Manje mjesta gdje se logika može razići.** Iznos zaduženja se računa na
  jednom mjestu, ne u API-ju *i* u bazi *i* na klijentu.
- **Realtime dolazi besplatno** i poštuje iste RLS politike.

Cijena: poslovna logika je u PL/pgSQL-u, što je manje poznato timovima
naviklim na aplikacijski kod. Zato su sve funkcije dokumentovane i pokrivene
smoke testom.

---

## 2. Sloj po sloj

### 2.1 Flutter klijent

Feature-first organizacija sa tri sloja unutar svakog modula:

| Sloj | Odgovornost | Smije zvati |
|---|---|---|
| `presentation/` | Ekrani, widgeti, Riverpod kontroleri | `domain/` |
| `domain/` | Modeli, apstraktni repozitoriji | ništa spolja |
| `data/` | Supabase pozivi, mapiranje | `domain/`, Supabase SDK |

**Ključno pravilo:** `domain/` ne importuje `supabase_flutter`. To čini modele i
poslovna pravila testabilnim bez mreže i omogućava zamjenu backenda bez
prepisivanja ekrana.

### 2.2 Baza podataka

Tri mehanizma, sa jasnom podjelom posla:

| Mehanizam | Kad se koristi | Primjer |
|---|---|---|
| **RLS politika** | "Da li ovaj korisnik smije vidjeti/mijenjati ovaj red?" | `tu_select` — stanar vidi samo svoje uplatnice |
| **Triger** | "Da li je ova izmjena konzistentna?" + popunjavanje izvedenih polja | `trg_validiraj_glas` — provjera prava glasa i snimanje težine |
| **Funkcija** | Izračuni i operacije nad više redova | `fn_obracunaj_mjesec` — mjesečni obračun |

### 2.3 Edge Functions

Samo za ono što **ne može** u bazu:

| Funkcija | Zašto nije u bazi |
|---|---|
| `zatvori-glasanje` | Potreban raspoređivač (cron); logika prebrojavanja jeste u bazi |
| `obracun-zaduzenja` | Isto — okida `fn_obracunaj_mjesec()` po zgradama |
| `posalji-otp` | Poziv vanjskog HTTP provajdera (Viber/SMS) |
| `generisi-uplatnicu` | Buduće generisanje PDF-a |

---

## 3. Ključni tokovi

### 3.1 Prijava (bez lozinke)

```
Stanar unese telefon
   → Supabase Auth pošalje OTP (Auth Hook → posalji-otp → Viber/SMS)
   → Stanar unese 6-cifreni kod
   → verifyOTP() vrati JWT
   → trigger on_auth_user_created kreira red u `korisnici`
   → go_router redirect pusti korisnika u aplikaciju
```

Korisnik bez članstva vidi **prazan** ekran — RLS ne otkriva nijednu zgradu.
Pristup se dobija isključivo kroz `fn_iskoristi_pozivnicu(kod)`.

### 3.2 Mjesečni obračun

```
Cron (1. u mjesecu)
   → Edge Function `obracun-zaduzenja`
   → za svaku aktivnu zgradu: fn_obracunaj_mjesec(zgrada, period)
        ├─ preskoči prostore koji već imaju zaduženje za taj period (idempotentno)
        ├─ iznos = fiksna_naknada + naknada_po_m2 × kvadratura
        ├─ poziv na broj po modelu 97 (fn_poziv_na_broj)
        └─ QR payload po standardu zgrade (fn_generisi_qr)
   → INSERT u `transakcije_uplatnice`
   → trigger trg_popuni_uplatnicu dopuni primaoca, račun, šifru plaćanja
```

Idempotentnost je namjerna: ako cron padne pa se ponovi, ništa se ne duplira.

### 3.3 Glasanje

```
Uprava kreira glasanje (status 'nacrt' — vidi ga samo uprava)
   → objavi → 'zakazano' → (pocetak_at) → 'aktivno'

Stanar glasa
   → INSERT u `glasovi`
   → trigger trg_validiraj_glas:
        ├─ glasanje je 'aktivno' i u roku?
        ├─ korisnik ima glasačko pravo za taj prostor?
        ├─ korisnik_id := auth.uid()   (ne može glasati u tuđe ime)
        └─ tezina := fn_tezina_glasa(stan, nacin)   ← SNAPSHOT
   → constraint unique(glasanje_id, stan_id): jedan glas po prostoru

Istek roka
   → Cron → fn_obradi_istekla_glasanja()
        → fn_zatvori_glasanje(id)
             ├─ fn_rezultat_glasanja() — kvorum + tip većine
             ├─ upiše snapshot u glasanja.rezultat
             └─ objavi odluku na oglasnoj tabli
```

**Zašto je težina snapshot:** ako se kvadratura stana kasnije ispravi, rezultat
prošlogodišnje skupštine se ne smije retroaktivno promijeniti. Odluka je
donesena pod tada važećim udjelima.

### 3.4 Prijava kvara

```
Stanar popuni formu + fotografije
   → upload u Storage: kvarovi/<zgrada_id>/<kvar_id>/<uuid>.jpg
        (prvi segment putanje = zgrada_id → osnov Storage RLS politike)
   → INSERT u `kvarovi`
   → trigger trg_broj_kvara dodijeli redni broj unutar zgrade (#1, #2, …)
   → Realtime obavijesti ostale članove
```

---

## 4. Multi-tenancy

**Tenant je zgrada.** Skoro svaka tabela nosi `zgrada_id`, a izolaciju
sprovodi RLS kroz helper `je_clan(zgrada_id)`.

Dodatni sloj zaštite su **kompozitni strani ključevi**:

```sql
foreign key (stan_id, zgrada_id) references public.stanovi(id, zgrada_id)
```

Ovo čini fizički nemogućim da se članstvo u zgradi A veže za stan iz zgrade B —
čak i ako aplikacijski kod ima grešku, a RLS politika propust.

Isti obrazac koriste `pozivnice`, `kvarovi` i `transakcije_uplatnice`.

---

## 5. Sprječavanje RLS rekurzije

Naivna politika nad `clanstva`:

```sql
-- ❌ NE RADI: infinite recursion detected in policy
create policy clanstva_select on public.clanstva
  using (exists (select 1 from public.clanstva c where ...));
```

Rješenje su `SECURITY DEFINER` helperi sa fiksiranim `search_path`:

```sql
create function public.je_clan(p_zgrada_id uuid) returns boolean
language sql stable
security definer                    -- prekida ciklus: RLS se ne primjenjuje unutra
set search_path = public, pg_temp   -- sprječava podmetanje objekata
as $$ select exists (select 1 from public.clanstva ...) $$;
```

Isto vrijedi za zaštitu od eskalacije privilegija: umjesto politike koja bi u
`WITH CHECK` čitala staru vrijednost iz iste tabele (rekurzija), koristi se
**triger** `fn_zastiti_clanstvo()` koji vraća osjetljiva polja na stare
vrijednosti kad korisnik nije u upravi.

---

## 6. Realtime

Objavljene tabele: `obavjestenja`, `kvarovi`, `komentari`, `glasanja`,
`glasovi`, `kvar_potvrde`.

Realtime **poštuje RLS**, pa klijent dobija samo događaje za svoju zgradu.

Namjerno **nisu** objavljene:
- `transakcije_uplatnice` — nema potrebe za live prikazom, a smanjuje površinu
  izloženosti finansijskih podataka
- `audit_log` — interni trag

---

## 7. Šta još nije riješeno

| Otvoreno pitanje | Napomena |
|---|---|
| Tačan format QR koda | `fn_generisi_qr` podržava EPC069-12 i IPS; **mora se potvrditi sa bankom** |
| Uparivanje uplata sa izvodom banke | Kolone (`referenca_banke`, `izvod_broj`, `upareno_at`) postoje; uvoz nije implementiran |
| Tok punomoći | `tip_clanstva = 'punomocnik'` postoji u modelu, tok dodjele/opoziva nije definisan |
| Naplata SaaS pretplate | `zgrade.plan` i `pretplata_do` postoje; integracija sa procesorom nije rađena |
| Push notifikacije | `push_tokeni` tabela postoji; FCM integracija nije rađena |
