import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/Local%20Storage/local_storage.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/no_emoji_input_formatter.dart';
import 'package:get_right/widgets/common/custom_button.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Modern login screen with premium design and enhanced UX
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadRememberedCredentials();
  }

  void _loadRememberedCredentials() {
    final ls = Get.isRegistered<LocalStorage>() ? Get.find<LocalStorage>() : Get.put(LocalStorage());
    if (!ls.hasSavedCredentials()) return;
    final savedEmail = ls.getSavedEmail();
    final savedPassword = ls.getSavedPassword();
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _emailController.text = savedEmail;
    }
    if (savedPassword != null && savedPassword.isNotEmpty) {
      _passwordController.text = savedPassword;
    }
    _rememberMe = true;
  }

  void _setupAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || !email.contains('@')) {
      Get.snackbar('Login', 'Please enter a valid email address', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (password.isEmpty) {
      Get.snackbar('Login', 'Please enter your password', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final authController = Get.find<AuthController>();
    final status = await authController.login(email: email, password: password, rememberMe: _rememberMe);
    if (!mounted) return;
    if (status == LoginStatus.accountBlocked) {
      _showAccountBlockedDialog();
    }
  }

  void _showAccountBlockedDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE0B2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.block, color: Color(0xFFE65100), size: 28),
        ),
        title: Text(
          'Account Blocked',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Your account has been blocked by an administrator. You cannot sign in right now. If you believe this is a mistake, open a support ticket and our team will help you.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, height: 1.45),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Close', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.primaryGray)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Get.toNamed(
                AppRoutes.supportTickets,
                arguments: {
                  'email': _emailController.text.trim(),
                  'accountBlocked': true,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            icon: const Icon(Icons.support_agent_outlined, size: 20),
            label: Text('Support Ticket', style: AppTextStyles.buttonMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFFEF),
      body: Container(
        // decoration: BoxDecoration(
        //   gradient: RadialGradient(center: Alignment.topRight, radius: 1.2, colors: [AppColors.accent.withOpacity(0.05), AppColors.background]),
        // ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 140.h),

                    // Logo with modern styling
                    // Center(child: const AppLogo(borderRadius: 16, size: 100)),
                    Center(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            textAlign: TextAlign.center,
                            'Welcome Back!',
                            style: AppTextStyles.headlineLarge.copyWith(
                              color: AppColors.black,
                              fontSize: 40.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1,
                            ),
                          ),

                          const SizedBox(height: 12),
                          Text(
                            'Login to continue your fitness journey',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.onBackground,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: 35.h),
                        ],
                      ),
                    ),

                    // Email field
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email Address',
                      hintText: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                      inputFormatters: kNoEmojiInputFormatters,
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    PasswordTextField(controller: _passwordController),
                    const SizedBox(height: 15),

                    // Remember Me and Forgot Password row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Remember Me checkbox
                        InkWell(
                          onTap: () => setState(() => _rememberMe = !_rememberMe),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _rememberMe ? AppColors.accent : Colors.transparent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _rememberMe ? AppColors.accent : AppColors.primaryGray.withOpacity(0.5), width: 2),
                                ),
                                child: _rememberMe ? const Icon(Icons.check_rounded, size: 14, color: AppColors.onAccent) : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Remember Me',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.onBackground.withOpacity(0.7),
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Forgot password
                        TextButton(
                          onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Forgot Password?',
                                style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontSize: 14.sp, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 2),
                              Container(
                                height: 1.h,
                                width: 120.w, // or use double.infinity for full width underline
                                color: AppColors.accent,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Login button
                    GetBuilder<AuthController>(
                      builder: (controller) {
                        return CustomButton(text: 'Login', onPressed: _login, isLoading: controller.isLoading);
                      },
                    ),
                    const SizedBox(height: 20),

                    // Divider with "OR"
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
                    const SizedBox(height: 20),

                    // Social login buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/google.png', width: 60.w),
                        if (Platform.isIOS || Platform.isMacOS) ...[const SizedBox(width: 12), Image.asset('assets/images/apple.png', width: 60.w)],
                        // const SizedBox(width: 12),
                        // Image.asset('assets/images/facebook.png', width: 60.w),
                      ],
                    ),
                    SizedBox(height: 100.h),
                    // Sign up link
                    Center(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Don\'t have an account? ',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.7), fontSize: 15.sp),
                          ).paddingOnly(top: 4),
                          TextButton(
                            onPressed: () => Get.toNamed(AppRoutes.signup),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 0),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Sign Up',
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
          ),
        ),
      ),
    );
  }
}
