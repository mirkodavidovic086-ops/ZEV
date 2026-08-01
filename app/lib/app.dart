import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/rute.dart';
import 'core/theme/tema.dart';

class MojZevApp extends ConsumerWidget {
  const MojZevApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MojZEV',
      debugShowCheckedModeBanner: false,
      theme: Tema.svijetla,
      darkTheme: Tema.tamna,
      themeMode: ThemeMode.system,
      routerConfig: router,
      locale: const Locale('bs'),
      supportedLocales: const [
        Locale('bs'),
        Locale('hr'),
        Locale('sr'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
