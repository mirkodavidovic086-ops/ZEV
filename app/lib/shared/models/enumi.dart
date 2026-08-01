/// Dart pandani PostgreSQL enum tipova iz `schema.sql`.
///
/// `kod` MORA odgovarati vrijednosti u bazi — to je ugovor između slojeva.
/// Kad dodaješ vrijednost u SQL enum, dodaj je i ovdje.
library;

enum TipProstora {
  stan('stan', 'Stan'),
  poslovniProstor('poslovni_prostor', 'Poslovni prostor'),
  garaza('garaza', 'Garaža'),
  garaznoMjesto('garazno_mjesto', 'Garažno mjesto'),
  ostava('ostava', 'Ostava'),
  potkrovlje('potkrovlje', 'Potkrovlje'),
  ostalo('ostalo', 'Ostalo');

  const TipProstora(this.kod, this.naziv);
  final String kod;
  final String naziv;

  static TipProstora izKoda(String k) =>
      values.firstWhere((e) => e.kod == k, orElse: () => ostalo);
}

enum StatusGlasanja {
  nacrt('nacrt', 'Nacrt'),
  zakazano('zakazano', 'Zakazano'),
  aktivno('aktivno', 'U toku'),
  zavrseno('zavrseno', 'Završeno'),
  ponisteno('ponisteno', 'Poništeno');

  const StatusGlasanja(this.kod, this.naziv);
  final String kod;
  final String naziv;

  static StatusGlasanja izKoda(String k) =>
      values.firstWhere((e) => e.kod == k, orElse: () => nacrt);
}

enum NacinGlasanja {
  poStanu('po_stanu', 'Po stanu'),
  poPovrsini('po_povrsini', 'Po površini'),
  poGlavi('po_glavi', 'Po glavi');

  const NacinGlasanja(this.kod, this.naziv);
  final String kod;
  final String naziv;

  static NacinGlasanja izKoda(String k) =>
      values.firstWhere((e) => e.kod == k, orElse: () => poStanu);
}

enum TipVecine {
  prostaVecina('prosta_vecina', 'Prosta većina (>50% izašlih)'),
  vecinaSvih('vecina_svih', 'Većina svih vlasnika'),
  dvijeTrecine('dvije_trecine', 'Dvotrećinska većina'),
  triCetvrtine('tri_cetvrtine', 'Tročetvrtinska većina'),
  jednoglasno('jednoglasno', 'Jednoglasno');

  const TipVecine(this.kod, this.naziv);
  final String kod;
  final String naziv;

  static TipVecine izKoda(String k) =>
      values.firstWhere((e) => e.kod == k, orElse: () => prostaVecina);
}

enum OpcijaGlasa {
  za('za', 'ZA'),
  protiv('protiv', 'PROTIV'),
  uzdrzan('uzdrzan', 'UZDRŽAN');

  const OpcijaGlasa(this.kod, this.naziv);
  final String kod;
  final String naziv;

  static OpcijaGlasa? izKoda(String? k) =>
      k == null ? null : values.where((e) => e.kod == k).firstOrNull;
}

enum KategorijaKvara {
  vodoinstalacije('vodoinstalacije', 'Vodoinstalacije'),
  elektroinstalacije('elektroinstalacije', 'Elektroinstalacije'),
  lift('lift', 'Lift'),
  krov('krov', 'Krov'),
  fasada('fasada', 'Fasada'),
  stepeniste('stepeniste', 'Stepenište'),
  grijanje('grijanje', 'Grijanje'),
  domofon('domofon', 'Domofon'),
  rasvjeta('rasvjeta', 'Rasvjeta'),
  ciscenje('ciscenje', 'Čišćenje'),
  dvoriste('dvoriste', 'Dvorište'),
  parking('parking', 'Parking'),
  vandalizam('vandalizam', 'Vandalizam'),
  ostalo('ostalo', 'Ostalo');

  const KategorijaKvara(this.kod, this.naziv);
  final String kod;
  final String naziv;

  static KategorijaKvara izKoda(String k) =>
      values.firstWhere((e) => e.kod == k, orElse: () => ostalo);
}

enum PrioritetKvara {
  nizak('nizak', 'Nizak'),
  srednji('srednji', 'Srednji'),
  visok('visok', 'Visok'),
  hitno('hitno', 'HITNO');

  const PrioritetKvara(this.kod, this.naziv);
  final String kod;
  final String naziv;

  static PrioritetKvara izKoda(String k) =>
      values.firstWhere((e) => e.kod == k, orElse: () => srednji);
}

enum StatusKvara {
  prijavljen('prijavljen', 'Prijavljen'),
  prihvacen('prihvacen', 'Prihvaćen'),
  cekaPonudu('ceka_ponudu', 'Čeka ponudu'),
  uToku('u_toku', 'U toku'),
  rijesen('rijesen', 'Riješen'),
  odbijen('odbijen', 'Odbijen'),
  duplikat('duplikat', 'Duplikat');

  const StatusKvara(this.kod, this.naziv);
  final String kod;
  final String naziv;

  bool get jeZatvoren => this == rijesen || this == odbijen || this == duplikat;

  static StatusKvara izKoda(String k) =>
      values.firstWhere((e) => e.kod == k, orElse: () => prijavljen);
}

enum TipTransakcije {
  zaduzenje('zaduzenje', 'Zaduženje'),
  uplata('uplata', 'Uplata'),
  kamata('kamata', 'Kamata'),
  popust('popust', 'Popust'),
  storno('storno', 'Storno');

  const TipTransakcije(this.kod, this.naziv);
  final String kod;
  final String naziv;

  /// Da li stavka povećava dug (usklađeno sa `iznos_predznakom` u bazi).
  bool get povecavaDug => this == zaduzenje || this == kamata;

  static TipTransakcije izKoda(String k) =>
      values.firstWhere((e) => e.kod == k, orElse: () => zaduzenje);
}

/// Uloge iz šifarnika `public.uloge`. `nivo` prati SQL hijerarhiju:
/// manji broj = veća ovlaštenja.
enum Uloga {
  sistemAdmin('sistem_admin', 'Sistem administrator', 0),
  predsjednik('predsjednik', 'Predsjednik ZEV-a', 10),
  clanUo('clan_uo', 'Član upravnog odbora', 20),
  blagajnik('blagajnik', 'Blagajnik', 25),
  upravnik('upravnik', 'Upravnik', 30),
  vlasnik('vlasnik', 'Etažni vlasnik', 50),
  podstanar('podstanar', 'Podstanar', 60);

  const Uloga(this.kod, this.naziv, this.nivo);
  final String kod;
  final String naziv;
  final int nivo;

  /// Isto pravilo kao `je_uprava()` u bazi. Služi SAMO za UI (sakrij dugme) —
  /// stvarna zaštita je u RLS politikama. Vidi CLAUDE.md, sekcija 4.2.
  bool get jeUprava => nivo <= 30;

  static Uloga izKoda(String k) =>
      values.firstWhere((e) => e.kod == k, orElse: () => vlasnik);
}
