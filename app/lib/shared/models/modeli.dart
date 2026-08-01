import 'enumi.dart';

/// Domenski modeli. Preslikavaju tabele iz `schema.sql`.
///
/// Namjerno su pisani ručno (bez `freezed`/`json_serializable`) da bi skelet
/// radio bez `build_runner` koraka. Kad projekt naraste, prebaci ih na
/// `freezed` — mapiranje ostaje isto.
library;

// ignore_for_file: avoid_dynamic_calls

double? _dbl(Object? v) => v == null ? null : (v as num).toDouble();
DateTime? _dt(Object? v) => v == null ? null : DateTime.parse(v as String);

class Zgrada {
  const Zgrada({
    required this.id,
    required this.naziv,
    required this.kod,
    required this.ulica,
    required this.broj,
    required this.grad,
    this.valuta = 'BAM',
    this.iban,
    this.fiksnaNaknada = 0,
    this.naknadaPoM2 = 0,
    this.danDospijeca = 15,
    this.logoUrl,
  });

  final String id;
  final String naziv;
  final String kod;
  final String ulica;
  final String broj;
  final String grad;
  final String valuta;
  final String? iban;
  final double fiksnaNaknada;
  final double naknadaPoM2;
  final int danDospijeca;
  final String? logoUrl;

  String get punaAdresa => '$ulica $broj, $grad';

  factory Zgrada.izMape(Map<String, dynamic> m) => Zgrada(
        id: m['id'] as String,
        naziv: m['naziv'] as String,
        kod: m['kod'] as String,
        ulica: m['ulica'] as String,
        broj: m['broj'] as String,
        grad: m['grad'] as String,
        valuta: (m['valuta'] as String?) ?? 'BAM',
        iban: m['iban'] as String?,
        fiksnaNaknada: _dbl(m['fiksna_naknada']) ?? 0,
        naknadaPoM2: _dbl(m['naknada_po_m2']) ?? 0,
        danDospijeca: (m['dan_dospijeca'] as int?) ?? 15,
        logoUrl: m['logo_url'] as String?,
      );
}

class Stan {
  const Stan({
    required this.id,
    required this.zgradaId,
    required this.oznaka,
    required this.tip,
    this.ulaz,
    this.sprat,
    this.kvadratura,
    this.suvlasnickiUdio,
  });

  final String id;
  final String zgradaId;
  final String oznaka;
  final TipProstora tip;
  final String? ulaz;
  final int? sprat;
  final double? kvadratura;
  final double? suvlasnickiUdio;

  String get prikaz =>
      ulaz == null ? 'Stan $oznaka' : 'Ulaz $ulaz, stan $oznaka';

  factory Stan.izMape(Map<String, dynamic> m) => Stan(
        id: m['id'] as String,
        zgradaId: m['zgrada_id'] as String,
        oznaka: m['oznaka'] as String,
        tip: TipProstora.izKoda(m['tip'] as String? ?? 'stan'),
        ulaz: m['ulaz'] as String?,
        sprat: m['sprat'] as int?,
        kvadratura: _dbl(m['kvadratura']),
        suvlasnickiUdio: _dbl(m['suvlasnicki_udio']),
      );
}

class Korisnik {
  const Korisnik({
    required this.id,
    this.ime,
    this.prezime,
    this.email,
    this.telefon,
    this.avatarUrl,
  });

  final String id;
  final String? ime;
  final String? prezime;
  final String? email;
  final String? telefon;
  final String? avatarUrl;

  String get punoIme {
    final s = '${ime ?? ''} ${prezime ?? ''}'.trim();
    return s.isEmpty ? (email ?? telefon ?? 'Korisnik') : s;
  }

  String get inicijali {
    final d = punoIme.split(' ').where((e) => e.isNotEmpty).toList();
    if (d.isEmpty) return '?';
    if (d.length == 1) return d.first.substring(0, 1).toUpperCase();
    return (d.first[0] + d.last[0]).toUpperCase();
  }

  factory Korisnik.izMape(Map<String, dynamic> m) => Korisnik(
        id: m['id'] as String,
        ime: m['ime'] as String?,
        prezime: m['prezime'] as String?,
        email: m['email'] as String?,
        telefon: m['telefon'] as String?,
        avatarUrl: m['avatar_url'] as String?,
      );
}

class Clanstvo {
  const Clanstvo({
    required this.id,
    required this.korisnikId,
    required this.zgradaId,
    required this.uloga,
    required this.glasackoPravo,
    this.stanId,
  });

  final String id;
  final String korisnikId;
  final String zgradaId;
  final Uloga uloga;
  final bool glasackoPravo;
  final String? stanId;

