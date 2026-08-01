import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_servis.dart';

class ProfilEkran extends ConsumerWidget {
  const ProfilEkran({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final korisnik = ref.watch(trenutniKorisnikProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Moj profil')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(korisnik?.email ?? korisnik?.phone ?? 'Korisnik'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Obavještenja'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('Vidljivost u imeniku'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Jezik'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Odjava', style: TextStyle(color: Colors.red)),
            onTap: () => ref.read(supabaseProvider).auth.signOut(),
          ),
        ],
      ),
    );
  }
}
