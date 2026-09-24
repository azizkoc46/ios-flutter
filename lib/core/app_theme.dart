import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Color(0xFF38BDF8);
  static const Color darkBackground = Color(0xFF0B0F19);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color iosDarkGrey = Color(0xFF131B2E);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'SF Pro Display',
    brightness: Brightness.light,
    colorSchemeSeed: const Color(0xFF0056D2),
    scaffoldBackgroundColor: lightBackground,
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'SF Pro Display',
    brightness: Brightness.dark,
    colorSchemeSeed: primaryBlue,
    scaffoldBackgroundColor: darkBackground,
    canvasColor: darkBackground,
    cardColor: iosDarkGrey,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: iosDarkGrey,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
      ),
    ),
  );
}
