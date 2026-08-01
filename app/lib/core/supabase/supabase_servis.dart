import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/okruzenje.dart';

/// Inicijalizacija i pristup Supabase klijentu.
class SupabaseServis {
  const SupabaseServis._();

  static Future<void> inicijalizuj() async {
    Okruzenje.provjeri();
    await Supabase.initialize(
      url: Okruzenje.supabaseUrl,
      publishableKey: Okruzenje.supabaseAnonKljuc,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get klijent => Supabase.instance.client;
}

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return SupabaseServis.klijent;
});

/// Tok promjena stanja prijave. Koristi ga `go_router` za auth guard.
final authStanjeProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

/// Trenutno prijavljeni korisnik, ili `null`.
final trenutniKorisnikProvider = Provider<User?>((ref) {
  ref.watch(authStanjeProvider);
  return ref.watch(supabaseProvider).auth.currentUser;
});
