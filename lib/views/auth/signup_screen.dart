import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/no_emoji_input_formatter.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Modern signup screen with streamlined UX and premium design
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
  }

  static bool _hasMinLength(String p) => p.length >= 8;

  static bool _hasUpperAndLower(String p) =>
      RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p);

  static bool _hasDigit(String p) => RegExp(r'\d').hasMatch(p);

  static bool _hasSpecialChar(String p) =>
      RegExp(r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?~`€£¥]''').hasMatch(p);

  String? _validateEmail(String? value) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return 'Enter your email';
    if (!s.contains('@')) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    final p = value ?? '';
    if (p.isEmpty) return 'Enter a password';
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
    if (c != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      final p = _passwordController.text;
      final missing = <String>[];
      final emailErr = _validateEmail(_emailController.text);
      if (emailErr != null) missing.add('valid email');
      if (p.isEmpty) {
        missing.add('a password');
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
        'Create account',
        missing.isEmpty
            ? 'Please fix the errors above'
            : 'Required: ${missing.join(', ')}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

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
                      child: Form(
                        key: _formKey,
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
                            validator: _validateEmail,
                            onChanged: (value) => setState(() {}),
                            inputFormatters: kNoEmojiInputFormatters,
                          ),
                          const SizedBox(height: 15),

                          // Password
                          _buildLabelWithAsterisk('Password'),
                          const SizedBox(height: 8),
                          PasswordTextField(
                            controller: _passwordController,
                            labelText: null,
                            hintText: 'Enter your password',
                            validator: _validatePassword,
                            onChanged: (value) => setState(() {}),
                            inputFormatters: kNoEmojiInputFormatters,
                          ),
                          const SizedBox(height: 15),

                          // Confirm Password
                          _buildLabelWithAsterisk('Confirm Password'),
                          const SizedBox(height: 8),
                          PasswordTextField(
                            controller: _confirmPasswordController,
                            labelText: null,
                            hintText: 'Confirm your password',
                            validator: _validateConfirmPassword,
                            onChanged: (value) => setState(() {}),
                            inputFormatters: kNoEmojiInputFormatters,
                          ),
                          const SizedBox(height: 16),

                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primaryGray.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 17, color: AppColors.accent),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Password requirements',
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: AppColors.onBackground,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13.sp,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _buildRequirement(
                                  'At least 8 characters',
                                  _hasMinLength(_passwordController.text),
                                ),
                                _buildRequirement(
                                  'Uppercase and lowercase letters',
                                  _hasUpperAndLower(_passwordController.text),
                                ),
                                _buildRequirement(
                                  'At least one number',
                                  _hasDigit(_passwordController.text),
                                ),
                                _buildRequirement(
                                  'At least one special character',
                                  _hasSpecialChar(_passwordController.text),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 28),

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

  Widget _buildRequirement(String text, bool met) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 16,
            color: met ? AppColors.accent : AppColors.primaryGray.withOpacity(0.45),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                color: met ? AppColors.onBackground.withOpacity(0.85) : AppColors.onBackground.withOpacity(0.55),
                fontSize: 12.sp,
                fontWeight: met ? FontWeight.w600 : FontWeight.w400,
                height: 1.35,
              ),
            ),
          ),
        ],
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
}
