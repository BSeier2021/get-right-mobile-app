import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Change Password screen accessed from Settings
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> with SingleTickerProviderStateMixin {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    Get.snackbar(
      'Update Failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.error,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  Future<void> _handleChangePassword() async {
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (_currentPasswordController.text.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showError('All fields are required');
      return;
    }

    if (newPassword != confirmPassword) {
      _showError('New password and confirmation must match');
      return;
    }

    if (newPassword.length < 8) {
      _showError('Password must be at least 8 characters long');
      return;
    }

    final authController = Get.find<AuthController>();
    final ok = await authController.changePassword(currentPassword: _currentPasswordController.text.trim(), newPassword: newPassword);
    if (!mounted || !ok) return;

    Get.back(result: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Change Password', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.background,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ).paddingAll(8),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Password
                  Text('Current Password', style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  PasswordTextField(controller: _currentPasswordController, labelText: null, hintText: 'Enter your current password'),
                  const SizedBox(height: 20),

                  // New Password
                  Text('New Password', style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  PasswordTextField(controller: _newPasswordController, labelText: null, hintText: 'Enter new password'),
                  const SizedBox(height: 20),

                  // Re-Enter New Password
                  Text('Re–Enter New Password', style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  PasswordTextField(controller: _confirmPasswordController, labelText: null, hintText: 'Re–enter new password'),
                  const SizedBox(height: 24),

                  _buildHints(),
                  const SizedBox(height: 24),

                  GetBuilder<AuthController>(
                    builder: (controller) {
                      return CustomButton(
                        text: 'Update Password',
                        onPressed: _handleChangePassword,
                        isLoading: controller.isLoading,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHints() {
    final hints = ['Use at least 8 characters', 'Include uppercase & lowercase letters', 'Add at least one number', 'Include a special character (!@#\$%)'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.accent.withOpacity(0.07),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(
                'Password Requirements',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...hints.map(
            (hint) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.5), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(hint, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground.withOpacity(0.7))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
