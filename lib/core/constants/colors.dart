import 'package:flutter/material.dart';

/// BODA CONNECT Design Tokens - Colors
/// Based on Figma specifications
class AppColors {
  AppColors._();

  // Primary Colors (Brand - Red/Rose from Figma #C61F42)
  static const Color peach = Color(0xFFC61F42);
  static const Color peachLight = Color(0xFFE57A93);
  static const Color peachDark = Color(0xFFA01735);

  // Base Colors
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Gray Scale
  static const Color gray900 = Color(0xFF111111);
  static const Color gray700 = Color(0xFF3A3A3A);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color gray300 = Color(0xFFD1D5DB);
  static const Color gray200 = Color(0xFFE5E7EB);
  static const Color gray100 = Color(0xFFF3F4F6);
  static const Color gray50 = Color(0xFFF9FAFB);

  // Semantic Colors
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Background Colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F5F5);

  // Text Colors
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF737373);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFF000000);

  // Border Colors
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderDark = Color(0xFFD1D5DB);

  // Special Colors
  static const Color whatsapp = Color(0xFF25D366);
  static const Color premium = Color(0xFFDB2777);
  static const Color premiumLight = Color(0xFFFCE7F3);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [peach, peachDark],
  );

  // Shadow
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 18,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: Color(0x1AC61F42),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
}
