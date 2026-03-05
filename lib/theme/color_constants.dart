import 'package:flutter/material.dart';

class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Brand Colors
  static const Color black = Color(0xFF000000);
  static const Color green = Color(0xFF29603C);
  static const Color steelGrey = Color(0xFF6B7280); // Legacy - Steel Grey (deprecated)
  static const Color white = Color.fromARGB(255, 255, 255, 255);
  static const Color backgroundColor = Color(0xFFFAFFEF);

  // Modern Light Design Colors (Dashboard Style)
  static const Color lightGrey = Color(0xFFD6D6D6); // New primary background
  static const Color cardWhite = Color(0xFFF5F5F5); // Card background
  static const Color textSecondary = Color(0xFF404040); // Secondary text

  // Primary Colors
  // Primary Background: Light Grey - modern, clean foundation
  static const Color primary = lightGrey; // Light grey as primary background
  static const Color primaryVariant = Color(0xFFFAFFEF); // Darker light grey for emphasis
  static const Color onPrimary = black; // Text/icons on light grey

  // Primary Accent: Green - used for buttons, icons, active states, progress indicators
  static const Color accent = green; // Green accent for motion, progress, readiness
  static const Color accentVariant = Color(0xFF214E31); // Darker green variant
  static const Color onAccent = white; // Text/icons on green

  // Secondary Accent: Black - used for typography, shadows, and outlines
  static const Color secondary = black; // Black for typography, shadows, outlines
  static const Color secondaryVariant = Color(0xFF1A1A1A); // Darker black variant
  static const Color onSecondary = white; // Text/icons on black

  // Gray Variants
  static const Color primaryGray = Color(0xFF9CA3AF); // Lighter gray for borders/outlines
  static const Color primaryGrayDark = Color(0xFF6B7280); // Medium gray
  static const Color primaryGrayLight = Color(0xFFD1D5DB); // Light gray for subtle elements

  // Background and Surface
  static const Color background = Color(0xFFFAFFEF); // Light grey background (modern design)
  static const Color onBackground = black; // Black text on light grey
  static const Color surface = Color.fromARGB(255, 248, 255, 233); // Card white surface for cards
  static const Color onSurface = black; // Black text on card surfaces
  static const Color surfaceDark = Color(0xFF4B5563); // Darker surface variant (legacy)
  static const Color onSurfaceDark = white; // White text on dark surfaces
  static const Color surfaceLight = primaryGrayLight; // Light gray for alternate surfaces
  static const Color onSurfaceLight = black; // Black text on light surfaces

  static const Color error = Color(0xFFB00020);
  static const Color onError = Color(0xFFFFFFFF);

  // Status Colors (for workout tracking)
  static const Color completed = Color(0xFF4CAF50); // Green for completed
  static const Color upcoming = Color(0xFFFF9800); // Orange for upcoming
  static const Color missed = Color(0xFFF44336); // Red for missed

  // Neutral Shades (updated for light design)
  static const Color lightGray = cardWhite; // Alias for card white
  static const Color mediumGray = Color(0xFF9CA3AF);
  static const Color darkGray = Color(0xFF4B5563);

  // Transparent variants (for overlays)
  static const Color blackOverlay = Color(0x80000000);
  static const Color whiteOverlay = Color(0x80F4F4F4);
  static const Color steelGreyOverlay = Color(0x806B7280);
}
