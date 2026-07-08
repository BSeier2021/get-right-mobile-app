import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
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
      confirmText: 'Continue',
      isDangerous: true,
    );

    if (confirm != true) return;

    final context = Get.context;
    if (context == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const _DeleteAccountPasswordDialog(),
    );
  }

  // Save settings to storage (mock - replace with actual storage)
  void _saveSettings() {
    // In production, save to SharedPreferences or API
    // SharedPreferences.setString('notifications_enabled', _notificationsEnabled.value);
    // SharedPreferences.setString('is_trainer', _isTrainer.value);
  }

  // Show confirmation dialog
  Future<bool?> _showConfirmDialog({required String title, required String message, String confirmText = 'Confirm', bool isDangerous = false}) {
    final context = Get.context;
    if (context == null || !context.mounted) return Future.value(false);

    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
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

class _DeleteAccountPasswordDialog extends StatefulWidget {
  const _DeleteAccountPasswordDialog();

  @override
  State<_DeleteAccountPasswordDialog> createState() => _DeleteAccountPasswordDialogState();
}

class _DeleteAccountPasswordDialogState extends State<_DeleteAccountPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _isDeleting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_isDeleting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop();
  }

  Future<void> _submit() async {
    if (_isDeleting) return;

    final password = _passwordController.text.trim();
    if (password.isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => _isDeleting = true);

    final ok = await Get.find<AuthController>().deleteAccount(password: password);

    if (!mounted) return;

    if (ok) return;

    setState(() => _isDeleting = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: Text(_isDeleting ? 'Deleting Account' : 'Confirm Password'),
        content: _isDeleting
            ? const SizedBox(
                height: 72,
                child: Center(child: CircularProgressIndicator()),
              )
            : TextField(
                controller: _passwordController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                  hintText: 'Enter your current password',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submit(),
              ),
        actions: _isDeleting
            ? null
            : [
                TextButton(onPressed: _cancel, child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  child: const Text('Delete Account'),
                ),
              ],
      ),
    );
  }
}
