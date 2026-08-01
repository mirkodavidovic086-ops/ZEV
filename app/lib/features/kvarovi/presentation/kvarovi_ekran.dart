import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/tema.dart';
import '../../../shared/models/enumi.dart';

/// Modul 4 — Ticketing sistem za kvarove.
///
/// TODO: povezati sa `kvarovi` tabelom kroz `KvaroviRepository`
/// (isti obrazac kao `features/glasanje/`).
class KvaroviEkran extends ConsumerWidget {
  const KvaroviEkran({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kvarovi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/kvarovi/novi'),
        icon: const Icon(Icons.add),
        label: const Text('Prijavi kvar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _KvarKartica(
            broj: 1,
            naslov: 'Ne radi lift',
            kategorija: KategorijaKvara.lift,
            prioritet: PrioritetKvara.hitno,
            status: StatusKvara.uToku,
            brojPotvrda: 4,
            onTap: () => context.go('/kvarovi/demo-1'),
          ),
          const SizedBox(height: 12),
          _KvarKartica(
            broj: 2,
            naslov: 'Curi slavina u podrumu',
            kategorija: KategorijaKvara.vodoinstalacije,
            prioritet: PrioritetKvara.srednji,
            status: StatusKvara.prijavljen,
            brojPotvrda: 0,
            onTap: () => context.go('/kvarovi/demo-2'),
          ),
        ],
      ),
    );
  }
}

class _KvarKartica extends StatelessWidget {
  const _KvarKartica({
    required this.broj,
    required this.naslov,
    required this.kategorija,
    required this.prioritet,
    required this.status,
    required this.brojPotvrda,
    required this.onTap,
  });

  final int broj;
  final String naslov;
  final KategorijaKvara kategorija;
  final PrioritetKvara prioritet;
  final StatusKvara status;
  final int brojPotvrda;
  final VoidCallback onTap;

  Color get _bojaPrioriteta => switch (prioritet) {
        PrioritetKvara.hitno => Tema.greska,
        PrioritetKvara.visok => Tema.upozorenje,
        PrioritetKvara.srednji => Tema.akcent,
        PrioritetKvara.nizak => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  color: _bojaPrioriteta,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#$broj · ${kategorija.naziv}',
                        style: tema.textTheme.bodySmall
                            ?.copyWith(color: tema.colorScheme.outline)),
                    const SizedBox(height: 4),
                    Text(naslov,
                        style: tema.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(status.naziv),
                          visualDensity: VisualDensity.compact,
                        ),
                        if (prioritet == PrioritetKvara.hitno)
                          Chip(
                            label: const Text('HITNO'),
                            backgroundColor:
                                Tema.greska.withValues(alpha: 0.15),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (brojPotvrda > 0)
                          Chip(
                            avatar: const Icon(Icons.group, size: 16),
                            label: Text('$brojPotvrda potvrda'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
