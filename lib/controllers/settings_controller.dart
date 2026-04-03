import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';

/// Controller for managing settings
class SettingsController extends GetxController {
  // Notifications enabled state
  final RxBool _notificationsEnabled = true.obs;

  // Trainer mode state
  final RxBool _isTrainer = false.obs;

  bool get notificationsEnabled => _notificationsEnabled.value;
  bool get isTrainer => _isTrainer.value;

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  // Load settings from storage (mock - replace with actual storage)
  void _loadSettings() {
    // In production, load from SharedPreferences or API
    // For now using mock data
    _notificationsEnabled.value = true;
    _isTrainer.value = false;
  }

  // Toggle notifications
  void toggleNotifications(bool value) {
    _notificationsEnabled.value = value;
    _saveSettings();

    if (value) {
      Get.snackbar(
        'Notifications Enabled',
        'You will now receive notifications',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } else {
      Get.snackbar(
        'Notifications Disabled',
        'You will not receive notifications',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    }
  }

  // Toggle trainer mode
  void toggleTrainerMode(bool value) async {
    if (value && !_isTrainer.value) {
      // User wants to become a trainer
      final result = await Get.toNamed(AppRoutes.createTrainerProfile);

      if (result == true) {
        // Profile creation successful
        _isTrainer.value = true;
        _saveSettings();

        Get.snackbar(
          'Trainer Profile Created',
          'You are now a trainer on Get Right!',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } else if (!value && _isTrainer.value) {
      // User wants to disable trainer mode
      final confirm = await _showConfirmDialog(
        title: 'Disable Trainer Mode',
        message: 'Are you sure you want to disable trainer mode? Your trainer profile will remain but will be hidden.',
      );

      if (confirm == true) {
        _isTrainer.value = false;
        _saveSettings();

        Get.snackbar(
          'Trainer Mode Disabled',
          'Your trainer profile is now hidden',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    }
  }

  // Delete account
  void deleteAccount() async {
    final confirm = await _showConfirmDialog(
      title: 'Delete Account',
      message: 'Are you sure you want to delete your account? This action cannot be undone. All your data will be permanently deleted.',
      confirmText: 'Delete',
      isDangerous: true,
    );

    if (confirm == true) {
      // Show loading
      Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // Close loading dialog
      Get.back();

      // In production, call API to delete account
      // await authService.deleteAccount();

      // Show success message
      Get.snackbar(
        'Account Deleted',
        'Your account has been permanently deleted',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );

      // Navigate to welcome screen
      Get.offAllNamed(AppRoutes.welcome);
    }
  }

  // Save settings to storage (mock - replace with actual storage)
  void _saveSettings() {
    // In production, save to SharedPreferences or API
    // SharedPreferences.setString('notifications_enabled', _notificationsEnabled.value);
    // SharedPreferences.setString('is_trainer', _isTrainer.value);
  }

  // Show confirmation dialog
  Future<bool?> _showConfirmDialog({required String title, required String message, String confirmText = 'Confirm', bool isDangerous = false}) {
    return Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDangerous ? Colors.red : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  // Logout user
  void logout() async {
    final confirm = await _showConfirmDialog(title: 'Logout', message: 'Are you sure you want to logout?', confirmText: 'Logout');

    if (confirm == true) {
      // In production, call API to logout
      // await authService.logout();

      Get.snackbar('Logged Out', 'You have been logged out successfully', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));

      // Navigate to welcome screen
      Get.offAllNamed(AppRoutes.welcome);
    }
  }
}
