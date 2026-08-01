import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/tema.dart';
import '../../../core/utils/formatiranje.dart';
import 'uplatnica_qr_dijalog.dart';

/// Modul 2 — Finansije.
///
/// Dvije kartice:
///  • Moje stanje  — saldo, zaduženja, uplatnica sa QR kodom
///  • Račun zgrade — kompletni prihodi i rashodi ZEV-a (vidljivo SVIMA;
///    transparentnost je ključna vrijednost proizvoda)
class FinansijeEkran extends ConsumerWidget {
  const FinansijeEkran({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finansije'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Moje stanje'),
              Tab(text: 'Račun zgrade'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_MojeStanje(), _RacunZgrade()],
        ),
      ),
    );
  }
}

class _MojeStanje extends ConsumerWidget {
  const _MojeStanje();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: `pogled_stanje_stana` + `transakcije_uplatnice` kroz repository.
    const saldo = 26.00;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: saldo > 0
              ? Tema.greska.withValues(alpha: 0.08)
              : Tema.uspjeh.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(saldo > 0 ? 'Vaš dug' : 'Nemate dugovanja',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  Formatiranje.novac(saldo),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: saldo > 0 ? Tema.greska : Tema.uspjeh,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => const UplatnicaQrDijalog(
              // Payload generiše baza (`fn_generisi_qr`) — klijent ga samo
              // iscrtava. Ovdje je primjer radi prikaza skeleta.
              qrSadrzaj: 'BCD\n002\n1\nSCT\n\nZEV Titova 15\n'
                  'BA391290079401028494\nBAM26.00\n\n82ZEV10012026081\n\n'
                  'Naknada 08/2026',
              pozivNaBroj: '82ZEV10012026081',
              iznos: 26.00,
              primalac: 'ZEV Titova 15',
              racun: 'BA391290079401028494',
            ),
          ),
          icon: const Icon(Icons.qr_code_2),
          label: const Text('Prikaži uplatnicu sa QR kodom'),
        ),
        const SizedBox(height: 24),
        Text('Promet', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const _Stavka(
          opis: 'Mjesečna naknada 08/2026',
          iznos: 26.00,
          zaduzenje: true,
        ),
        const _Stavka(
          opis: 'Uplata na blagajni',
          iznos: 20.00,
          zaduzenje: false,
        ),
      ],
    );
  }
}

class _RacunZgrade extends ConsumerWidget {
  const _RacunZgrade();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: `pogled_stanje_zgrade` + `troskovi_zev` kroz repository.
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stanje fonda',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _Red(oznaka: 'Prihodi (uplate stanara)', iznos: 1240.00),
                _Red(oznaka: 'Rashodi', iznos: -890.50),
                Divider(height: 24),
                _Red(oznaka: 'Saldo', iznos: 349.50, istaknuto: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Svaki član zgrade vidi sve stavke — bez izuzetka.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _Red extends StatelessWidget {
  const _Red({
    required this.oznaka,
    required this.iznos,
    this.istaknuto = false,
  });

  final String oznaka;
  final double iznos;
  final bool istaknuto;

  @override
  Widget build(BuildContext context) {
    final stil = istaknuto
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(oznaka, style: stil),
          Text(Formatiranje.novac(iznos), style: stil),
        ],
      ),
    );
  }
}

class _Stavka extends StatelessWidget {
  const _Stavka({
    required this.opis,
    required this.iznos,
    required this.zaduzenje,
  });

  final String opis;
  final double iznos;
  final bool zaduzenje;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: (zaduzenje ? Tema.greska : Tema.uspjeh)
            .withValues(alpha: 0.15),
        child: Icon(
          zaduzenje ? Icons.arrow_upward : Icons.arrow_downward,
          color: zaduzenje ? Tema.greska : Tema.uspjeh,
        ),
      ),
      title: Text(opis),
      trailing: Text(
        '${zaduzenje ? '+' : '−'} ${Formatiranje.novac(iznos)}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: zaduzenje ? Tema.greska : Tema.uspjeh,
        ),
      ),
    );
  }
}
