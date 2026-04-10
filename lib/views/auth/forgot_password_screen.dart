import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Modern forgot password screen with two-step flow
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showResetForm = false;

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
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  void _sendResetEmail() {
    final authController = Get.find<AuthController>();
    authController.forgotPassword(_emailController.text.trim());
    setState(() {
      _showResetForm = true;
      _animationController.reset();
      _animationController.forward();
      _iconAnimationController.reset();
      _iconAnimationController.forward();
    });
  }

  void _resetPassword() {
    final authController = Get.find<AuthController>();
    authController.resetPassword(otp: _otpController.text.trim(), newPassword: _newPasswordController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

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
                    SizedBox(height: 24.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => Get.back(),
                          child: Container(
                            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18).paddingAll(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Icon
                    ScaleTransition(
                      scale: _iconScaleAnimation,
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)]),
                          ),
                          child: Icon(_showResetForm ? Icons.lock_reset_rounded : Icons.email_rounded, size: 40, color: AppColors.onAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Title
                    Text(
                      _showResetForm ? 'Reset Password' : 'Forgot Password?',
                      style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        _showResetForm
                            ? 'Enter the verification code sent to your email and create a new password'
                            : 'Enter your email address and we\'ll send you a code to reset your password',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 15, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Forms
                    if (!_showResetForm) ...[
                      // Email field
                      CustomTextField(
                        controller: _emailController,
                        labelText: 'Email Address',
                        hintText: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      const SizedBox(height: 32),

                      // Send button
                      GetBuilder<AuthController>(
                        builder: (controller) {
                          return CustomButton(text: 'Send Reset Code', onPressed: _sendResetEmail, isLoading: controller.isLoading);
                        },
                      ),
                    ] else ...[
                      // OTP field
                      CustomTextField(
                        controller: _otpController,
                        labelText: 'Verification Code',
                        hintText: 'Enter ${AppConstants.otpLength}-digit code',
                        keyboardType: TextInputType.number,
                        maxLength: AppConstants.otpLength,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                      ),
                      const SizedBox(height: 20),

                      // New password
                      PasswordTextField(controller: _newPasswordController, labelText: 'New Password', hintText: 'Enter new password'),
                      const SizedBox(height: 20),

                      // Confirm new password
                      PasswordTextField(controller: _confirmPasswordController, labelText: 'Confirm New Password', hintText: 'Re-enter new password'),
                      const SizedBox(height: 32),

                      // Reset button
                      GetBuilder<AuthController>(
                        builder: (controller) {
                          return CustomButton(text: 'Reset Password', onPressed: _resetPassword, isLoading: controller.isLoading);
                        },
                      ),
                    ],
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
}
