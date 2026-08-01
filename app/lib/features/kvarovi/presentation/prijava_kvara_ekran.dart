import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/enumi.dart';

/// Prijava novog kvara sa fotografijama.
///
/// TODO: upload slika u bucket `kvarovi/<zgrada_id>/<kvar_id>/…`
/// (konvencija putanje je osnov Storage RLS politika — vidi schema.sql, sekcija 9).
class PrijavaKvaraEkran extends ConsumerStatefulWidget {
  const PrijavaKvaraEkran({super.key});

  @override
  ConsumerState<PrijavaKvaraEkran> createState() => _PrijavaKvaraEkranState();
}

class _PrijavaKvaraEkranState extends ConsumerState<PrijavaKvaraEkran> {
  final _kljuc = GlobalKey<FormState>();
  final _naslov = TextEditingController();
  final _opis = TextEditingController();
  final _lokacija = TextEditingController();

  KategorijaKvara _kategorija = KategorijaKvara.ostalo;
  PrioritetKvara _prioritet = PrioritetKvara.srednji;

  @override
  void dispose() {
    _naslov.dispose();
    _opis.dispose();
    _lokacija.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prijavi kvar')),
      body: Form(
        key: _kljuc,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _naslov,
              decoration: const InputDecoration(
                labelText: 'Šta je u kvaru?',
                hintText: 'npr. Ne radi lift',
              ),
              validator: (v) => (v == null || v.trim().length < 3)
                  ? 'Unesite kratak naslov'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<KategorijaKvara>(
              initialValue: _kategorija,
              decoration: const InputDecoration(labelText: 'Kategorija'),
              items: [
                for (final k in KategorijaKvara.values)
                  DropdownMenuItem(value: k, child: Text(k.naziv)),
              ],
              onChanged: (v) => setState(() => _kategorija = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PrioritetKvara>(
              initialValue: _prioritet,
              decoration: const InputDecoration(labelText: 'Prioritet'),
              items: [
                for (final p in PrioritetKvara.values)
                  DropdownMenuItem(value: p, child: Text(p.naziv)),
              ],
              onChanged: (v) => setState(() => _prioritet = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lokacija,
              decoration: const InputDecoration(
                labelText: 'Lokacija (opciono)',
                hintText: 'npr. 3. sprat, hodnik kod lifta',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _opis,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Opis problema'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Opišite problem'
                  : null,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Dodaj fotografije'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                if (_kljuc.currentState?.validate() ?? false) {
                  // TODO: KvaroviRepository.prijavi(...)
                }
              },
              child: const Text('Pošalji prijavu'),
            ),
          ],
        ),
      ),
    );
  }
}
