import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/greske.dart';
import '../../../core/theme/tema.dart';
import '../../../core/utils/formatiranje.dart';
import '../../../shared/models/enumi.dart';
import '../../../shared/models/modeli.dart';
import '../../../shared/providers/kontekst_provider.dart';
import '../data/glasanje_repository_supabase.dart';
import 'glasanje_ekran.dart';

final glasanjeDetaljProvider =
    FutureProvider.family<Glasanje, String>((ref, id) async {
  return ref.watch(glasanjeRepositoryProvider).ucitajGlasanje(id);
});

class GlasanjeDetaljEkran extends ConsumerWidget {
  const GlasanjeDetaljEkran({required this.glasanjeId, super.key});

  final String glasanjeId;

  Future<void> _glasaj(
    BuildContext context,
    WidgetRef ref,
    OpcijaGlasa opcija,
  ) async {
    final stanovi = ref.read(mojiStanoviProvider).valueOrNull ?? const [];
    if (stanovi.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nemate prostor sa glasačkim pravom.')),
      );
      return;
    }

    // Ako korisnik ima više prostora, mora izabrati za koji glasa —
    // baza dozvoljava jedan glas PO PROSTORU.
    final stan = stanovi.length == 1
        ? stanovi.first
        : await showModalBottomSheet<Stan>(
            context: context,
            builder: (_) => _IzborStana(stanovi: stanovi),
          );
    if (stan == null || !context.mounted) return;

    try {
      await ref.read(glasanjeRepositoryProvider).glasaj(
            glasanjeId: glasanjeId,
            stanId: stan.id,
            opcija: opcija,
          );
      ref.invalidate(glasanjeDetaljProvider(glasanjeId));
      ref.invalidate(glasanjaProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vaš glas je zabilježen.')),
      );
    } on AppGreska catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.poruka)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glasanje = ref.watch(glasanjeDetaljProvider(glasanjeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Glasanje')),
      body: glasanje.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Greška: $e')),
        data: (g) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(g.naslov,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(g.opis),
            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Pravilo(
                        oznaka: 'Način glasanja', vrijednost: g.nacin.naziv),
                    _Pravilo(
                        oznaka: 'Potrebna većina',
                        vrijednost: g.potrebnaVecina.naziv),
                    _Pravilo(
                        oznaka: 'Kvorum',
                        vrijednost: Formatiranje.procenat(g.kvorumProcenat)),
                    _Pravilo(
                        oznaka: 'Rok',
                        vrijednost: Formatiranje.datumVrijeme(g.krajAt)),
                    if (g.tajno)
                      const _Pravilo(
                          oznaka: 'Tajnost',
                          vrijednost: 'Tajno glasanje'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (g.rezultat != null && !g.tajno) _Rezultat(r: g.rezultat!),

            if (g.jeOtvoreno) ...[
              const SizedBox(height: 24),
              Text('Vaš glas',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: Tema.uspjeh),
                      onPressed: () =>
                          _glasaj(context, ref, OpcijaGlasa.za),
                      icon: const Icon(Icons.thumb_up_outlined),
                      label: const Text('ZA'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: Tema.greska),
                      onPressed: () =>
                          _glasaj(context, ref, OpcijaGlasa.protiv),
                      icon: const Icon(Icons.thumb_down_outlined),
                      label: const Text('PROTIV'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _glasaj(context, ref, OpcijaGlasa.uzdrzan),
                child: const Text('UZDRŽAN'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pravilo extends StatelessWidget {
  const _Pravilo({required this.oznaka, required this.vrijednost});

  final String oznaka;
  final String vrijednost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(oznaka,
              style: TextStyle(color: Theme.of(context).colorScheme.outline)),
          Flexible(
            child: Text(vrijednost,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Rezultat extends StatelessWidget {
  const _Rezultat({required this.r});

  final RezultatGlasanja r;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rezultat',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _Traka(oznaka: 'ZA', vrijednost: r.za, ukupno: r.izaslo,
                boja: Tema.uspjeh),
            _Traka(oznaka: 'PROTIV', vrijednost: r.protiv, ukupno: r.izaslo,
                boja: Tema.greska),
            _Traka(oznaka: 'UZDRŽAN', vrijednost: r.uzdrzan, ukupno: r.izaslo,
                boja: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'Odziv: ${Formatiranje.procenat(r.odzivProcenat)} · '
              'kvorum ${r.kvorumIspunjen ? "ispunjen" : "nije ispunjen"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Traka extends StatelessWidget {
  const _Traka({
    required this.oznaka,
    required this.vrijednost,
    required this.ukupno,
    required this.boja,
  });

  final String oznaka;
  final double vrijednost;
  final double ukupno;
  final Color boja;

  @override
  Widget build(BuildContext context) {
    final udio = ukupno > 0 ? vrijednost / ukupno : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(oznaka),
              Text(Formatiranje.procenat(udio * 100)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: udio.clamp(0, 1),
            minHeight: 8,
            color: boja,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}

class _IzborStana extends StatelessWidget {
  const _IzborStana({required this.stanovi});

  final List<Stan> stanovi;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Za koji prostor glasate?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          for (final s in stanovi)
            ListTile(
              leading: const Icon(Icons.door_front_door_outlined),
              title: Text(s.prikaz),
              subtitle: s.kvadratura == null
                  ? null
                  : Text('${s.kvadratura!.toStringAsFixed(2)} m²'),
              onTap: () => Navigator.pop(context, s),
            ),
        ],
      ),
    );
  }
}
