import 'package:flutter/material.dart';

/// Paleta de instrumento antiguo compartida por el menú y los puzzles:
/// madera oscura, latón y cristal ámbar.
abstract final class VestigiaColors {
  static const background = Color(0xFF16100C);
  static const wood = Color(0xFF3A2416);
  static const woodLight = Color(0xFF5A3A22);
  static const brass = Color(0xFFD4A24C);
  static const brassDark = Color(0xFF8A6526);
  static const cream = Color(0xFFF1E4C6);
  static const creamMuted = Color(0xFFB9A887);
  static const glass = Color(0xFF1F150B);
  static const glow = Color(0xFFFFC566);
  static const needle = Color(0xFFD8553A);
  static const signal = Color(0xFF7FD6A0);
}

ThemeData buildVestigiaTheme() {
  const scheme = ColorScheme.dark(
    primary: VestigiaColors.brass,
    onPrimary: VestigiaColors.background,
    secondary: VestigiaColors.glow,
    surface: VestigiaColors.wood,
    onSurface: VestigiaColors.cream,
    error: VestigiaColors.needle,
  );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: VestigiaColors.background,
    fontFamily: 'serif',
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: VestigiaColors.cream,
      elevation: 0,
      centerTitle: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: VestigiaColors.brass,
        foregroundColor: VestigiaColors.background,
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VestigiaColors.cream,
        side: const BorderSide(color: VestigiaColors.brassDark, width: 1.5),
        minimumSize: const Size(64, 52),
        textStyle: const TextStyle(fontSize: 17),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: VestigiaColors.creamMuted,
        minimumSize: const Size(48, 48),
      ),
    ),
  );
}
