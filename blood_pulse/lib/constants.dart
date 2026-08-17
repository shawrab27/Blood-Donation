import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand Colors
  static const Color primaryRed = Color(0xFFC32121);
  static const Color darkRed = Color(0xFF9E000E);
  static const Color trustBlue = Color(0xFF1565C0);
  
  // Background Gradient Colors
  static const Color backgroundDark1 = Color(0xFF1A0000);
  static const Color backgroundDark2 = Color(0xFF2D0000);
  
  // Neutrals
  static const Color white = Colors.white;
  static const Color charcoal = Color(0xFF2B2B2B);
  static const Color lightGray = Color(0xFFF7F7F7);
  
  // Gradients
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundDark1, backgroundDark2],
  );
}

class AppTextStyles {
  // Headlines: Georgia
  static TextStyle headlineLarge = GoogleFonts.getFont(
    'Georgia',
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );
  
  static TextStyle headlineMedium = GoogleFonts.getFont(
    'Georgia',
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );

  static TextStyle headlineSmall = GoogleFonts.getFont(
    'Georgia',
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.white,
  );

  // Body: Roboto
  static TextStyle bodyLarge = GoogleFonts.roboto(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.white,
  );
  
  static TextStyle bodyMedium = GoogleFonts.roboto(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.white,
  );
}
