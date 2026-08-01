import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/kontekst_provider.dart';

/// Modul 5 — Zgrada: podaci, imenik, kontakti, dokumenti, profil.
class ZgradaEkran extends ConsumerWidget {
  const ZgradaEkran({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zgrada = ref.watch(aktivnaZgradaProvider);
    final uloga = ref.watch(mojaUlogaProvider);
    final jeUprava = ref.watch(jeUpravaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Zgrada')),
      body: ListView(
        children: [
          zgrada.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ListTile(title: Text('Greška: $e')),
            data: (z) => z == null
                ? const ListTile(
                    title: Text('Niste član nijedne zgrade'),
                    subtitle: Text('Zatražite pozivnicu od uprave.'),
                  )
                : ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.apartment)),
                    title: Text(z.naziv),
                    subtitle: Text(z.punaAdresa),
                  ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.contacts_outlined),
            title: const Text('Imenik stanara'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.emergency_outlined),
            title: const Text('Hitni kontakti'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Dokumenti'),
            subtitle: const Text('Zapisnici, ugovori, računi'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          if (jeUprava) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Uprava',
                  style: TextStyle(fontWeight: FontWeight.bold),),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Članovi i uloge'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('Pozivnice'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Mjesečni obračun'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Moj profil'),
            subtitle: uloga == null ? null : Text(uloga.naziv),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/zgrada/profil'),
          ),
        ],
      ),
    );
  }
}
