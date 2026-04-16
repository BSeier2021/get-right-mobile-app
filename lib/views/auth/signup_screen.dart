import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Modern signup screen with streamlined UX and premium design
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (email.isEmpty || !email.contains('@')) {
      Get.snackbar('Invalid email', 'Please enter a valid email address', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (password.length < 8) {
      Get.snackbar('Password', 'Password must be at least 8 characters', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (password != confirm) {
      Get.snackbar('Password', 'Passwords do not match', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    final authController = Get.find<AuthController>();
    final ok = await authController.signup(email: email, password: password);
    if (!ok || !mounted) return;

    Get.toNamed(AppRoutes.otp, arguments: {'email': email, 'fromSignup': true, 'userId': authController.pendingSignupUserId});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: AppColors.background),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Row(
                    //   children: [
                    //     IconButton(
                    //       icon: const Icon(Icons.chevron_left, color: AppColors.accent, size: 35),
                    //       onPressed: () => Get.back(),
                    //     ),
                    //   ],
                    // ),
                    // Title
                    SizedBox(height: 100.h),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'Create Account',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.headlineLarge.copyWith(color: AppColors.black, fontSize: 35.sp, fontWeight: FontWeight.w800, letterSpacing: -1),
                            ),
                          ),
                          SizedBox(height: 5.h),
                          Center(
                            child: Text(
                              textAlign: TextAlign.center,
                              'Sign up to start your fitness journey.',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 13.sp, fontWeight: FontWeight.w400, height: 1.4),
                            ),
                          ),
                          SizedBox(height: 30.h),

                          // Email
                          _buildLabelWithAsterisk('Email'),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _emailController,
                            labelText: null,
                            hintText: 'Enter your email address',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(Icons.email_outlined),
                            onChanged: (value) => setState(() {}),
                          ),
                          const SizedBox(height: 15),

                          // Password
                          _buildLabelWithAsterisk('Password'),
                          const SizedBox(height: 8),
                          PasswordTextField(controller: _passwordController, labelText: null, hintText: 'Enter your password', onChanged: (value) => setState(() {})),
                          const SizedBox(height: 15),

                          // Confirm Password
                          _buildLabelWithAsterisk('Confirm Password'),
                          const SizedBox(height: 8),
                          PasswordTextField(controller: _confirmPasswordController, labelText: null, hintText: 'Confirm your password', onChanged: (value) => setState(() {})),
                          const SizedBox(height: 20),

                          // Instructions
                          Text(
                            'Password must be at least 8 characters long and include uppercase and lowercase letters.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontSize: 13.sp, fontWeight: FontWeight.w400, height: 1.4),
                          ),

                          const SizedBox(height: 32),

                          // Create Account button
                          GetBuilder<AuthController>(
                            builder: (controller) {
                              return CustomButton(
                                text: 'Create Account',
                                onPressed: _signup,
                                isLoading: controller.isLoading,
                                backgroundColor: AppColors.accent,
                                textColor: Colors.white,
                              );
                            },
                          ),
                          SizedBox(height: 20.h),
                          Center(
                            child: Text(
                              textAlign: TextAlign.center,
                              'After creating your account, check your email (including spam folder) for verification.',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontSize: 13.sp, fontWeight: FontWeight.w400, height: 1.4),
                            ),
                          ).paddingSymmetric(horizontal: 24.w),
                          const SizedBox(height: 10),

                          // Divider with "or"
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppColors.primaryGray.withOpacity(0.3)])),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OR',
                                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.black, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryGray.withOpacity(0.3), Colors.transparent])),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Social signup buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset('assets/images/google.png', width: 60.w),
                              if (Platform.isIOS || Platform.isMacOS) ...[const SizedBox(width: 12), Image.asset('assets/images/apple.png', width: 60.w)],
                              const SizedBox(width: 12),
                              Image.asset('assets/images/facebook.png', width: 60.w),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Login link
                          Center(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.black, fontSize: 15.sp),
                                ).paddingOnly(top: 4),
                                TextButton(
                                  onPressed: () => Get.toNamed(AppRoutes.login),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 0),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Log In',
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 15.sp),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelWithAsterisk(String label) {
    return RichText(
      text: TextSpan(
        text: label,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 14.sp, fontWeight: FontWeight.w500),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({required IconData icon, required String label, required VoidCallback onPressed, bool isFullWidth = false}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppColors.onBackground),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
