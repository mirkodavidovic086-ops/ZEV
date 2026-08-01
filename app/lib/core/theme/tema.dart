import 'package:flutter/material.dart';

/// Tema aplikacije.
///
/// Ciljana publika uključuje stariju populaciju, pa su minimalne veličine
/// fonta i dodirnih meta namjerno veće od Material podrazumijevanih.
class Tema {
  const Tema._();

  static const Color primarna = Color(0xFF1B5E5A);   // teal — povjerenje, mirnoća
  static const Color akcent = Color(0xFFE8A33D);     // amber — akcije, hitno
  static const Color uspjeh = Color(0xFF2E7D32);
  static const Color upozorenje = Color(0xFFED6C02);
  static const Color greska = Color(0xFFC62828);

  /// Minimalna visina dodirne mete (Material preporučuje 48).
  static const double minDodir = 52;

  static ThemeData get svijetla => _gradi(Brightness.light);
  static ThemeData get tamna => _gradi(Brightness.dark);

  static ThemeData _gradi(Brightness svjetlina) {
    final sheme = ColorScheme.fromSeed(
      seedColor: primarna,
      brightness: svjetlina,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: sheme,
      visualDensity: VisualDensity.comfortable,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontSize: 17),
        bodyMedium: TextStyle(fontSize: 16),
        labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(minDodir),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: sheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
