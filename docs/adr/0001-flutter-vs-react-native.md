# ADR-0001: Flutter umjesto React Native

- **Status:** prihvaćeno
- **Datum:** 2026-08-01
- **Odlučuje:** tim MojZEV

## Kontekst

Specifikacija traži mobilnu **i** web podršku, uz stack naveden kao
"Flutter / React Native". Trebalo je izabrati jedno.

Ograničenja projekta:

1. **Tri platforme iz jednog koda** — iOS, Android i Web. Web nije opciono:
   dio uprave zgrade radi sa računara, a stanari otvaraju dijeljene linkove.
2. **Mali tim.** Nema kapaciteta za dvije odvojene kodne baze niti za
   održavanje zasebnog web klijenta.
3. **Starija ciljna populacija.** Veliki dodirni elementi, čitljiv tekst,
   predvidljivo ponašanje na starijim Android uređajima.
4. **Grafički bogati ekrani** — grafikoni finansija, trake rezultata glasanja,
   QR kod uplatnice.

## Razmatrane opcije

### A) Flutter

**Za**
- Jedan kod za iOS, Android i Web, sa istim renderom na svim platformama.
  Nema "radi na Androidu, razliva se na iOS-u".
- `supabase_flutter` je zvanično podržan i pokriva Auth, Realtime i Storage.
- Kontrola nad iscrtavanjem olakšava pristupačnost (veće mete, veći font)
  bez borbe sa platformskim komponentama.
- Dart je statički tipiziran; uz `strict-casts` hvata greške mapiranja podataka
  u vrijeme kompajliranja — bitno kad se model preslikava iz baze.

**Protiv**
- Veći početni `bundle` na webu (~1,5–2 MB nakon kompresije). Za aplikaciju
  koja se koristi redovno, a ne jednokratno, prihvatljivo.
- SEO praktično ne postoji. Nebitno — cijela aplikacija je iza prijave.
- Manji bazen developera u regionu nego za React.

### B) React Native + React Native Web

**Za**
- Veći bazen developera; JS/TS znanje je rasprostranjenije.
- Lakše dijeljenje tipova sa Supabase Edge Functions (isti jezik).
- Manji web bundle.

**Protiv**
- `react-native-web` je **sloj prevođenja**, ne prva klasa. Dio biblioteka
  (posebno za kameru i fajlove — a treba nam za slike kvarova) nema web
  ekvivalent ili se ponaša drugačije.
- U praksi se često završi sa odvojenim web klijentom → dvije kodne baze,
  što je upravo ono što ne možemo održavati.
- Više varijacija u izgledu među platformama, što povećava trošak testiranja.

## Odluka

**Flutter.**

Presudila je treća tačka konteksta: React Native Web bi vjerovatno vodio ka
odvojenom web klijentu, a to je za ovaj tim skuplje od svake mane Fluttera.
Ujednačen render preko sve tri platforme direktno smanjuje trošak testiranja i
podrške — što je bitnije od veličine bundle-a za aplikaciju koja se koristi
svakodnevno i iza prijave.

## Posljedice

**Pozitivne**
- Jedna kodna baza, jedan build proces, jedan skup testova.
- Ista logika prikaza duga i rezultata glasanja svuda — nema razilaženja
  u izračunu prikaza po platformama.

**Negativne**
- Zapošljavanje traži Dart iskustvo ili spremnost na učenje.
- Prvi učitavanje weba je sporije; ublažava se `--web-renderer canvaskit`
  i keširanjem.

**Neutralne**
- Edge Functions ostaju u TypeScript-u (Deno), pa tim ipak dodiruje dva jezika.
  Prihvatljivo — serverskog koda je malo i namjerno tanak.

## Napomena o granici

Odluka se tiče **klijenta**. Poslovna logika je u bazi (RLS, trigeri, SQL
funkcije), pa bi zamjena klijentskog framework-a bila skupa, ali ne bi ugrozila
podatke ni pravila. To je i razlog zašto `domain/` sloj ne smije importovati
`supabase_flutter` — vidi CLAUDE.md, sekcija 6.
