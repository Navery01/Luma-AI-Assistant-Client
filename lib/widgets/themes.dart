import 'package:flutter/material.dart';

class AppTheme {

  static RadialGradient gradient(Color outer, Color inner) => RadialGradient(
    colors: [outer, inner],
    focal: Alignment.center,
    focalRadius: 0.8,
    radius: 0.4,
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: ColorScheme.dark(
      surface: Colors.black,
      onSurface: Colors.white,
      surfaceTint: Colors.indigo.shade700,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
    ),
    textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.deepPurple,
    colorScheme: ColorScheme.light(
      surface: Colors.white,
      onSurface: Colors.black,
      surfaceTint: Colors.indigo.shade700,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),
    textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.black)),
  );
}
