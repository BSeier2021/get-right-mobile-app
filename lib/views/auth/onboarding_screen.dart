import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';

/// Next-Level Modern Onboarding Screen 2024/2025
/// Features: Bold visuals, smooth animations, immersive design
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Modern color palette
  static const Color _greenAccent = Color(0xFF29603C);
  static const Color _greenAccentVariant = Color(0xFF44C071);
  static const Color _bgGrey = Color(0xFFD6D6D6);

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      width: 550,
      imagePath: 'assets/images/dumbles.png',
      title: 'Track Every Rep',
      subtitle: 'Your Fitness Journey',
      description:
          'Log workouts, track progress, and watch yourself grow stronger every single day.',
    ),
    OnboardingPage(
      width: 550,
      imagePath: 'assets/images/sportswear.png',
      title: 'Plan Your Goals',
      subtitle: 'Smart Planning',
      description:
          'Custom programs designed for your goals. Follow expert plans or create your own.',
    ),
    OnboardingPage(
      width: 330,
      imagePath: 'assets/images/run.png',
      title: 'Run & Conquer',
      subtitle: 'GPS Tracking',
      description:
          'Track outdoor runs with real-time pace, distance, and elevation data.',
    ),
    OnboardingPage(
      width: 550,
      imagePath: 'assets/images/girlrun.png',
      title: 'Get Right',
      subtitle: 'Start Today',
      description:
          'Join thousands achieving their fitness goals. Your transformation starts now.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
    _fadeController.reset();
    _scaleController.reset();
    _fadeController.forward();
    _scaleController.forward();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final storage = await StorageService.getInstance();
    final authController = Get.put(AuthController(storage), permanent: true);
    await authController.completeOnboarding();
    Get.offAllNamed(AppRoutes.welcome);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgGrey,
        body: Stack(
          children: [
            // Onboarding background image
            Positioned.fill(
              child: Image.asset(
                'assets/images/Onboarding.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to animated gradient if image fails to load
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _bgGrey,
                          Color.lerp(_bgGrey, _greenAccent, 0.1)!,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Dark overlay for better text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Top bar with skip
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_currentPage < _pages.length - 1)
                          TextButton(
                            onPressed: _completeOnboarding,
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Page view
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemCount: _pages.length,
                      itemBuilder: (context, index) {
                        return _buildPage(_pages[index]);
                      },
                    ),
                  ),

                  // Bottom section
                  _buildBottomSection().paddingOnly(bottom: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Image with modern container
                  ClipRRect(
                    child: Image.asset(
                      page.imagePath,
                      width: page.width,
                      height: 390.h,
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // Subtitle (green text)
          Text(
            _pages[_currentPage].subtitle,
            style: TextStyle(
              color: _greenAccentVariant,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          // Title (white text)
          Text(
            _pages[_currentPage].title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1.0,
            ),
          ),

          const SizedBox(height: 16),

          // Description (white text with opacity)
          Text(
            _pages[_currentPage].description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 16,
              height: 1.5,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ),

          // Bottom navigation row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            crossAxisAlignment: CrossAxisAlignment.center,

            children: [
              // Page indicators
              Row(
                children: List.generate(
                  _pages.length,
                  (index) => _buildPageIndicator(index),
                ),
              ),

              // Next button (circular)
              GestureDetector(
                onTap: _nextPage,

                child: Container(
                  width: 56,

                  height: 56,

                  decoration: BoxDecoration(
                    color: _greenAccent,

                    shape: BoxShape.circle,

                    boxShadow: [
                      BoxShadow(
                        color: _greenAccent.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),

                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = _currentPage == index;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: isActive
            ? _greenAccent
            : const Color.fromARGB(255, 255, 255, 255),
      ),
    );
  }
}

class OnboardingPage {
  final String imagePath;
  final String title;
  final String subtitle;
  final String description;
  final double width;
  OnboardingPage({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.width,
  });
}
