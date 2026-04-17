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
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _animationController;
  late AnimationController _iconAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _iconAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _iconScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(CurvedAnimation(parent: _iconAnimationController, curve: Curves.elasticOut));

    _animationController.forward();
    _iconAnimationController.forward();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final newPass = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (newPass != confirm) {
      Get.snackbar('Reset password', 'Passwords do not match', snackPosition: SnackPosition.BOTTOM);
      return;
    }

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
                      style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Your new password must be different from previously used passwords',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 15, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // New password
                    PasswordTextField(controller: _newPasswordController, labelText: 'New Password', hintText: 'Enter new password'),
                    const SizedBox(height: 20),

                    // Confirm new password
                    PasswordTextField(controller: _confirmPasswordController, labelText: 'Confirm New Password', hintText: 'Re-enter new password'),
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
                          _buildRequirement('At least 8 characters'),
                          _buildRequirement('Contains uppercase and lowercase letters'),
                          _buildRequirement('Contains numbers'),
                          _buildRequirement('Contains special characters'),
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
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryGray.withOpacity(0.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
