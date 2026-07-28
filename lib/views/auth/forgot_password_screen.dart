import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Forgot password — email step; sends code then opens [OtpScreen] (forgot flow).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();

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
    _animationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  static const String _otpFlowForgot = 'forgot_password';

  Future<void> _sendResetEmail() async {
    final authController = Get.find<AuthController>();
    final ok = await authController.forgotPassword(_emailController.text);
    if (!mounted || !ok) return;

    final userId = authController.forgotPasswordUserId;
    if (userId == null || userId.isEmpty) {
      Get.snackbar('Forgot password', 'Could not start verification. Please try again.', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    Get.toNamed(AppRoutes.otp, arguments: {'flow': _otpFlowForgot, 'email': _emailController.text.trim(), 'userId': userId});
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
                            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18).paddingAll(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    ScaleTransition(
                      scale: _iconScaleAnimation,
                      child: Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.8)]),
                          ),
                          child: const Icon(Icons.email_rounded, size: 40, color: AppColors.onAccent),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    Text(
                      'Forgot Password?',
                      style: AppTextStyles.headlineLarge.copyWith(color: AppColors.onBackground, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Enter your email address and we\'ll send you a code to reset your password',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withValues(alpha: 0.6), fontSize: 15, height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 48),

                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email Address',
                      hintText: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    const SizedBox(height: 32),

                    GetBuilder<AuthController>(
                      builder: (controller) {
                        return CustomButton(text: 'Send Reset Code', onPressed: _sendResetEmail, isLoading: controller.isLoading);
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
}
