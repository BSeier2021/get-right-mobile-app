import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/app_logo.dart';
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
    _animationController.dispose();
    super.dispose();
  }

  void _login() {
    final authController = Get.find<AuthController>();
    authController.login(email: _emailController.text.trim(), password: _passwordController.text);
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
                    const SizedBox(height: 40),

                    // Logo with modern styling
                    Center(child: const AppLogo(borderRadius: 16, size: 100)),
                    const SizedBox(height: 25),

                    // Welcome text with modern typography
                    Text(
                      'Welcome Back!',
                      style: AppTextStyles.headlineLarge.copyWith(color: AppColors.accentVariant, fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Login to continue your fitness journey',
                      style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.2),
                    ),
                    const SizedBox(height: 25),

                    // Email field
                    CustomTextField(
                      controller: _emailController,
                      labelText: 'Email Address',
                      hintText: 'Enter your email',
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    const SizedBox(height: 20),

                    // Password field
                    PasswordTextField(controller: _passwordController),
                    const SizedBox(height: 5),

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
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: _rememberMe ? AppColors.accent : AppColors.primaryGray.withOpacity(0.5), width: 2),
                                ),
                                child: _rememberMe ? const Icon(Icons.check_rounded, size: 14, color: AppColors.onAccent) : null,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Remember Me',
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),

                        // Forgot password
                        TextButton(
                          onPressed: () => Get.toNamed(AppRoutes.forgotPassword),
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                          child: Text(
                            'Forgot Password?',
                            style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

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
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
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
                        Image.asset('assets/images/google.png'),
                        if (Platform.isIOS || Platform.isMacOS) ...[const SizedBox(width: 12), Image.asset('assets/images/apple.png')],
                        const SizedBox(width: 12),
                        Image.asset('assets/images/facebook.png'),
                      ],
                    ),
                    const SizedBox(height: 120),

                    // Sign up link
                    Center(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Don\'t have an account? ',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.7), fontSize: 15),
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
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 15),
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
