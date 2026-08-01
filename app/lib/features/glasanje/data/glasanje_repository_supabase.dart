import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/greske.dart';
import '../../../core/supabase/supabase_servis.dart';
import '../../../shared/models/enumi.dart';
import '../../../shared/models/modeli.dart';
import '../domain/glasanje_repository.dart';

class GlasanjeRepositorySupabase implements GlasanjeRepository {
  const GlasanjeRepositorySupabase(this._db);

  final SupabaseClient _db;

  /// Čita iz pogleda `pogled_glasanja` — on već nosi `ja_glasao` i
  /// `trenutni_rezultat`, pa nema N+1 upita po stavci.
  @override
  Future<List<Glasanje>> ucitajGlasanja(String zgradaId) async {
    return mapirajGresku(() async {
      final red = await _db
          .from('pogled_glasanja')
          .select()
          .eq('zgrada_id', zgradaId)
          .order('kraj_at', ascending: false);

      return red.map(Glasanje.izMape).toList();
    });
  }

  @override
  Future<Glasanje> ucitajGlasanje(String glasanjeId) async {
    return mapirajGresku(() async {
      final red = await _db
          .from('pogled_glasanja')
          .select()
          .eq('id', glasanjeId)
          .single();

      return Glasanje.izMape(red);
    });
  }

  @override
  Future<void> glasaj({
    required String glasanjeId,
    required String stanId,
    required OpcijaGlasa opcija,
    String? obrazlozenje,
  }) async {
    return mapirajGresku(() async {
      // `korisnik_id` i `tezina` postavlja triger u bazi — ne šaljemo ih.
      await _db.from('glasovi').insert({
        'glasanje_id': glasanjeId,
        'stan_id': stanId,
        'opcija': opcija.kod,
        if (obrazlozenje != null && obrazlozenje.isNotEmpty)
          'obrazlozenje': obrazlozenje,
      });
    });
  }

  @override
  Future<void> promijeniGlas({
    required String glasanjeId,
    required String stanId,
    required OpcijaGlasa opcija,
  }) async {
    return mapirajGresku(() async {
      await _db
          .from('glasovi')
          .update({'opcija': opcija.kod})
          .eq('glasanje_id', glasanjeId)
          .eq('stan_id', stanId);
    });
  }

  @override
  Stream<List<Glasanje>> pratiGlasanja(String zgradaId) {
    return _db
        .from('glasanja')
        .stream(primaryKey: ['id'])
        .eq('zgrada_id', zgradaId)
        .order('kraj_at')
        .map((red) => red.map(Glasanje.izMape).toList());
  }
}

final glasanjeRepositoryProvider = Provider<GlasanjeRepository>((ref) {
  return GlasanjeRepositorySupabase(ref.watch(supabaseProvider));
});
