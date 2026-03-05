import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/widgets/common/app_logo.dart';
import 'package:get_right/widgets/common/custom_button.dart';

/// Welcome/Onboarding screen - single screen entry point
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _navigateToSignUp() {
    Get.toNamed(AppRoutes.signup);
  }

  void _navigateToSignIn() {
    Get.toNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: const Color(0xFF2C2C2C),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.9], // 80% primary, 20% black
            colors: [
              AppColors.primary, // Primary color at top (80%)
              AppColors.backgroundColor, // Black at bottom (20%)
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // Logo with animation
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        // Logo - Simple, no container decoration
                        const AppLogo(borderRadius: 0),
                        const SizedBox(height: 32),

                        // App Name - "GET RIGHT"
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 4),

                // Action buttons
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Create Account Button (Primary - Green)
                      CustomButton(text: 'Create Account', onPressed: _navigateToSignUp, backgroundColor: AppColors.accent, textColor: AppColors.onAccent),
                      const SizedBox(height: 16),

                      // Log In Button (Outline - Dark Grey)
                      CustomOutlineButton(text: 'Log In', onPressed: _navigateToSignIn, borderColor: Colors.white.withOpacity(0.3), textColor: Colors.white),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
