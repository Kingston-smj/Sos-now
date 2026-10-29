import 'package:flutter/material.dart';

ThemeData buildTheme() {
  const green = Color(0xFF0E4D3A);
  const red = Color(0xFFB42318);
  final scheme = ColorScheme.fromSeed(
    seedColor: green,
    primary: green,
    secondary: red,
    surface: const Color(0xFFF7F4EE),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF7F4EE),
    appBarTheme: const AppBarTheme(
      backgroundColor: green,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
      fillColor: Colors.white,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFD7E8E1),
    ),
  );
}

Color categoryColor(String category) {
  switch (category) {
    case 'Accident':
      return const Color(0xFFB45309);
    case 'Fighting':
      return const Color(0xFFC2410C);
    case 'Rioting':
      return const Color(0xFFB42318);
    case 'Robbery':
      return const Color(0xFF6D28D9);
    case 'Fire':
      return const Color(0xFFDC2626);
    case 'Medical':
      return const Color(0xFF0F766E);
    case 'Flood':
      return const Color(0xFF1D4ED8);
    case 'Kidnapping':
      return const Color(0xFF3730A3);
    default:
      return const Color(0xFF3F4A45);
  }
}
