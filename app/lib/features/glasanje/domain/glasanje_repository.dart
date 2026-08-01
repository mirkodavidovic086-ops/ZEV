import '../../../shared/models/enumi.dart';
import '../../../shared/models/modeli.dart';

/// Apstraktni ugovor za modul Glasanje.
///
/// Ovaj fajl NE SMIJE importovati `supabase_flutter` — vidi CLAUDE.md,
/// sekcija 6. Implementacija je u `data/glasanje_repository_supabase.dart`.
abstract interface class GlasanjeRepository {
  /// Lista glasanja zgrade, najnovija prvo.
  Future<List<Glasanje>> ucitajGlasanja(String zgradaId);

  Future<Glasanje> ucitajGlasanje(String glasanjeId);

  /// Predaje glas za dati prostor.
  ///
  /// Baza (`fn_validiraj_glas`) provjerava pravo glasa, rok i računa težinu.
  /// Klijent te provjere NE duplira kao zaštitu — samo kao UX.
  Future<void> glasaj({
    required String glasanjeId,
    required String stanId,
    required OpcijaGlasa opcija,
    String? obrazlozenje,
  });

  /// Mijenja već predani glas. Uspijeva samo ako glasanje to dozvoljava.
  Future<void> promijeniGlas({
    required String glasanjeId,
    required String stanId,
    required OpcijaGlasa opcija,
  });

  /// Uživo praćenje rezultata (Supabase Realtime).
  Stream<List<Glasanje>> pratiGlasanja(String zgradaId);
}
