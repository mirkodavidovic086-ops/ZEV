import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/greske.dart';
import '../../core/supabase/supabase_servis.dart';
import '../models/enumi.dart';
import '../models/modeli.dart';

/// Aktivna zgrada i uloga prijavljenog korisnika.
///
/// Korisnik može biti član više zgrada (npr. stan + poslovni prostor u drugoj
/// zgradi), pa cijela aplikacija radi u kontekstu jedne izabrane zgrade.

/// Sva članstva prijavljenog korisnika.
final mojaClanstvaProvider = FutureProvider<List<Clanstvo>>((ref) async {
  final db = ref.watch(supabaseProvider);
  final korisnik = ref.watch(trenutniKorisnikProvider);
  if (korisnik == null) return const [];

  return mapirajGresku(() async {
    final red = await db
        .from('clanstva')
        .select('*, uloge(kod, naziv, nivo)')
        .eq('korisnik_id', korisnik.id)
        .eq('aktivno', true);

    return red.map(Clanstvo.izMape).toList();
  });
});

/// ID trenutno izabrane zgrade. Podrazumijevano prva iz liste članstava.
final aktivnaZgradaIdProvider = StateProvider<String?>((ref) {
  final clanstva = ref.watch(mojaClanstvaProvider).valueOrNull;
  return clanstva == null || clanstva.isEmpty ? null : clanstva.first.zgradaId;
});

final aktivnaZgradaProvider = FutureProvider<Zgrada?>((ref) async {
  final id = ref.watch(aktivnaZgradaIdProvider);
  if (id == null) return null;

  final db = ref.watch(supabaseProvider);
  return mapirajGresku(() async {
    final red = await db.from('zgrade').select().eq('id', id).single();
    return Zgrada.izMape(red);
  });
});

/// Uloga korisnika u aktivnoj zgradi.
///
/// Služi ISKLJUČIVO za UI (npr. sakrij dugme "Novo glasanje"). Stvarna
/// zaštita je u RLS politikama — vidi CLAUDE.md, sekcija 4.2.
final mojaUlogaProvider = Provider<Uloga?>((ref) {
  final zgradaId = ref.watch(aktivnaZgradaIdProvider);
  final clanstva = ref.watch(mojaClanstvaProvider).valueOrNull;
  if (zgradaId == null || clanstva == null) return null;

  final zaZgradu = clanstva.where((c) => c.zgradaId == zgradaId);
  if (zaZgradu.isEmpty) return null;

  // Ako korisnik ima više članstava u istoj zgradi (npr. dva stana),
  // mjerodavna je ona sa najvećim ovlaštenjima.
  return zaZgradu
      .map((c) => c.uloga)
      .reduce((a, b) => a.nivo <= b.nivo ? a : b);
});

final jeUpravaProvider = Provider<bool>((ref) {
  return ref.watch(mojaUlogaProvider)?.jeUprava ?? false;
});

/// Prostori prijavljenog korisnika u aktivnoj zgradi.
final mojiStanoviProvider = FutureProvider<List<Stan>>((ref) async {
  final zgradaId = ref.watch(aktivnaZgradaIdProvider);
  final korisnik = ref.watch(trenutniKorisnikProvider);
  if (zgradaId == null || korisnik == null) return const [];

  final db = ref.watch(supabaseProvider);
  return mapirajGresku(() async {
    final red = await db
        .from('clanstva')
        .select('stanovi(*)')
        .eq('korisnik_id', korisnik.id)
        .eq('zgrada_id', zgradaId)
        .eq('aktivno', true)
        .not('stan_id', 'is', null);

    return red
        .map((e) => e['stanovi'])
        .whereType<Map<String, dynamic>>()
        .map(Stan.izMape)
        .toList();
  });
});
