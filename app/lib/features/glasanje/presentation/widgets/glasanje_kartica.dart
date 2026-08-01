import 'package:flutter/material.dart';

import '../../../../core/theme/tema.dart';
import '../../../../core/utils/formatiranje.dart';
import '../../../../shared/models/enumi.dart';
import '../../../../shared/models/modeli.dart';

class GlasanjeKartica extends StatelessWidget {
  const GlasanjeKartica({required this.glasanje, required this.onTap, super.key});

  final Glasanje glasanje;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final r = glasanje.rezultat;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatusZnacka(glasanje: glasanje),
                  const Spacer(),
                  if (glasanje.jaGlasao)
                    const Chip(
                      avatar: Icon(Icons.check, size: 16, color: Tema.uspjeh),
                      label: Text('Glasali ste'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(glasanje.naslov,
                  style: tema.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),),
              const SizedBox(height: 4),
              Text(
                glasanje.opis,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.bodyMedium
                    ?.copyWith(color: tema.colorScheme.outline),
              ),
              const SizedBox(height: 12),

              // Kod tajnog glasanja baza ne vraća uživo rezultat.
              if (r != null && !glasanje.tajno) ...[
                LinearProgressIndicator(
                  value: (r.odzivProcenat / 100).clamp(0, 1),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 6),
                Text(
                  'Odziv ${Formatiranje.procenat(r.odzivProcenat)} '
                  '· kvorum ${r.kvorumIspunjen ? "ispunjen" : "nije ispunjen"}',
                  style: tema.textTheme.bodySmall,
                ),
              ],

              if (glasanje.jeOtvoreno) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16),
                    const SizedBox(width: 6),
                    Text('Ističe za ${Formatiranje.trajanje(glasanje.preostalo)}',
                        style: tema.textTheme.bodySmall,),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusZnacka extends StatelessWidget {
  const _StatusZnacka({required this.glasanje});

  final Glasanje glasanje;

  @override
  Widget build(BuildContext context) {
    final (boja, tekst) = switch (glasanje.status) {
      StatusGlasanja.aktivno => (Tema.uspjeh, 'U TOKU'),
      StatusGlasanja.zakazano => (Tema.akcent, 'ZAKAZANO'),
      StatusGlasanja.zavrseno => glasanje.usvojeno == true
          ? (Tema.uspjeh, 'USVOJENO')
          : (Tema.greska, 'NIJE USVOJENO'),
      StatusGlasanja.ponisteno => (Tema.greska, 'PONIŠTENO'),
      StatusGlasanja.nacrt => (Colors.grey, 'NACRT'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: boja.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tekst,
        style: TextStyle(
            color: boja, fontWeight: FontWeight.bold, fontSize: 11,),
      ),
    );
  }
}
