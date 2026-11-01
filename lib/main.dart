import 'package:flutter/material.dart';
import 'package:uniguide/layout/adaptive_scaffold.dart';
import 'package:uniguide/theme/app_fonts.dart';
import 'package:uniguide/theme/app_colors.dart';

void main() {
  runApp(const UniGuideApp());
}

class UniGuideApp extends StatelessWidget {
  const UniGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniGuide',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: AppColors.colorScheme,
        scaffoldBackgroundColor: AppColors.background,
        textTheme: AppFonts.appTextTheme(),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        dividerColor: AppColors.border,
        inputDecorationTheme: const InputDecorationTheme(
          hintStyle: TextStyle(color: AppColors.muted),
          labelStyle: TextStyle(color: AppColors.muted),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.surface,
          contentTextStyle: TextStyle(color: AppColors.botText),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.heading,
        ),
      ),
      themeMode: ThemeMode.light,
      home: const AdaptiveScaffold(),
    );
  }
}
