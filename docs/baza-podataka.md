# Model podataka

Referenca uz `schema.sql`. Ovdje je **zašto**; *šta* je u samoj shemi.

21 tabela · 4 pogleda · 30 funkcija · 46 RLS politika

---

## 1. Odnosi

```
                        ┌───────────┐
                        │   uloge   │  šifarnik (nivo 0…60)
                        └─────▲─────┘
                              │
┌────────────┐         ┌──────┴──────┐         ┌────────────┐
│ korisnici  │◄────────┤  clanstva   ├────────►│   zgrade   │
│ (=auth.    │         │             │         │  = TENANT  │
│  users)    │         └──────┬──────┘         └─────┬──────┘
└────────────┘                │                      │
                              ▼                      ▼
                        ┌───────────┐          ┌──────────────┐
                        │  stanovi  │◄─────────┤  sve ostale  │
                        └─────┬─────┘          │   tabele     │
                              │                └──────────────┘
              ┌───────────────┼──────────────────┐
              ▼               ▼                  ▼
      ┌──────────────┐  ┌──────────┐   ┌──────────────────────┐
      │   glasovi    │  │ kvarovi  │   │transakcije_uplatnice │
      └──────┬───────┘  └──────────┘   └──────────────────────┘
             ▼
      ┌──────────────┐
      │   glasanja   │───► glasanje_opcije
      └──────────────┘
```

---

## 2. Ključne odluke

### 2.1 Tenant je zgrada, ne organizacija

Jedna ZEV = jedan tenant. Skoro svaka tabela nosi `zgrada_id` i RLS se svodi na
`je_clan(zgrada_id)`.

**Zašto ne "organizacija" iznad zgrade:** ZEV je pravni subjekt sam po sebi.
Uvođenje nadređenog nivoa bi služilo samo agencijama koje upravljaju sa više
zgrada — a to je model koji ovaj proizvod namjerno zaobilazi.

### 2.2 `korisnici` je 1:1 sa `auth.users`

Supabase Auth drži kredencijale; `public.korisnici` drži sve što aplikacija
prikazuje. Red se kreira trigerom `on_auth_user_created`.

**Zašto ne koristiti `auth.users` direktno:** ta schema je Supabase-ova i može
se mijenjati; osim toga, ne može se na nju vezati FK iz aplikacijskih tabela
bez sprege sa internim modelom.

### 2.3 `clanstva` je srce modela pristupa

Veza korisnik ↔ zgrada ↔ (opciono) stan + uloga.

Pokriva slučajeve koji se stvarno javljaju:
- vlasnik dva stana u istoj zgradi
- predsjednik u jednoj zgradi, običan stanar u drugoj
- angažovani upravnik bez vlasništva nad ijednim prostorom (`stan_id IS NULL`)
- podstanar sa punomoći vlasnika (`glasacko_pravo = true` uz `tip = 'punomocnik'`)

`vazi_od` / `vazi_do` omogućavaju istek mandata bez brisanja historije.

### 2.4 Kompozitni FK-ovi čuvaju konzistentnost tenanta

```sql
-- stanovi ima: unique (id, zgrada_id)
-- pa clanstva može:
foreign key (stan_id, zgrada_id) references public.stanovi(id, zgrada_id)
```

Rezultat: **fizički je nemoguće** vezati članstvo u zgradi A za stan iz zgrade B.
Ovo je zaštita ispod RLS-a — radi čak i ako politika ima propust.

Isti obrazac koriste `pozivnice`, `kvarovi`, `transakcije_uplatnice`.

Kod `kvarovi` FK koristi `on delete set null (stan_id)` — sa listom kolona, jer
bi običan `SET NULL` pokušao poništiti i `zgrada_id`, koji je `NOT NULL`.

### 2.5 Jedan glas po prostoru

```sql
constraint glasovi_jedan_po_stanu unique (glasanje_id, stan_id)
```

