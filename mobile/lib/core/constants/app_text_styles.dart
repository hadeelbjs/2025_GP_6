import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTextStyles {
  // ====================================
  // Font Family
  // ====================================
  static const String fontFamily = 'Almarai';

  // ====================================
  // Headers / Titles
  // ====================================

  // H1 - عناوين كبيرة جداً
  static TextStyle h1 = GoogleFonts.almarai(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // H2 - عناوين الصفحات
  static TextStyle h2 = GoogleFonts.almarai(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // H3 - عناوين الأقسام
  static TextStyle h3 = GoogleFonts.almarai(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // H4 - عناوين فرعية
  static TextStyle h4 = GoogleFonts.almarai(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ====================================
  // Body Text
  // ====================================

  // Body Large - نصوص كبيرة
  static TextStyle bodyLarge = GoogleFonts.almarai(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // Body Medium - نصوص متوسطة (الأكثر استخداماً)
  static TextStyle bodyMedium = GoogleFonts.almarai(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  // Body Small - نصوص صغيرة
  static TextStyle bodySmall = GoogleFonts.almarai(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // ====================================
  // Button Text
  // ====================================

  // Button Large
  static TextStyle buttonLarge = GoogleFonts.almarai(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
    height: 1.2,
  );

  // Button Medium
  static TextStyle buttonMedium = GoogleFonts.almarai(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
    height: 1.2,
  );

  // Button Small
  static TextStyle buttonSmall = GoogleFonts.almarai(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textLight,
    height: 1.2,
  );

  // ====================================
  // Labels
  // ====================================

  // Label - تسميات الحقول
  static TextStyle label = GoogleFonts.almarai(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // Label Small
  static TextStyle labelSmall = GoogleFonts.almarai(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  // ====================================
  // Hints / Placeholders
  // ====================================

  static TextStyle hint = GoogleFonts.almarai(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textHint,
    height: 1.3,
  );

  static TextStyle hintLarge = GoogleFonts.almarai(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textHint,
    height: 1.3,
  );

  // ====================================
  // Special Text Styles
  // ====================================

  // Contact Name - اسم جهة الاتصال
  static TextStyle contactName = GoogleFonts.almarai(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // Search Text
  static TextStyle searchText = GoogleFonts.almarai(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // Caption - نصوص توضيحية صغيرة جداً
  static TextStyle caption = GoogleFonts.almarai(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  // Overline - نصوص فوق الأزرار أو العناوين
  static TextStyle overline = GoogleFonts.almarai(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 1.3,
    letterSpacing: 1.5,
  );

  // Error Text
  static TextStyle error = GoogleFonts.almarai(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: Colors.red,
    height: 1.3,
  );

  // Success Text
  static TextStyle success = GoogleFonts.almarai(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.green,
    height: 1.3,
  );

  // ====================================
  // Dialog Text Styles
  // ====================================

  // Dialog Title
  static TextStyle dialogTitle = GoogleFonts.almarai(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.textLight,
    height: 1.3,
  );

  // Dialog Content
  static TextStyle dialogContent = GoogleFonts.almarai(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight.withOpacity(0.7),
    height: 1.5,
  );
}