  factory Clanstvo.izMape(Map<String, dynamic> m) => Clanstvo(
        id: m['id'] as String,
        korisnikId: m['korisnik_id'] as String,
        zgradaId: m['zgrada_id'] as String,
        uloga: Uloga.izKoda(
          (m['uloge'] as Map<String, dynamic>?)?['kod'] as String? ?? 'vlasnik',
        ),
        glasackoPravo: (m['glasacko_pravo'] as bool?) ?? false,
        stanId: m['stan_id'] as String?,
      );
}

class Obavjestenje {
  const Obavjestenje({
    required this.id,
    required this.zgradaId,
    required this.tip,
    required this.naslov,
    required this.sadrzaj,
    required this.zakaceno,
    this.objavljenoAt,
    this.autor,
  });

  final String id;
  final String zgradaId;
  final String tip;
  final String naslov;
  final String sadrzaj;
  final bool zakaceno;
  final DateTime? objavljenoAt;
  final Korisnik? autor;

  bool get jeHitno => tip == 'hitno';

  factory Obavjestenje.izMape(Map<String, dynamic> m) => Obavjestenje(
        id: m['id'] as String,
        zgradaId: m['zgrada_id'] as String,
        tip: m['tip'] as String,
        naslov: m['naslov'] as String,
        sadrzaj: m['sadrzaj'] as String,
        zakaceno: (m['zakaceno'] as bool?) ?? false,
        objavljenoAt: _dt(m['objavljeno_at']),
        autor: m['korisnici'] == null
            ? null
            : Korisnik.izMape(m['korisnici'] as Map<String, dynamic>),
      );
}

class Glasanje {
  const Glasanje({
    required this.id,
    required this.zgradaId,
    required this.naslov,
    required this.opis,
    required this.status,
    required this.nacin,
    required this.potrebnaVecina,
    required this.kvorumProcenat,
    required this.pocetakAt,
    required this.krajAt,
    required this.tajno,
    required this.jeVisestruko,
    this.usvojeno,
    this.rezultat,
    this.jaGlasao = false,
  });

  final String id;
  final String zgradaId;
  final String naslov;
  final String opis;
  final StatusGlasanja status;
  final NacinGlasanja nacin;
  final TipVecine potrebnaVecina;
  final double kvorumProcenat;
  final DateTime pocetakAt;
  final DateTime krajAt;
  final bool tajno;
  final bool jeVisestruko;
  final bool? usvojeno;
  final RezultatGlasanja? rezultat;
  final bool jaGlasao;

  bool get jeOtvoreno =>
      status == StatusGlasanja.aktivno && DateTime.now().isBefore(krajAt);

  Duration get preostalo => krajAt.difference(DateTime.now());

  factory Glasanje.izMape(Map<String, dynamic> m) {
    final r = m['trenutni_rezultat'] ?? m['rezultat'];
    return Glasanje(
      id: m['id'] as String,
      zgradaId: m['zgrada_id'] as String,
      naslov: m['naslov'] as String,
      opis: m['opis'] as String,
      status: StatusGlasanja.izKoda(m['status'] as String),
      nacin: NacinGlasanja.izKoda(m['nacin'] as String),
      potrebnaVecina: TipVecine.izKoda(m['potrebna_vecina'] as String),
      kvorumProcenat: _dbl(m['kvorum_procenat']) ?? 50,
      pocetakAt: DateTime.parse(m['pocetak_at'] as String),
      krajAt: DateTime.parse(m['kraj_at'] as String),
      tajno: (m['tajno'] as bool?) ?? false,
      jeVisestruko: (m['je_visestruko'] as bool?) ?? false,
      usvojeno: m['usvojeno'] as bool?,
      rezultat: r == null
          ? null
          : RezultatGlasanja.izMape(r as Map<String, dynamic>),
      jaGlasao: (m['ja_glasao'] as bool?) ?? false,
    );
  }
}

/// Snapshot iz `fn_rezultat_glasanja()`. Sva prebrojavanja dolaze iz baze —
/// klijent ih nikad ne računa sam (CLAUDE.md, sekcija 4.2).
class RezultatGlasanja {
  const RezultatGlasanja({
    required this.ukupnoTijelo,
    required this.izaslo,
    required this.odzivProcenat,
    required this.kvorumIspunjen,
    this.za = 0,
    this.protiv = 0,
    this.uzdrzan = 0,
    this.zaProcenat = 0,
    this.usvojeno,
  });

  final double ukupnoTijelo;
  final double izaslo;
  final double odzivProcenat;
  final bool kvorumIspunjen;
  final double za;
  final double protiv;
  final double uzdrzan;
  final double zaProcenat;
  final bool? usvojeno;

  factory RezultatGlasanja.izMape(Map<String, dynamic> m) => RezultatGlasanja(
        ukupnoTijelo: _dbl(m['ukupno_tijelo']) ?? 0,
        izaslo: _dbl(m['izaslo']) ?? 0,
        odzivProcenat: _dbl(m['odziv_procenat']) ?? 0,
        kvorumIspunjen: (m['kvorum_ispunjen'] as bool?) ?? false,
        za: _dbl(m['za']) ?? 0,
        protiv: _dbl(m['protiv']) ?? 0,
        uzdrzan: _dbl(m['uzdrzan']) ?? 0,
        zaProcenat: _dbl(m['za_procenat']) ?? 0,
        usvojeno: m['usvojeno'] as bool?,
      );
}

