import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  const ink = Color(0xFF18201F);
  const paper = Color(0xFFF7F5EF);
  const moss = Color(0xFF2E6B57);
  const ember = Color(0xFFE65F2B);
  const sea = Color(0xFF0A7890);

  final scheme = ColorScheme.fromSeed(
    seedColor: moss,
    brightness: Brightness.light,
    primary: moss,
    secondary: ember,
    tertiary: sea,
    surface: paper,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    fontFamily: 'Segoe UI',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontWeight: FontWeight.w800, color: ink),
      headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: ink),
      titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: ink),
      bodyLarge: TextStyle(color: ink, height: 1.35),
      bodyMedium: TextStyle(color: ink, height: 1.35),
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFFECF0E8),
      selectedIconTheme: IconThemeData(color: moss),
      selectedLabelTextStyle: TextStyle(color: moss, fontWeight: FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      filled: true,
      fillColor: Colors.white,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFDDE4DA)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    ),
  );
}
