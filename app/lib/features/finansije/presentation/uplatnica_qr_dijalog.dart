import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/utils/formatiranje.dart';

/// Prikaz uplatnice sa QR kodom za skeniranje u mobilnoj banci.
///
/// `qrSadrzaj` dolazi IZ BAZE (`transakcije_uplatnice.qr_sadrzaj`, generisan
/// funkcijom `fn_generisi_qr`). Klijent ga nikad ne sastavlja sam — format
/// zavisi od standarda banke (EPC069-12 / IPS) i konfiguriše se po zgradi.
class UplatnicaQrDijalog extends StatelessWidget {
  const UplatnicaQrDijalog({
    required this.qrSadrzaj,
    required this.pozivNaBroj,
    required this.iznos,
    required this.primalac,
    required this.racun,
    super.key,
  });

  final String qrSadrzaj;
  final String pozivNaBroj;
  final double iznos;
  final String primalac;
  final String racun;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Uplatnica',
                  style: Theme.of(context).textTheme.titleLarge,),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: QrImageView(
                  data: qrSadrzaj,
                  size: 220,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              const SizedBox(height: 16),
              _Podatak(oznaka: 'Primalac', vrijednost: primalac),
              _Podatak(oznaka: 'Račun', vrijednost: racun),
              _Podatak(oznaka: 'Poziv na broj', vrijednost: pozivNaBroj),
              _Podatak(
                  oznaka: 'Iznos', vrijednost: Formatiranje.novac(iznos),),
              const SizedBox(height: 16),
              Text(
                'Skenirajte QR kod u aplikaciji vaše banke.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Zatvori'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Podatak extends StatelessWidget {
  const _Podatak({required this.oznaka, required this.vrijednost});

  final String oznaka;
  final String vrijednost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(oznaka,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.outline),),
          ),
          Expanded(
            child: SelectableText(
              vrijednost,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
