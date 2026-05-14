import 'package:flutter/material.dart';

/// Futuristic dark theme: OLED black backgrounds, neon cyan/magenta accents.
class AppTheme {
  AppTheme._();

  static const _fontFamily = 'Orbitron';

  // Colors
  static const background = Color(0xFF0B0C10);
  static const surface = Color(0xFF1F2833);
  static const surfaceLight = Color(0xFF2A3441);
  static const neonCyan = Color(0xFF66FCF1);
  static const neonCrimson = Color(0xFFFF0055);
  static const neonPurple = Color(0xFFC77DFF);
  static const textPrimary = Color(0xFFF0F0F0);
  static const textSecondary = Color(0xFFB0B0B0);
  static const whitePiece = Color(0xFFF8F8F8);
  static const blackPiece = Color(0xFF2D2D2D);

  // Board colors
  static const boardLight = Color(0xFF2C3E50);
  static const boardDark = Color(0xFF1A252F);
  static const selectedSquare = Color(0x3366FCF1);
  static const validMoveGlow = Color(0x4066FCF1);
  static const captureGlow = Color(0x40FF0055);
  static const lastMoveHighlight = Color(0x2066FCF1);

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      fontFamily: _fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: neonCyan,
        secondary: neonCrimson,
        surface: surface,
        error: neonCrimson,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: neonCyan, width: 0.5),
        ),
      ),
    );
  }
}
