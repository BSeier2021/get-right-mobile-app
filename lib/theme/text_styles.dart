import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_right/theme/color_constants.dart';

/// Get Right Typography System
///
/// Updated according to Design & Typography Guidelines (Section 3.3)
/// - Primary Typeface: Clean, geometric sans-serif (Inter/SF Pro)
/// - Headers: Bold or semibold weight
/// - Sub headers & Labels: Medium weight with increased letter spacing
/// - Body Text: Regular weight
/// - Buttons & CTAs: Semibold with clear spacing

class AppTextStyles {
  AppTextStyles._(); // Private constructor to prevent instantiation

  // Font Families
  static const String primaryFont = 'Inter'; // Clean, geometric sans-serif
  static const String secondaryFont = 'DM Sans'; // Clean, geometric sans-serif

  // Heading Styles - Bold or semibold for section titles
  static TextStyle headlineLarge = TextStyle(
    fontFamily: primaryFont,
    fontSize: 32.sp,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: -0.5,
    color: AppColors.secondary, // Black (secondary accent)
  );

  static TextStyle headlineMedium = TextStyle(
    fontFamily: primaryFont,
    fontSize: 28.sp,
    fontWeight: FontWeight.bold,
    height: 1.3,
    letterSpacing: -0.3,
    color: AppColors.secondary, // Black
  );

  static TextStyle headlineSmall = TextStyle(
    fontFamily: primaryFont,
    fontSize: 24.sp,
    fontWeight: FontWeight.bold,
    height: 1.3,
    letterSpacing: 0,
    color: AppColors.secondary, // Black
  );

  // Title Styles - Bold or semibold
  static TextStyle titleLarge = TextStyle(
    fontFamily: secondaryFont,
    fontSize: 22.sp,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
    color: AppColors.black, // Black
  );

  static TextStyle titleMedium = TextStyle(
    fontFamily: primaryFont,
    fontSize: 18.sp,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.15,
    color: AppColors.secondary, // Black
  );

  static TextStyle titleSmall = TextStyle(
    fontFamily: primaryFont,
    fontSize: 16.sp,
    fontWeight: FontWeight.bold,
    height: 1.4,
    letterSpacing: 0.1,
    color: AppColors.secondary, // Black
  );

  // Sub headers & Labels - Medium weight with increased letter spacing
  static TextStyle labelLarge = TextStyle(
    fontFamily: primaryFont,
    fontSize: 16.sp,
    fontWeight: FontWeight.w500, // Medium weight
    height: 1.4,
    letterSpacing: 0.75, // Increased letter spacing
    color: AppColors.secondary, // Black
  );

  static TextStyle labelMedium = TextStyle(
    fontFamily: primaryFont,
    fontSize: 14.sp,
    fontWeight: FontWeight.w500, // Medium weight
    height: 1.4,
    letterSpacing: 0.5, // Increased letter spacing
    color: AppColors.secondary, // Black
  );

  static TextStyle labelSmall = TextStyle(
    fontFamily: primaryFont,
    fontSize: 12.sp,
    fontWeight: FontWeight.w500, // Medium weight
    height: 1.4,
    letterSpacing: 0.5, // Increased letter spacing
    color: AppColors.darkGray,
  );

  // Body Text - Regular weight for instructions, details, and stats
  static TextStyle bodyLarge = TextStyle(
    fontFamily: primaryFont,
    fontSize: 18,
    fontWeight: FontWeight.normal, // Regular weight
    height: 1.5,
    letterSpacing: 0.25,
    color: AppColors.secondary, // Black
  );

  static TextStyle bodyMedium = TextStyle(
    fontFamily: primaryFont,
    fontSize: 16.sp,
    fontWeight: FontWeight.normal, // Regular weight
    height: 1.5,
    letterSpacing: 0.25,
    color: AppColors.secondary, // Black
  );

  static TextStyle bodySmall = TextStyle(
    fontFamily: primaryFont,
    fontSize: 14.sp,
    fontWeight: FontWeight.normal, // Regular weight
    height: 1.5,
    letterSpacing: 0.4,
    color: AppColors.darkGray,
  );

  // Button & CTA Styles - Semibold with clear spacing and strong contrast
  static TextStyle buttonLarge = TextStyle(
    fontFamily: primaryFont,
    fontSize: 16,
    fontWeight: FontWeight.w600, // Semibold
    height: 1.2,
    letterSpacing: 0.75, // Clear spacing
    color: AppColors.onAccent, // White on green (strong contrast)
  );

  static TextStyle buttonMedium = TextStyle(
    fontFamily: primaryFont,
    fontSize: 14.sp,
    fontWeight: FontWeight.w600, // Semibold
    height: 1.2,
    letterSpacing: 0.5, // Clear spacing
    color: AppColors.onAccent, // White on green
  );
  static TextStyle buttonSmall = TextStyle(
    fontFamily: primaryFont,
    fontSize: 12.sp,
    fontWeight: FontWeight.w600, // Semibold
    height: 0.8,
    letterSpacing: 0.5, // Clear spacing
    color: AppColors.onAccent, // White on green
  );

  // Specialized Styles
  static TextStyle caption = TextStyle(
    fontFamily: primaryFont,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.3,
    letterSpacing: 0.4,
    color: AppColors.darkGray,
  );

  static TextStyle overline = TextStyle(
    fontFamily: primaryFont,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.6,
    letterSpacing: 1.5,
    color: AppColors.darkGray,
  );

  // Workout-specific Styles
  static TextStyle statNumber = TextStyle(
    fontFamily: primaryFont,
    fontSize: 36.sp,
    fontWeight: FontWeight.bold,
    height: 1.1,
    letterSpacing: -1,
    color: AppColors.accent, // Green for stats
  );

  static const TextStyle statLabel = TextStyle(
    fontFamily: primaryFont,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.3,
    letterSpacing: 0.5,
    color: AppColors.darkGray,
  );
}
