import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue = Colors.blueAccent;
  static const Color darkBackground = Color(0xFF121212);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color iosDarkGrey = Color(0xFF1C1C1E);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'SF Pro Display',
    brightness: Brightness.light,
    colorSchemeSeed: primaryBlue,
    scaffoldBackgroundColor: lightBackground,
    // DÜZELTME: CardTheme yerine CardThemeData kullanıldı
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
    // DÜZELTME: CardTheme yerine CardThemeData kullanıldı
    cardTheme: CardThemeData(
      color: iosDarkGrey,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
