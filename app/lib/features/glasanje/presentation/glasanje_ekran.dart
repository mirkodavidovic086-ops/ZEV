import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/modeli.dart';
import '../../../shared/providers/kontekst_provider.dart';
import '../data/glasanje_repository_supabase.dart';
import 'widgets/glasanje_kartica.dart';

/// Lista glasanja aktivne zgrade.
final glasanjaProvider = FutureProvider<List<Glasanje>>((ref) async {
  final zgradaId = ref.watch(aktivnaZgradaIdProvider);
  if (zgradaId == null) return const [];
  return ref.watch(glasanjeRepositoryProvider).ucitajGlasanja(zgradaId);
});

/// Modul 3 — Digitalna skupština (asinhrono glasanje).
class GlasanjeEkran extends ConsumerWidget {
  const GlasanjeEkran({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glasanja = ref.watch(glasanjaProvider);
    final jeUprava = ref.watch(jeUpravaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Glasanje')),
      floatingActionButton: jeUprava
          ? FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('Novo glasanje'),
            )
          : null,
      body: glasanja.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Greška pri učitavanju: $e'),
          ),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const _Prazno();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(glasanjaProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: lista.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => GlasanjeKartica(
                glasanje: lista[i],
                onTap: () => context.go('/glasanje/${lista[i].id}'),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Prazno extends StatelessWidget {
  const _Prazno();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.how_to_vote_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline,),
            const SizedBox(height: 16),
            Text('Trenutno nema glasanja',
                style: Theme.of(context).textTheme.titleMedium,),
            const SizedBox(height: 8),
            Text(
              'Kad uprava pokrene glasanje, pojaviće se ovdje i dobićete '
              'obavještenje.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
