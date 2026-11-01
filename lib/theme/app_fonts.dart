import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFonts {
  static const aiBodyFamily = 'Source Serif 4';
  static const headingFamily = 'Poppins';
  static const uiFamily = 'Inter';

  static TextTheme appTextTheme([TextTheme? base]) {
    final body = GoogleFonts.getTextTheme(uiFamily, base);
    final headings = GoogleFonts.getTextTheme(headingFamily, base);
    return body.copyWith(
      displayLarge: headings.displayLarge,
      displayMedium: headings.displayMedium,
      displaySmall: headings.displaySmall,
      headlineLarge: headings.headlineLarge,
      headlineMedium: headings.headlineMedium,
      headlineSmall: headings.headlineSmall,
      titleLarge: headings.titleLarge,
      titleMedium: headings.titleMedium,
      titleSmall: headings.titleSmall,
    );
  }

  static TextStyle userMessage({Color? color}) => GoogleFonts.getFont(
        uiFamily,
        color: color,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  static TextStyle assistantMessage({Color? color}) => GoogleFonts.getFont(
        uiFamily,
        color: color,
        fontSize: 16,
        height: 1.55,
      );

  static TextStyle aiResponse({Color? color}) => GoogleFonts.getFont(
        aiBodyFamily,
        color: color,
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.7,
      ).copyWith(
        fontFamilyFallback: const ['Georgia', 'Times New Roman', 'serif'],
      );

  static TextStyle responseHeading({Color? color, double fontSize = 19}) =>
      GoogleFonts.getFont(
        headingFamily,
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ).copyWith(fontFamilyFallback: const ['Arial', 'sans-serif']);

  static TextStyle importantTerm({
    required Color color,
    Color? highlight,
    double fontSize = 16,
  }) =>
      GoogleFonts.getFont(
        headingFamily,
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        backgroundColor: highlight,
        height: 1.55,
      );

  static TextStyle code({
    Color? color,
    double fontSize = 14,
    double height = 1.5,
    Color? backgroundColor,
  }) =>
      GoogleFonts.jetBrainsMono(
        color: color,
        fontSize: fontSize,
        height: height,
        backgroundColor: backgroundColor,
      );

  static TextStyle messageLabel({
    required Color color,
    required bool isUser,
  }) =>
      GoogleFonts.getFont(
        uiFamily,
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      );

  static TextStyle timestamp({
    required Color color,
    required bool isUser,
  }) =>
      GoogleFonts.getFont(
        uiFamily,
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.25,
      );
}
