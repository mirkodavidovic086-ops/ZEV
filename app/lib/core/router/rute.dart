import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/prijava_ekran.dart';
import '../../features/auth/presentation/otp_ekran.dart';
import '../../features/finansije/presentation/finansije_ekran.dart';
import '../../features/glasanje/presentation/glasanje_ekran.dart';
import '../../features/glasanje/presentation/glasanje_detalj_ekran.dart';
import '../../features/kvarovi/presentation/kvarovi_ekran.dart';
import '../../features/kvarovi/presentation/kvar_detalj_ekran.dart';
import '../../features/kvarovi/presentation/prijava_kvara_ekran.dart';
import '../../features/pocetna/presentation/pocetna_ekran.dart';
import '../../features/profil/presentation/profil_ekran.dart';
import '../../features/zgrada/presentation/zgrada_ekran.dart';
import '../supabase/supabase_servis.dart';
import '../widgets/glavna_ljuska.dart';

/// Nazivi ruta — koristi ih umjesto sirovih stringova.
abstract final class Rute {
  static const prijava = '/prijava';
  static const otp = '/prijava/otp';

  static const pocetna = '/';
  static const finansije = '/finansije';
  static const glasanje = '/glasanje';
  static const kvarovi = '/kvarovi';
  static const zgrada = '/zgrada';
  static const profil = '/profil';
}

final _korijenKljuc = GlobalKey<NavigatorState>();
final _ljuskaKljuc = GlobalKey<NavigatorState>();

/// Router se namjerno gradi SAMO JEDNOM (`Provider`, bez `ref.watch` na
/// stanje prijave). Kad bi se presložio pri svakoj promjeni auth stanja,
/// izgubila bi se historija navigacije. Reakciju na prijavu/odjavu obavlja
/// `refreshListenable` + `redirect`.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _korijenKljuc,
    initialLocation: Rute.pocetna,

    // Preusmjeravanje na prijavu dok korisnik nije autentifikovan.
    redirect: (context, state) {
      final prijavljen =
          ref.read(supabaseProvider).auth.currentSession != null;
      final naAuthEkranu = state.matchedLocation.startsWith(Rute.prijava);

      if (!prijavljen && !naAuthEkranu) return Rute.prijava;
      if (prijavljen && naAuthEkranu) return Rute.pocetna;
      return null;
    },
    refreshListenable: _AuthOsvjezivac(ref),

    routes: [
      GoRoute(
        path: Rute.prijava,
        builder: (_, __) => const PrijavaEkran(),
        routes: [
          GoRoute(
            path: 'otp',
            builder: (_, state) => OtpEkran(
              kontakt: state.uri.queryParameters['kontakt'] ?? '',
            ),
          ),
        ],
      ),

      // Donja navigacija — pet modula iz specifikacije.
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _korijenKljuc,
        builder: (_, __, ljuska) => GlavnaLjuska(ljuska: ljuska),
        branches: [
          StatefulShellBranch(
            navigatorKey: _ljuskaKljuc,
            routes: [
              GoRoute(path: Rute.pocetna, builder: (_, __) => const PocetnaEkran()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.finansije,
                builder: (_, __) => const FinansijeEkran(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.glasanje,
                builder: (_, __) => const GlasanjeEkran(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => GlasanjeDetaljEkran(
                      glasanjeId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.kvarovi,
                builder: (_, __) => const KvaroviEkran(),
                routes: [
                  GoRoute(
                    path: 'novi',
                    builder: (_, __) => const PrijavaKvaraEkran(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => KvarDetaljEkran(
                      kvarId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rute.zgrada,
                builder: (_, __) => const ZgradaEkran(),
                routes: [
                  GoRoute(
                    path: 'profil',
                    builder: (_, __) => const ProfilEkran(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],

    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Stranica nije pronađena: ${state.uri}')),
    ),
  );
});

/// Premošćuje Riverpod stream u `Listenable` koji `go_router` očekuje.
class _AuthOsvjezivac extends ChangeNotifier {
  _AuthOsvjezivac(Ref ref) {
    ref.listen(authStanjeProvider, (_, __) => notifyListeners());
  }
}
