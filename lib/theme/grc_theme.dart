// lib/theme/grc_theme.dart
import 'package:flutter/material.dart';

class GrcColors {
  // PRIMARY BRAND
  static const Color maroon       = Color(0xFF8A1538);
  static const Color maroonDark   = Color(0xFF6B1029); // deeper hover shade
  static const Color maroonLight  = Color(0xFFAD1C47); // lighter accent

  // PANEL COLORS
  static const Color leftPanel    = Color(0xFF8A1538); // brand side panel
  static const Color leftPanelText = Color(0xFFF9F6F0);
  static const Color leftPanelSub  = Color(0xFFD4A0B0); // muted text on maroon

  // BACKGROUNDS
  static const Color background   = Color(0xFFF8F8F8);
  static const Color surface      = Colors.white;
  static const Color surfaceAlt   = Color(0xFFF4F4F4);

  // TEXT
  static const Color textDark     = Color(0xFF1A1A1A);
  static const Color textMid      = Color(0xFF555555);
  static const Color textLight    = Color(0xFF9E9E9E);

  // BORDERS & DIVIDERS
  static const Color border       = Color(0xFFE0E0E0);
  static const Color divider      = Color(0xFFEEEEEE);

  // GOLD ACCENT (kept for compatibility)
  static const Color gold         = Color(0xFFF9F6F0);

  // STATUS COLORS
  static const Color success      = Color(0xFF2E7D32);
  static const Color warning      = Color(0xFFE65100);
  static const Color danger       = Color(0xFFC62828);
}

class GrcTextStyles {
  // Panel heading (white on maroon)
  static const TextStyle panelTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: GrcColors.leftPanelText,
    letterSpacing: 1.5,
  );

  static const TextStyle panelSub = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: GrcColors.leftPanelSub,
    letterSpacing: 0.5,
    height: 1.5,
  );

  // Form heading
  static const TextStyle formTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: GrcColors.textDark,
    letterSpacing: -0.3,
  );

  static const TextStyle formSub = TextStyle(
    fontSize: 12,
    color: GrcColors.textLight,
    height: 1.5,
  );

  // Section labels
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: GrcColors.textLight,
    letterSpacing: 1.5,
  );
}

class GrcTheme {
  static ThemeData get theme => ThemeData(
    scaffoldBackgroundColor: GrcColors.background,
    primaryColor: GrcColors.maroon,
    colorScheme: const ColorScheme.light(
      primary: GrcColors.maroon,
      secondary: GrcColors.maroonLight,
      surface: GrcColors.surface,
    ),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      backgroundColor: GrcColors.maroon,
      elevation: 0,
      iconTheme: IconThemeData(color: GrcColors.leftPanelText),
      titleTextStyle: TextStyle(
        color: GrcColors.leftPanelText,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GrcColors.maroon,
        foregroundColor: GrcColors.leftPanelText,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: GrcColors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: GrcColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: GrcColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: GrcColors.maroon, width: 1.5),
      ),
      labelStyle: const TextStyle(color: GrcColors.textLight, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: GrcColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: GrcColors.border),
      ),
    ),
    dividerTheme: const DividerThemeData(color: GrcColors.divider, thickness: 1),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: GrcColors.surface,
      selectedIconTheme: IconThemeData(color: GrcColors.maroon),
      selectedLabelTextStyle: TextStyle(color: GrcColors.maroon, fontWeight: FontWeight.w700, fontSize: 11),
      unselectedIconTheme: IconThemeData(color: GrcColors.textLight),
      unselectedLabelTextStyle: TextStyle(color: GrcColors.textLight, fontSize: 11),
    ),
  );
}