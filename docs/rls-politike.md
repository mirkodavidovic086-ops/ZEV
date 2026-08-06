# RLS politike — matrica pristupa

Row Level Security je uključen na **svih 21 tabela**. Ovaj dokument je
referenca "ko šta smije"; izvor istine je `schema.sql`, sekcija 8.

---

## 1. Helper funkcije

Sve su `SECURITY DEFINER` sa `set search_path = public, pg_temp`.
Vraćaju isključivo boolean ili skup UUID-ova — nikad podatke.

| Funkcija | Vraća |
|---|---|
| `je_sistem_admin()` | Da li je korisnik administrator platforme |
| `moje_zgrade()` | UUID-ovi zgrada u kojima korisnik ima aktivno članstvo |
| `je_clan(zgrada_id)` | Član bilo koje uloge |
| `je_uprava(zgrada_id)` | Uloga nivoa ≤ 30 (predsjednik, član UO, blagajnik, upravnik) |
| `je_predsjednik(zgrada_id)` | Uloga nivoa ≤ 10 |
| `moji_stanovi()` | Prostori na koje korisnik ima pravo uvida |
| `moji_glasacki_stanovi()` | Prostori za koje korisnik smije glasati |

> Sve funkcije uključuju i provjeru `vazi_do` — isteklo članstvo ne daje pristup.

---

## 2. Matrica

Legenda: **✅** puno · **👁** samo čitanje · **🔒** samo svoje · **❌** nema pristupa

| Tabela | Stanar / vlasnik | Podstanar | Uprava (≤30) | Predsjednik | Napomena |
|---|---|---|---|---|---|
| `uloge` | 👁 | 👁 | 👁 | 👁 | Šifarnik, javan za prijavljene |
| `korisnici` | 🔒 + 👁 komšije | isto | isto | isto | Vidljivi samo članovi istih zgrada |
| `zgrade` | 👁 | 👁 | ✅ izmjena | ✅ + brisanje | Svako smije osnovati novu ZEV |
| `stanovi` | 👁 | 👁 | ✅ | ✅ | |
| `clanstva` | 👁 + 🔒 izmjena | isto | ✅ | ✅ | Izmjena sebe ograničena trigerom |
| `pozivnice` | ❌ | ❌ | ✅ | ✅ | Namjerno bez SELECT-a za stanare |
| `obavjestenja` | 👁 objavljena | isto | ✅ | ✅ | Neobjavljena vidi samo uprava |
| `glasanja` | 👁 osim nacrta | isto | ✅ | ✅ | Nacrt vidi samo uprava |
| `glasanje_opcije` | 👁 | 👁 | ✅ | ✅ | Prati vidljivost glasanja |
| `glasovi` | 🔒 + javni | 🔒 | 🔒 + javni | 🔒 + javni | **Tajno glasanje: niko ne vidi tuđe** |
| `kvarovi` | 👁 + prijava | 👁 + prijava | ✅ | ✅ | Prijavitelj dopunjuje dok je `prijavljen` |
| `kvar_potvrde` | 👁 + 🔒 | isto | isto | isto | |
| `komentari` | 👁 + 🔒 | isto | ✅ + interni | ✅ | Interni komentari samo za upravu |
| `transakcije_uplatnice` | 🔒 svoj prostor | 🔒 | 👁 sve + unos | isto | **Brisanje zabranjeno svima** |
| `troskovi_zev` | 👁 **sve** | 👁 **sve** | ✅ | ✅ | Transparentnost — poenta proizvoda |
| `dokumenti` | 👁 javni | 👁 javni | ✅ | ✅ | |
| `prilozi` | 👁 + unos | isto | ✅ | ✅ | Prilozi uz finansije samo vlasniku |
| `kontakti` | 👁 | 👁 | ✅ | ✅ | |
| `push_tokeni` | 🔒 | 🔒 | 🔒 | 🔒 | Isključivo svoji |
| `dnevnik_obavjestavanja` | 🔒 | 🔒 | 👁 zgrade | isto | Upis samo iz Edge Functions |
| `audit_log` | ❌ | ❌ | 👁 | 👁 | **Brisanje zabranjeno svima** |

---

## 3. Pravila koja se ne smiju "popraviti"

### 3.1 Tajno glasanje je stvarno tajno

