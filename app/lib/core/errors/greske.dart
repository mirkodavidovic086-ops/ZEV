import 'package:supabase_flutter/supabase_flutter.dart';

/// Greška koju je bezbjedno pokazati korisniku.
class AppGreska implements Exception {
  const AppGreska(this.poruka, {this.kod, this.uzrok});

  final String poruka;
  final String? kod;
  final Object? uzrok;

  @override
  String toString() => 'AppGreska($kod): $poruka';
}

/// Prevodi tehničke greške Postgresa u poruke razumljive stanaru.
///
/// SQL funkcije namjerno bacaju standardne SQLSTATE kodove
/// (`insufficient_privilege`, `unique_violation`, …) da bi se ovdje mogle
/// prepoznati bez parsiranja teksta.
Future<T> mapirajGresku<T>(Future<T> Function() akcija) async {
  try {
    return await akcija();
  } on PostgrestException catch (e) {
    throw AppGreska(_prevedi(e), kod: e.code, uzrok: e);
  } on AuthException catch (e) {
    throw AppGreska(e.message, kod: 'auth', uzrok: e);
  } on StorageException catch (e) {
    throw AppGreska('Greška pri radu sa fajlom: ${e.message}',
        kod: e.statusCode, uzrok: e,);
  }
}

String _prevedi(PostgrestException e) {
  // Poruke koje SQL funkcije eksplicitno postavljaju već su na lokalnom jeziku
  // i namijenjene korisniku — proslijedi ih kakve jesu.
  const rucnePoruke = [
    'Nemate glasačko pravo',
    'Glasanje nije aktivno',
    'Glasanje je izvan',
    'Izmjena glasa nije dozvoljena',
    'Knjižena stavka se ne smije mijenjati',
    'Pozivnica',
    'Nemate ovlaštenje',
    'Odaberite ZA',
    'Ovo glasanje zahtijeva',
  ];
  if (rucnePoruke.any(e.message.startsWith)) return e.message;

  return switch (e.code) {
    '23505' => 'Taj zapis već postoji.',
    '23503' => 'Povezani zapis ne postoji ili je obrisan.',
    '23514' => 'Unesene vrijednosti nisu ispravne.',
    '42501' => 'Nemate ovlaštenje za ovu radnju.',
    'PGRST116' => 'Traženi zapis nije pronađen.',
    // RLS je sakrio red — korisniku to izgleda kao "nema pristupa".
    'PGRST301' => 'Nemate pristup ovom podatku.',
    _ => 'Došlo je do greške. Pokušajte ponovo.',
  };
}