Ne po korisniku. Ako stan ima tri suvlasnika, oni imaju **jedan** glas i
dogovaraju se van sistema — tako nalaže i pravni okvir.

### 2.6 Težina glasa je snapshot

`glasovi.tezina` se upisuje trigerom u trenutku glasanja.

Ako se kasnije ispravi kvadratura stana, **rezultat prošlog glasanja se ne
mijenja**. Odluka je donesena pod tada važećim udjelima; retroaktivna izmjena
bi značila falsifikovanje izbornog rezultata.

Ovo nije bug i ne smije se "popraviti".

### 2.7 Knjiga je append-only

`transakcije_uplatnice` je jedinstvena knjiga: zaduženja i uplate su redovi u
istoj tabeli. Saldo je suma generisane kolone:

```sql
iznos_predznakom numeric(12,2) generated always as (
  case when tip in ('zaduzenje','kamata') then iznos else -iznos end
) stored
```

`iznos` je uvijek pozitivan; predznak nosi `tip`. Time nema nedoumice oko toga
"da li je iznos već negativan" pri unosu.

Ispravka greške ide `storno` stavkom (`storno_od_id` pokazuje na original).
Constraint garantuje da su `tip = 'storno'` i `storno_od_id IS NOT NULL`
neodvojivi.

### 2.8 `troskovi_zev` je odvojen od `transakcije_uplatnice`

Dvije različite knjige:

| | `transakcije_uplatnice` | `troskovi_zev` |
|---|---|---|
| Čije | Po prostoru (stanaru) | Zajednice kao cjeline |
| Pitanje | "Koliko ja dugujem?" | "Gdje je otišao naš novac?" |
| Vidljivost | Vlasnik + uprava | **Svi članovi** |

Razdvajanje je namjerno: stanar ne smije vidjeti dug komšije, ali **mora**
vidjeti svaki rashod zajednice. To je glavna vrijednost naspram agencijskog
modela.

### 2.9 Redni broj tiketa po zgradi