class Kvar {
  const Kvar({
    required this.id,
    required this.zgradaId,
    required this.broj,
    required this.naslov,
    required this.opis,
    required this.kategorija,
    required this.prioritet,
    required this.status,
    required this.kreiranoAt,
    this.lokacija,
    this.brojPotvrda = 0,
    this.prijavio,
    this.slike = const [],
  });

  final String id;
  final String zgradaId;
  final int broj;
  final String naslov;
  final String opis;
  final KategorijaKvara kategorija;
  final PrioritetKvara prioritet;
  final StatusKvara status;
  final DateTime kreiranoAt;
  final String? lokacija;
  final int brojPotvrda;
  final Korisnik? prijavio;
  final List<String> slike;

  factory Kvar.izMape(Map<String, dynamic> m) => Kvar(
        id: m['id'] as String,
        zgradaId: m['zgrada_id'] as String,
        broj: m['broj'] as int,
        naslov: m['naslov'] as String,
        opis: m['opis'] as String,
        kategorija: KategorijaKvara.izKoda(m['kategorija'] as String),
        prioritet: PrioritetKvara.izKoda(m['prioritet'] as String),
        status: StatusKvara.izKoda(m['status'] as String),
        kreiranoAt: DateTime.parse(m['kreirano_at'] as String),
        lokacija: m['lokacija'] as String?,
        brojPotvrda: (m['broj_potvrda'] as int?) ?? 0,
        prijavio: m['korisnici'] == null
            ? null
            : Korisnik.izMape(m['korisnici'] as Map<String, dynamic>),
        slike: ((m['prilozi'] as List<dynamic>?) ?? [])
            .map((e) => (e as Map<String, dynamic>)['putanja'] as String)
            .toList(),
      );
}

class TransakcijaUplatnica {
  const TransakcijaUplatnica({
    required this.id,
    required this.stanId,
    required this.tip,
    required this.iznos,
    required this.valuta,
    required this.opis,
    required this.datumDokumenta,
    this.datumDospijeca,
    this.brojUplatnice,
    this.pozivNaBroj,
    this.racunPrimaoca,
    this.primalac,
    this.qrSadrzaj,
  });

  final String id;
  final String stanId;
  final TipTransakcije tip;
  final double iznos;
  final String valuta;
  final String opis;
  final DateTime datumDokumenta;
  final DateTime? datumDospijeca;
  final String? brojUplatnice;
  final String? pozivNaBroj;
  final String? racunPrimaoca;
  final String? primalac;

  /// Payload za QR kod. Generiše ga baza (`fn_generisi_qr`) — klijent ga samo
  /// iscrtava kroz `qr_flutter`.
  final String? qrSadrzaj;

  bool get jeDospjela =>
      tip.povecavaDug &&
      datumDospijeca != null &&
      DateTime.now().isAfter(datumDospijeca!);

  factory TransakcijaUplatnica.izMape(Map<String, dynamic> m) =>
      TransakcijaUplatnica(
        id: m['id'] as String,
        stanId: m['stan_id'] as String,
        tip: TipTransakcije.izKoda(m['tip'] as String),
        iznos: _dbl(m['iznos']) ?? 0,
        valuta: (m['valuta'] as String?) ?? 'BAM',
        opis: m['opis'] as String,
        datumDokumenta: DateTime.parse(m['datum_dokumenta'] as String),
        datumDospijeca: _dt(m['datum_dospijeca']),
        brojUplatnice: m['broj_uplatnice'] as String?,
        pozivNaBroj: m['poziv_na_broj'] as String?,
        racunPrimaoca: m['racun_primaoca'] as String?,
        primalac: m['primalac'] as String?,
        qrSadrzaj: m['qr_sadrzaj'] as String?,
      );
}

class StanjeStana {
  const StanjeStana({
    required this.stanId,
    required this.saldo,
    required this.ukupnoZaduzeno,
    required this.ukupnoPlaceno,
    required this.dospjeliDug,
  });

  final String stanId;
  final double saldo;
  final double ukupnoZaduzeno;
  final double ukupnoPlaceno;
  final double dospjeliDug;

  bool get uDugu => saldo > 0;

  factory StanjeStana.izMape(Map<String, dynamic> m) => StanjeStana(
        stanId: m['stan_id'] as String,
        saldo: _dbl(m['saldo']) ?? 0,
        ukupnoZaduzeno: _dbl(m['ukupno_zaduzeno']) ?? 0,
        ukupnoPlaceno: _dbl(m['ukupno_placeno']) ?? 0,
        dospjeliDug: _dbl(m['dospjeli_dug']) ?? 0,
      );
}
