import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const sidebar = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF5F9FF);
  static const border = Color(0xFFC8D8F5);
  static const primary = Color(0xFF1E5EFF);
  static const primaryDark = Color(0xFF0B3BB5);
  static const primaryLight = Color(0xFFE6EEFF);
  static const responseBody = Color(0xFF1F2937);
  static const highlight = Color(0xFF1E5EFF);
  static const botText = Color(0xFF1A1F2B);
  static const userText = Color(0xFF1A1F2B);
  static const keyTerm = highlight;
  static const accent = primary;
  static const muted = Color(0xFF565F70);
  static const heading = Color(0xFF111827);
  static const error = primaryDark;

  static const codeKeyword = primaryDark;
  static const codeString = primary;
  static const codeComment = muted;
  static const codeFunction = primaryDark;
  static const codeNumber = primaryDark;
  static const tableHeader = primaryLight;

  static ColorScheme get colorScheme => const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: background,
        primaryContainer: primaryLight,
        onPrimaryContainer: primaryDark,
        secondary: primaryDark,
        onSecondary: background,
        secondaryContainer: primaryLight,
        onSecondaryContainer: botText,
        tertiary: primary,
        onTertiary: background,
        error: error,
        onError: background,
        surface: background,
        onSurface: botText,
        surfaceContainerHighest: surface,
        onSurfaceVariant: muted,
        outline: border,
        outlineVariant: border,
        shadow: heading,
        scrim: heading,
        inverseSurface: heading,
        onInverseSurface: background,
        inversePrimary: primaryLight,
        surfaceTint: primary,
      );
}
