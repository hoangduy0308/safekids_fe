import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// SafeKids Typography System - "Purple Guardian" Design
/// Inspired by SafeZ - Clean, Modern, Friendly
/// Using Poppins from Google Fonts (rounded, friendly like SF Rounded)
class AppTypography {
  // Font Family - Poppins (rounded, modern, friendly)
  static String get fontFamily => GoogleFonts.poppins().fontFamily ?? 'Poppins';
  
  // Helper method to apply Poppins font to TextStyle
  static TextStyle _poppins(TextStyle style) {
    return GoogleFonts.poppins(textStyle: style);
  }
  
  // Display styles (large headings, hero text) - Bold, tight spacing
  static TextStyle get display1 => _poppins(const TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.5,
    height: 1.1,
    color: AppColors.textPrimary,
  ));
  
  static TextStyle get display2 => _poppins(const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.2,
    color: AppColors.textPrimary,
  ));
  
  // Heading styles - SafeZ style bold headings
  static TextStyle get h1 => _poppins(const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700, // Bolder like SafeZ
    letterSpacing: -0.5,
    height: 1.2,
    color: AppColors.textPrimary,
  ));
  
  static TextStyle get h2 => _poppins(const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
    color: AppColors.textPrimary,
  ));
  
  static TextStyle get h3 => _poppins(const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700, // Bold for section headers
    letterSpacing: -0.2,
    height: 1.3,
    color: AppColors.textPrimary,
  ));
  
  static TextStyle get h4 => _poppins(const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.3,
    color: AppColors.textPrimary,
  ));
  
  // Body styles - Clean, readable
  static TextStyle get bodyLarge => _poppins(const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  ));
  
  static TextStyle get body => _poppins(const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  ));
  
  static TextStyle get bodySmall => _poppins(const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  ));
  
  // Label/Caption styles
  static TextStyle get label => _poppins(const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600, // Semi-bold for labels
    height: 1.3,
    letterSpacing: 0.0,
    color: AppColors.textPrimary,
  ));
  
  static TextStyle get caption => _poppins(const TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0.0,
    color: AppColors.textSecondary,
  ));
  
  static TextStyle get captionSmall => _poppins(const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: AppColors.textTertiary,
  ));
  
  // Button styles - Bold and clear
  static TextStyle get buttonLarge => _poppins(const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    height: 1.2,
  ));
  
  static TextStyle get button => _poppins(const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    height: 1.2,
  ));
  
  static TextStyle get buttonSmall => _poppins(const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.0,
    height: 1.2,
  ));
  
  // Special styles
  static TextStyle get overline => _poppins(const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    height: 1.3,
    color: AppColors.textTertiary,
  ));
  
  static TextStyle get subtitle => _poppins(const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.textSecondary,
  ));
}
