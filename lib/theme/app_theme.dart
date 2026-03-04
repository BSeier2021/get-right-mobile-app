import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Get Right App Theme Configuration
///
/// Updated according to Design & Typography Guidelines (Section 3.0)
/// - Steel Grey primary background
/// - Green accent for buttons, icons, active states
/// - Black for typography, shadows, outlines
/// - Spacious layouts, subtle shadows, clear iconography

class AppTheme {
  AppTheme._(); // Private constructor to prevent instantiation

  /// Light Theme (Primary theme for Get Right)
  static ThemeData get lightTheme {
    return ThemeData(
      // Use Material 3
      useMaterial3: true,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary, // Steel Grey
        onPrimary: AppColors.onPrimary, // White
        secondary: AppColors.secondary, // Black (for typography)
        onSecondary: AppColors.onSecondary, // White
        error: AppColors.error,
        onError: AppColors.onError,
        surface: AppColors.surface, // White for cards
        onSurface: AppColors.onSurface, // Black text
        outline: AppColors.primaryGray, // Gray for outlines
        outlineVariant: AppColors.primaryGrayLight,
      ),

      // Scaffold Background - Steel Grey
      scaffoldBackgroundColor: AppColors.background, // Steel Grey background
      // App Bar Theme - Steel Grey background with Green accent title
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary, // Steel Grey
        foregroundColor: AppColors.onBackground, // Black text/icons
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark, // Dark icons for light background
        titleTextStyle: AppTextStyles.titleLarge.copyWith(color: AppColors.black), // Green accent title
        iconTheme: const IconThemeData(color: AppColors.accent, size: 24), // Green icons
      ),

      // Text Theme - Black text on steel grey backgrounds
      textTheme: TextTheme(
        headlineLarge: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground),
        headlineMedium: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground),
        headlineSmall: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground),
        titleLarge: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground),
        titleMedium: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground),
        titleSmall: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground),
        bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground),
        bodyMedium: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground),
        bodySmall: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground),
        labelLarge: AppTextStyles.labelLarge.copyWith(color: AppColors.onBackground),
        labelMedium: AppTextStyles.labelMedium.copyWith(color: AppColors.onBackground),
        labelSmall: AppTextStyles.labelSmall.copyWith(color: AppColors.onBackground),
      ),

      // Button Themes
      // Primary buttons use Green (accent) for actions
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent, // Green
          foregroundColor: AppColors.onAccent, // White
          textStyle: AppTextStyles.buttonLarge,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2, // Subtle shadow
          shadowColor: AppColors.secondary.withOpacity(0.2), // Black shadow
          minimumSize: const Size(120, 56),
        ),
      ),

      // Outlined buttons use Black (secondary) for outlines
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onBackground, // Black text
          textStyle: AppTextStyles.buttonLarge.copyWith(color: AppColors.onBackground),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          side: const BorderSide(color: AppColors.secondary, width: 2), // Black outline
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(120, 56),
        ),
      ),

      // Text buttons use Green (accent) for actions
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent, // Green
          textStyle: AppTextStyles.buttonMedium.copyWith(color: AppColors.accent),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface, // White background
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGray, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryGray, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 2), // Green focus
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        labelStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
        errorStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
      ),

      // Card Theme - White surface with subtle shadows
      cardTheme: CardThemeData(
        color: AppColors.surface, // White surface
        elevation: 2, // Subtle shadow
        shadowColor: AppColors.secondary.withOpacity(0.1), // Black shadow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide.none, // No border, using shadow instead
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Floating Action Button Theme - Green (accent) for actions
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent, // Green
        foregroundColor: AppColors.onAccent, // White
        elevation: 4, // Subtle shadow
        shape: CircleBorder(),
      ),

      // Bottom Navigation Bar Theme - Steel Grey background, Green for selected
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.primary, // Steel Grey background
        selectedItemColor: AppColors.accent, // Green for selected
        unselectedItemColor: AppColors.primaryGrayDark, // Gray for unselected
        selectedLabelStyle: AppTextStyles.labelMedium,
        unselectedLabelStyle: AppTextStyles.labelMedium,
        type: BottomNavigationBarType.fixed,
        elevation: 4, // Subtle shadow
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      // Chip Theme - Green (accent) for selected
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryGrayLight,
        deleteIconColor: AppColors.onBackground,
        disabledColor: AppColors.primaryGray,
        selectedColor: AppColors.accent, // Green when selected
        secondarySelectedColor: AppColors.accent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.onBackground),
        secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(color: AppColors.onAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface, // White surface
        elevation: 8,
        shadowColor: AppColors.secondary.withOpacity(0.2), // Black shadow
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppTextStyles.titleLarge.copyWith(color: AppColors.black),
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
      ),

      // Divider Theme
      dividerTheme: const DividerThemeData(color: AppColors.primaryGray, thickness: 1, space: 24),

      // Icon Theme - Green icons for navigation, actions, and toggles
      iconTheme: const IconThemeData(
        color: AppColors.accent, // Green icons
        size: 24,
      ),
      // Switch Theme - Green (accent) when selected
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.onAccent; // White
          }
          return AppColors.primaryGray; // Gray
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent; // Green
          }
          return AppColors.primaryGrayDark; // Gray
        }),
      ),

      // Checkbox Theme - Green (accent) when selected
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent; // Green
          }
          return AppColors.surface; // White
        }),
        checkColor: WidgetStateProperty.all(AppColors.onAccent), // White check
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // Radio Theme - Green (accent) when selected
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.accent; // Green
          }
          return AppColors.primaryGrayDark; // Gray
        }),
      ),

      // Progress Indicator Theme - Green (accent) for progress
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent, // Green
        linearTrackColor: AppColors.primaryGrayLight,
        circularTrackColor: AppColors.primaryGrayLight,
      ),

      // Snackbar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark, // Dark surface
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurfaceDark),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),

      // Tab Bar Theme - Green (accent) for selected
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.accent, // Green for selected
        unselectedLabelColor: AppColors.primaryGrayDark, // Gray for unselected
        labelStyle: AppTextStyles.titleSmall,
        unselectedLabelStyle: AppTextStyles.titleSmall,
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: AppColors.accent, width: 3), // Green indicator
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface, // White surface
        elevation: 8,
        shadowColor: AppColors.secondary, // Black shadow
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      ),
    );
  }

  /// System UI Overlay Styles - Light theme (dark icons for light background)
  static const SystemUiOverlayStyle lightSystemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Dark icons for light background
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.primary, // Steel Grey navigation bar
    systemNavigationBarIconBrightness: Brightness.dark, // Dark icons
  );
}
