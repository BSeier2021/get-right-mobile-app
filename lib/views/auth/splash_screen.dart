import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/app_logo.dart';

/// Modern splash screen with elegant animations and premium feel
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _shimmerController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;

  /// Guards against navigating twice if `_initializeApp` resumes after dispose
  /// (avoids `Navigator !_debugLocked` assertion when navigation is already in flight).
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    // Fade animation
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    // Scale animation
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut));

    // Shimmer animation for premium effect
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _shimmerAnimation = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut));

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    _shimmerController.repeat();
  }

  Future<void> _initializeApp() async {
    // Minimum splash duration (animations)
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    final auth = Get.find<AuthController>();
    final route = await auth.tryAutoLoginAndRouteFromSplash() ?? AppRoutes.onboarding;
    if (!mounted) return;

    // Defer to after the current frame so we never push a new route while
    // the framework is still mid-build / mid-transition.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_hasNavigated) return;
      _hasNavigated = true;
      if (route == AppRoutes.otp) {
        Get.offAllNamed(route, arguments: auth.autoLoginOtpArgs);
      } else {
        Get.offAllNamed(route);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            // Splash screen background image
            Positioned.fill(
              child: Image.asset(
                'assets/images/Splash screen.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to gradient if image fails to load
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [const Color.fromARGB(0, 214, 214, 214), const Color.fromARGB(0, 192, 192, 192).withOpacity(0.3)],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Dark overlay for better text readability
            // Positioned.fill(
            //   child: Container(
            //     decoration: BoxDecoration(
            //       gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.5)]),
            //     ),
            //   ),
            // ),

            // Animated gradient circles for depth
            _buildAnimatedCircle(alignment: Alignment.topLeft, size: 200, offset: const Offset(-50, -50)),
            _buildAnimatedCircle(alignment: Alignment.bottomRight, size: 250, offset: const Offset(50, 100)),

            // Main content
            SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo with scale animation and shimmer

                      // Modern loading indicator
                      _buildModernLoadingIndicator(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCircle({required Alignment alignment, required double size, required Offset offset}) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Transform.translate(
          offset: offset,
          child: AnimatedBuilder(
            animation: _scaleController,
            builder: (context, child) {
              return Container(
                width: size * _scaleAnimation.value,
                height: size * _scaleAnimation.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AppColors.accent.withOpacity(0.08), AppColors.accent.withOpacity(0.02), Colors.transparent]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildModernLoadingIndicator() {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent.withOpacity(0.3)))),
          // Inner ring
          SizedBox(width: 35, height: 35, child: CircularProgressIndicator(strokeWidth: 3, valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent))),
        ],
      ),
    );
  }
}
