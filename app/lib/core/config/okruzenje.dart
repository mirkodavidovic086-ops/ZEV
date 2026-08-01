/// Konfiguracija okruženja.
///
/// Vrijednosti se prosljeđuju pri pokretanju, ne hardkoduju:
///
/// ```bash
/// flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// ```
///
/// VAŽNO: ovdje smije stajati isključivo `anon` ključ. `service_role` ključ
/// nikad ne ide u klijent — vidi CLAUDE.md, sekcija 4.5.
library;

class Okruzenje {
  const Okruzenje._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  static const String supabaseAnonKljuc =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// `dev` | `staging` | `prod`
  static const String naziv =
      String.fromEnvironment('OKRUZENJE', defaultValue: 'dev');

  static bool get jeProdukcija => naziv == 'prod';

  /// Provjerava se pri startu aplikacije da bi greška u konfiguraciji pukla
  /// odmah, a ne tek pri prvom mrežnom pozivu.
  static void provjeri() {
    if (supabaseUrl.isEmpty || supabaseAnonKljuc.isEmpty) {
      throw StateError(
        'Nedostaje SUPABASE_URL ili SUPABASE_ANON_KEY. '
        'Pokreni sa --dart-define ili --dart-define-from-file=.env.json',
      );
    }
  }
}