```sql
create policy glasovi_select on public.glasovi
  for select to authenticated
  using (
    korisnik_id = auth.uid()               -- svoj glas vidi uvijek
    or exists (
      select 1 from public.glasanja g
       where g.id = glasovi.glasanje_id
         and not g.tajno                    -- ← kod tajnog: nema izuzetka
         and public.je_clan(g.zgrada_id)
    )
  );
```

Kad je `tajno = true`, **ni uprava ni sistem admin** ne mogu pročitati
pojedinačne glasove. Rezultat se dobija isključivo agregatom kroz
`fn_rezultat_glasanja()` (SECURITY DEFINER).

Ne dodavati "admin može vidjeti" prečicu — to poništava svrhu tajnog glasanja.

Pokriveno tvrdnjama 35–39 u `supabase/tests/01_smoke_test.sql`. Tvrdnja 37
(uprava **vidi** glasove javnog glasanja) je kontrolna: bez nje bi tvrdnja 36
prolazila i kad bi uprava bila slijepa iz nekog sasvim drugog razloga.
Provjereno mutacijom — dodavanje `or je_uprava(...)` u politiku obara test.

### 3.2 Knjiga je append-only

`transakcije_uplatnice` nema `DELETE` politiku — brisanje je nemoguće za sve.
`UPDATE` je dozvoljen upravi, ali triger `trg_append_only_knjizenje` blokira
izmjenu `iznos`, `tip`, `stan_id`, `zgrada_id` i `period_od`.

Ispravka greške ide **isključivo** kroz `storno` stavku koja preko
`storno_od_id` pokazuje na original.

### 3.3 Glasovi se ne brišu

`glasovi` nema `DELETE` politiku. Izmjena je moguća samo ako
`glasanja.dozvoli_izmjenu = true` i samo dok je glasanje aktivno
(provjerava `trg_validiraj_glas`).

### 3.4 Zaštita od eskalacije privilegija

Politika `clanstva_update_self` dozvoljava stanaru da ažurira svoj red
(praktično: vidljivost u imeniku). Zaštita je u trigeru, ne u politici:

```sql
create function public.fn_zastiti_clanstvo() returns trigger ... as $$
begin
  if public.je_uprava(old.zgrada_id) then
    return new;                       -- uprava smije sve
  end if;
  new.uloga_id       := old.uloga_id;         -- vraćanje na staro
  new.glasacko_pravo := old.glasacko_pravo;
  new.zgrada_id      := old.zgrada_id;
  new.stan_id        := old.stan_id;
  ...
end $$;
```

**Zašto ne politikom:** `WITH CHECK` koji bi čitao staru vrijednost iz
`public.clanstva` pokreće politiku nad samom sobom →
`infinite recursion detected in policy for relation "clanstva"`.

Pokriveno tvrdnjama 33 i 34 u `supabase/tests/01_smoke_test.sql`.

### 3.5 Pozivnice se ne mogu pobrojati

`pozivnice` nema SELECT politiku za obične korisnike. Kod se iskorištava
isključivo kroz `fn_iskoristi_pozivnicu(kod)`, koja traži **tačan** kod. Bez
toga bi napadač mogao pročitati sve nevažeće kodove i ubaciti se u zgradu.

---

## 4. Storage

Konvencija putanje — **prvi segment je uvijek `zgrada_id`**:

```
kvarovi/<zgrada_id>/<kvar_id>/<uuid>.jpg
dokumenti/<zgrada_id>/<kategorija>/<uuid>.pdf
avatari/<korisnik_id>/<uuid>.jpg
```

| Bucket | Javni | Čitanje | Pisanje |
|---|---|---|---|
| `kvarovi` | ne | članovi zgrade | članovi zgrade |
| `dokumenti` | ne | članovi zgrade | uprava |
| `avatari` | da | svi | vlasnik foldera |
| `logotipi` | da | svi | uprava |

Cast prvog segmenta u `uuid` ide kroz `fn_u_uuid()`, koja vraća `NULL` umjesto
da baci grešku — neispravna putanja inače ruši cijeli upit nad `storage.objects`.

---

## 5. Obaveza pri izmjeni

**Svaka izmjena RLS politike zahtijeva test u `supabase/tests/01_smoke_test.sql`**
koji dokazuje da član zgrade A ne vidi podatke zgrade B.

Postojeći testovi izolacije: 23–32 (uvid stanara vs. uprave vs. stranca) i
33–34 (eskalacija privilegija).

```bash
psql "$DATABASE_URL" -f supabase/tests/01_smoke_test.sql
```

Skripta puca sa greškom ako ijedna tvrdnja padne.