`kvarovi.broj` je čitljiv broj unutar zgrade (#1, #2, …), ne globalni. Trigger
`trg_broj_kvara` zaključava red zgrade (`SELECT … FOR UPDATE`) da bi
istovremene prijave dobile različite brojeve.

---

## 3. Pravila na nivou baze

Ono što se **mora** provjeravati u bazi, jer klijent nije izvor istine:

| Provjera | Gdje |
|---|---|
| Pravo glasa za prostor | `fn_validiraj_glas()` |
| Težina glasa | `fn_validiraj_glas()` → `fn_tezina_glasa()` |
| Da li je glasanje otvoreno | `fn_validiraj_glas()` |
| Da li je izmjena glasa dozvoljena | `fn_validiraj_glas()` |
| Ko smije mijenjati ulogu | `fn_zastiti_clanstvo()` |
| Nepromjenjivost knjiženja | `fn_zabrani_izmjenu_knjizenja()` |
| Iznos zaduženja | `fn_obracunaj_mjesec()` |
| Rezultat glasanja | `fn_rezultat_glasanja()` |

Provjere u Dart kodu služe samo za UX (sakriti dugme), nikad kao zaštita.

---

## 4. Finansije — detalji

### 4.1 Obračun

```
iznos = zgrade.fiksna_naknada + zgrade.naknada_po_m2 × stanovi.kvadratura
```

`fn_obracunaj_mjesec()` je **idempotentna**: preskače prostore koji već imaju
zaduženje za dati period. Ponovno pokretanje ne duplira ništa — zato je
bezbjedno da ga cron pokrene više puta.

Autorizacija: ako postoji prijavljen korisnik (`auth.uid()` nije NULL), mora
biti u upravi. Ako ga nema, poziv dolazi od cron-a / `service_role` ključa i
već je autorizovan na nivou infrastrukture.

### 4.2 Poziv na broj — model 97

```
baza     = <kod zgrade><YYYYMM><oznaka stana>     npr. ZEV10012026081
kontrola = 98 − (baza || "00") mod 97             npr. 82
rezultat = <kontrola><baza>                       82ZEV10012026081
```

Kontrolni broj ide **na početak** (regionalna konvencija), pa validacija
premješta prve dvije cifre na kraj:

```sql
fn_provjeri_poziv_na_broj(p) := fn_mod97(substr(p,3) || substr(p,1,2)) = 1
```

`fn_mod97()` implementira ISO 7064 MOD 97-10 sa konverzijom slova (A=10 … Z=35),
obrađujući ulaz u komadima da bi izbjegao prekoračenje `bigint`-a.

### 4.3 QR kod

`fn_generisi_qr()` podržava:

| Standard | Gdje se koristi |
|---|---|
| `EPC069_12` | SEPA EPC QR — podrazumijevani |
| `IPS_QR` | NBS IPS QR (Srbija) |
| `HUB3A` | rezervisano |
| `BEZ_QR` | isključeno |

> ⚠️ **Prije produkcije obavezno validirati payload sa bankom ZEV-a.** Format
> se razlikuje po državi i banci; zato je `zgrade.qr_standard` konfigurabilan
> po zgradi, a ne globalna konstanta.

Payload generiše **baza**, klijent ga samo iscrtava (`qr_flutter`). Time format
ostaje na jednom mjestu.

---

## 5. Glasanje — detalji

### 5.1 Način glasanja (težina)

| `nacin` | Težina jednog prostora |
|---|---|
| `po_stanu` | 1 |
| `po_povrsini` | `suvlasnicki_udio`, ili `kvadratura` ako udio nije unesen |
| `po_glavi` | 1 |

### 5.2 Tip većine

| `potrebna_vecina` | Prag | Osnovica |
|---|---|---|
| `prosta_vecina` | > 50% | izašli |
| `vecina_svih` | > 50% | **cijelo glasačko tijelo** |
| `dvije_trecine` | ≥ 66,67% | izašli |
| `tri_cetvrtine` | ≥ 75% | izašli |
| `jednoglasno` | 100% | izašli |

Prosta većina traži **strogo više** od 50%; kvalifikovane većine se dostižu
(`>=`), uz toleranciju 10⁻⁶ zbog periodičnog razlomka kod 2/3.

Kvorum se provjerava odvojeno od većine: odluka je usvojena samo ako je
**i kvorum ispunjen i prag pređen**.

### 5.3 Zašto `pogled_glasanja`

Pogled vraća `ja_glasao` i `trenutni_rezultat` uz svaki red, pa lista glasanja
ne pravi N+1 upita. Kod tajnog glasanja `trenutni_rezultat` je `NULL` dok
glasanje traje.

Svi pogledi su `security_invoker = true` (PostgreSQL 15+) — bez toga bi radili
sa ovlaštenjima vlasnika i procurili podatke drugih zgrada.

---

## 6. Konvencije

| Prefiks | Značenje |
|---|---|
| `fn_` | SQL funkcija (poslovna logika) |
| `trg_` | Triger |
| `pogled_` | Pogled |
| bez prefiksa | RLS helper (`je_clan`, `je_uprava`, `moje_zgrade`) |

Identifikatori: `snake_case`, lokalni jezik, **bez dijakritika**.
Korisnički tekst: ijekavica, sa dijakriticima.

---

## 7. Izmjena sheme

```bash
supabase migration new opis_izmjene
# uredi supabase/migrations/<timestamp>_opis_izmjene.sql
supabase db reset                    # provjera od nule
psql "$DATABASE_URL" -f supabase/tests/01_smoke_test.sql
```

Zatim osvježi `schema.sql` (referentni snapshot).

**Nikad ne mijenjaj već primijenjenu migraciju.**

Nova tabela sa podacima zgrade mora imati: `zgrada_id`, `enable row level
security`, politike, i — ako referencira i stan — kompozitni FK.
