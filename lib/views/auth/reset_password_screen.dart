import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Reset Password screen - shown after OTP verification
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _animationController;
  late AnimationController _iconAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _iconScaleAnimation;

  static bool _hasMinLength(String p) => p.length >= 8;

  static bool _hasUpperAndLower(String p) => RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p);

  static bool _hasDigit(String p) => RegExp(r'\d').hasMatch(p);

  /// Typical special symbols accepted by backends (aligned with common password rules).
  static bool _hasSpecialChar(String p) => RegExp(r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?~`€£¥]''').hasMatch(p);

  String? _validateNewPassword(String? value) {
    final p = value ?? '';
    if (p.isEmpty) return 'Enter a new password';
    if (!_hasMinLength(p)) return 'Use at least 8 characters';
    if (!_hasUpperAndLower(p)) {
      return 'Include uppercase and lowercase letters';
    }
    if (!_hasDigit(p)) return 'Include at least one number';
    if (!_hasSpecialChar(p)) return 'Include at least one special character';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final c = value ?? '';
    if (c.isEmpty) return 'Confirm your password';
    if (c != _newPasswordController.text) return 'Passwords do not match';
    return null;
  }

  void _onPasswordFieldsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onPasswordFieldsChanged);
    _confirmPasswordController.addListener(_onPasswordFieldsChanged);
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _iconAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _iconScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _iconAnimationController, curve: Curves.elasticOut));

    _animationController.forward();
    _iconAnimationController.forward();
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordFieldsChanged);
    _confirmPasswordController.removeListener(_onPasswordFieldsChanged);
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      final p = _newPasswordController.text;
      final missing = <String>[];
      if (p.isEmpty) {
        missing.add('enter a new password');
      } else {
        if (!_hasMinLength(p)) missing.add('at least 8 characters');
        if (!_hasUpperAndLower(p)) {
          missing.add('uppercase and lowercase letters');
        }
        if (!_hasDigit(p)) missing.add('a number');
        if (!_hasSpecialChar(p)) missing.add('a special character');
      }
      final confirm = _confirmPasswordController.text;
      if (confirm.isEmpty) {
        missing.add('confirm your password');
      } else if (confirm != p) {
        missing.add('matching passwords');
      }
      Get.snackbar(
        'Reset password',
        missing.isEmpty ? 'Please fix the errors above' : 'Required: ${missing.join(', ')}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final newPass = _newPasswordController.text.trim();
    final authController = Get.find<AuthController>();
    await authController.resetPassword(newPassword: newPass);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
            ),
            child: const Icon(Icons.chevron_left, size: 25),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24),

                      // Icon
                      ScaleTransition(
                        scale: _iconScaleAnimation,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [AppColors.surface, AppColors.surface.withOpacity(0.8)]),
                            border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1.5),
                            boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.2), blurRadius: 30, spreadRadius: 5)],
                          ),
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)]),
                              ),
                              child: const Icon(Icons.lock_reset_rounded, size: 30, color: AppColors.onAccent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Title
                      Text(
                        'Create New Password',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: AppColors.onBackground,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Create a strong new password for your account',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 15, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 48),

                      // New password
                      PasswordTextField(
                        controller: _newPasswordController,
                        labelText: 'New Password',
                        hintText: 'Enter new password',
                        validator: _validateNewPassword,
                      ),
                      const SizedBox(height: 20),

                      // Confirm new password
                      PasswordTextField(
                        controller: _confirmPasswordController,
                        labelText: 'Confirm New Password',
                        hintText: 'Re-enter new password',
                        validator: _validateConfirmPassword,
                      ),
                      const SizedBox(height: 32),

                      // Password requirements hint
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
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
                            _buildRequirement('At least 8 characters', _hasMinLength(_newPasswordController.text)),
                            _buildRequirement('Contains uppercase and lowercase letters', _hasUpperAndLower(_newPasswordController.text)),
                            _buildRequirement('Contains numbers', _hasDigit(_newPasswordController.text)),
                            _buildRequirement('Contains special characters', _hasSpecialChar(_newPasswordController.text)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Reset button
                      GetBuilder<AuthController>(
                        builder: (controller) {
                          return CustomButton(
                            text: 'Reset Password',
                            onPressed: _resetPassword,
                            isLoading: controller.isLoading,
                            icon: const Icon(Icons.check_circle_outline_rounded),
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle_rounded : Icons.circle_outlined, size: 18, color: met ? AppColors.accent : AppColors.primaryGray.withOpacity(0.45)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: met ? AppColors.onBackground.withOpacity(0.85) : AppColors.onBackground.withOpacity(0.55),
                fontSize: 13,
                fontWeight: met ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
