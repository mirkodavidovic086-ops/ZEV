import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Detalj kvara: opis, slike, historija statusa, komentari.
///
/// TODO: povezati sa `kvarovi`, `prilozi`, `komentari` i `kvar_potvrde`.
class KvarDetaljEkran extends ConsumerWidget {
  const KvarDetaljEkran({required this.kvarId, super.key});

  final String kvarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalji kvara')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Kvar: $kvarId\n\nEkran u izradi.',
              textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
