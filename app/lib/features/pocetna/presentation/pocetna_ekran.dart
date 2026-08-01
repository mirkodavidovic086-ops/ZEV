import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tema.dart';
import '../../../shared/providers/kontekst_provider.dart';

/// Modul 1 — Oglasna tabla i hitna obavještenja.
///
/// TODO: povezati sa `obavjestenja` tabelom kroz `PocetnaRepository`
/// (isti obrazac kao `features/glasanje/`).
class PocetnaEkran extends ConsumerWidget {
  const PocetnaEkran({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zgrada = ref.watch(aktivnaZgradaProvider);
    final jeUprava = ref.watch(jeUpravaProvider);

    return Scaffold(
      appBar: AppBar(
        title: zgrada.when(
          data: (z) => Text(z?.naziv ?? 'MojZEV'),
          loading: () => const Text('MojZEV'),
          error: (_, __) => const Text('MojZEV'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: jeUprava
          ? FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Objavi'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _HitnoBanner(
            naslov: 'Nestanak vode u srijedu',
            sadrzaj: 'Zbog radova na instalacijama, voda neće raditi '
                'u srijedu od 9 do 14 sati.',
          ),
          SizedBox(height: 16),
          _Obavjestenje(
            naslov: 'Zapisnik sa skupštine je objavljen',
            sadrzaj: 'Zapisnik možete pogledati u sekciji Zgrada → Dokumenti.',
            autor: 'Uprava',
            prije: 'prije 2 dana',
          ),
        ],
      ),
    );
  }
}

class _HitnoBanner extends StatelessWidget {
  const _HitnoBanner({required this.naslov, required this.sadrzaj});

  final String naslov;
  final String sadrzaj;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Tema.upozorenje.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.priority_high, color: Tema.upozorenje),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(naslov,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(sadrzaj),
          ],
        ),
      ),
    );
  }
}

class _Obavjestenje extends StatelessWidget {
  const _Obavjestenje({
    required this.naslov,
    required this.sadrzaj,
    required this.autor,
    required this.prije,
  });

  final String naslov;
  final String sadrzaj;
  final String autor;
  final String prije;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(naslov, style: tema.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(sadrzaj),
            const SizedBox(height: 12),
            Text('$autor · $prije',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
