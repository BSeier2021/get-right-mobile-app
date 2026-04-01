import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_button.dart';

/// Modern OTP verification screen with enhanced UX and timer
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with TickerProviderStateMixin {
  final List<TextEditingController> _otpControllers = List.generate(AppConstants.otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(AppConstants.otpLength, (_) => FocusNode());

  int _remainingSeconds = AppConstants.otpResendTimeSeconds;
  Timer? _timer;

  late AnimationController _animationController;
  late AnimationController _shakeController;
  late Animation<double> _fadeAnimation;
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startTimer();
  }

  void _setupAnimations() {
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));

    _animationController.forward();
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    _animationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  // void _verifyOTP() {
  //   final otp = _otpControllers.map((c) => c.text).join();
  //   final authController = Get.find<AuthController>();
  //   authController.verifyOTP(otp);

  //   // Check if this is from signup flow
  //   final args = Get.arguments as Map<String, dynamic>?;
  //   final fromSignup = args?['fromSignup'] ?? false;

  //   if (fromSignup) {
  //     // Navigate to Profile Setup after OTP verification from signup
  //     Get.offAllNamed(AppRoutes.profileSetup);
  //   } else {
  //     // Navigate to reset password or login for other flows
  //   }
  // }

  void _resendOTP() {
    if (_remainingSeconds > 0) return;

    final authController = Get.find<AuthController>();
    authController.resendOTP();

    setState(() {
      _remainingSeconds = AppConstants.otpResendTimeSeconds;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    // Get email from arguments if passed
    final args = Get.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,

      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(center: Alignment.topCenter, radius: 1.0, colors: [AppColors.accent.withOpacity(0.05), AppColors.background]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
                          ),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ).paddingOnly(left: 10.w),
                    const SizedBox(height: 24),

                    // Icon with animation
                    Image.asset('assets/images/otpicon.png', width: 100.w, height: 100.h),

                    const SizedBox(height: 40),

                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          Text(
                            'Verify Your Email',
                            style: AppTextStyles.headlineLarge.copyWith(color: AppColors.black, fontSize: 35.sp, fontWeight: FontWeight.w600, letterSpacing: -1),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 10),

                          // Description
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              email != null
                                  ? 'We\'ve sent a ${AppConstants.otpLength}-digit verification code to\n$email'
                                  : 'We\'ve sent a ${AppConstants.otpLength}-digit verification code to your email.\nPlease enter it below.',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 15.sp, height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 48),

                          // OTP input fields
                          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(6, (index) => _buildOtpCircleField(index))),
                          const SizedBox(height: 48),

                          // Verify button
                          GetBuilder<AuthController>(
                            builder: (controller) {
                              return CustomButton(text: 'Verify Code', onPressed: () => Get.toNamed(AppRoutes.profileSetup));
                            },
                          ),
                          const SizedBox(height: 32),

                          // Timer and resend
                          _buildResendSection(),
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

  /// OTP field styled as an outlined circle with thin gray border, centered thin dash
  Widget _buildOtpCircleField(int index) {
    final bool isFocused = _focusNodes[index].hasFocus;
    final controller = _controllers[index];

    return ClipOval(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: isFocused ? AppColors.primaryGray.withOpacity(0.7) : AppColors.primaryGray.withOpacity(0.35), width: 1.2),
          color: Colors.transparent,
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          focusNode: _focusNodes[index],
          autofocus: index == 0,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          showCursor: false,
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700, fontSize: 18),
          decoration: InputDecoration(
            border: InputBorder.none,
            counterText: '',
            hintText: '-',
            hintStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.primaryGray.withOpacity(0.6), fontWeight: FontWeight.w600, fontSize: 18),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < _focusNodes.length - 1) {
              _focusNodes[index + 1].requestFocus();
            }
            if (value.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
          },
        ),
      ),
    );
  }

  Widget _buildResendSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(color: AppColors.surface.withOpacity(0.5), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, size: 20, color: AppColors.onBackground.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text('Didn\'t receive the code? ', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.7), fontSize: 14)),
          if (_remainingSeconds > 0)
            Text(
              'Resend in ${_remainingSeconds}s',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, fontSize: 14, fontWeight: FontWeight.w600),
            )
          else
            TextButton(
              onPressed: _resendOTP,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(
                'Resend Code',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
