import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import '../constants/app_text_styles.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    textTheme: GoogleFonts.almaraiTextTheme().copyWith(
      displayLarge: AppTextStyles.h1,
      displayMedium: AppTextStyles.h2,
      displaySmall: AppTextStyles.h3,
      headlineMedium: AppTextStyles.h4,
      bodyLarge: AppTextStyles.bodyLarge,
      bodyMedium: AppTextStyles.bodyMedium,
      bodySmall: AppTextStyles.bodySmall,
      labelLarge: AppTextStyles.buttonMedium,
      labelMedium: AppTextStyles.label,
      labelSmall: AppTextStyles.labelSmall,
    ),
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: const Color.fromARGB(255, 255, 255, 255),

    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: AppTextStyles.h3.copyWith(color: Colors.white),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        textStyle: AppTextStyles.buttonMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      hintStyle: AppTextStyles.hint,
      labelStyle: AppTextStyles.label,
      errorStyle: AppTextStyles.error,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    ),
  );
}
