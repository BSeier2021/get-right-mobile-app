import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Modern OTP verification screen with enhanced UX and timer
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _remainingSeconds = AppConstants.otpResendTimeSeconds;
  Timer? _timer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _animationController.forward();
    _startTimer();
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var n in _focusNodes) {
      n.dispose();
    }
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  static const String _flowForgotPassword = 'forgot_password';

  void _resendOTP() {
    if (_remainingSeconds > 0) return;
    for (final controller in _controllers) {
      controller.clear();
    }
    FocusScope.of(context).requestFocus(_focusNodes.first);
    final args = Get.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String?;
    final forgot = args?['flow'] == _flowForgotPassword;
    final authController = Get.find<AuthController>();
    authController.resendOTP(email: email, forgotPasswordFlow: forgot);
    _timer?.cancel();
    setState(() => _remainingSeconds = AppConstants.otpResendTimeSeconds);
    _startTimer();
  }

  String _otpCode() => _controllers.map((c) => c.text).join();

  void _showOtpExpiredAlert() {
    Get.dialog<void>(
      AlertDialog(
        title: Text('OTP Expired', style: AppTextStyles.titleLarge.copyWith(color: AppColors.black)),
        content: Text(
          'This code has expired. Tap Resend Code to receive a new verification code.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.85)),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: Text('OK', style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOtp() async {
    final args = Get.arguments as Map<String, dynamic>?;
    final forgot = args?['flow'] == _flowForgotPassword;
    final userId = args?['userId'] as String? ?? (forgot ? null : Get.find<AuthController>().pendingSignupUserId);
    final code = _otpCode();

    if (userId == null || userId.isEmpty) {
      Get.snackbar(
        'Verification',
        forgot ? 'Missing user id. Go back and try again.' : 'Missing user id. Go back and sign up again.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (code.length != 6) {
      Get.snackbar('Verification', 'Enter the 6-digit code', snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (_remainingSeconds <= 0) {
      _showOtpExpiredAlert();
      return;
    }

    final authController = Get.find<AuthController>();
    await authController.verifyOTP(userId: userId, otp: code, forgotPasswordFlow: forgot);
  }

  void _handleBack() {
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
      return;
    }

    final args = Get.arguments as Map<String, dynamic>?;
    final forgot = args?['flow'] == _flowForgotPassword;
    final fromSignup = args?['fromSignup'] == true;
    if (forgot) {
      Get.offAllNamed(AppRoutes.forgotPassword);
      return;
    }
    Get.offAllNamed(fromSignup ? AppRoutes.signup : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final email = args?['email'] as String?;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) => _handleBack(),
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        // Back button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: 16.w),
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
                              ),
                              onPressed: _handleBack,
                            ),
                          ),
                        ),
                        SizedBox(height: 20.h),

                        // Verified icon
                        Image.asset('assets/images/otpicon.png', width: 90.w, height: 90.h),
                        SizedBox(height: 25.h),

                        // Title
                        Text(
                          'Verify Your Email',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: AppColors.black,
                            fontSize: 30.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10.h),

                        // Subtitle
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 40.w),
                          child: Text(
                            email != null ? 'We\'ve sent a 6-digit verification code to\n$email' : 'We\'ve sent a 6-digit verification code to',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 14.sp, height: 1.5),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        SizedBox(height: 36.h),

                        // OTP circles
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.w),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(6, (i) => _buildOtpCircle(i))),
                        ),
                        SizedBox(height: 36.h),

                        // Verify & continue
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.w),
                          child: GetBuilder<AuthController>(
                            builder: (auth) {
                              return SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: auth.isLoading ? null : _submitOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accentVariant,
                                    foregroundColor: AppColors.onAccent,
                                    elevation: 0,
                                    disabledBackgroundColor: AppColors.accentVariant.withOpacity(0.6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : Text('Verify & continue', style: AppTextStyles.buttonLarge.copyWith(fontSize: 16.sp)),
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Didn\'t receive the code? ',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.6), fontSize: 14),
                            ),
                            if (_remainingSeconds > 0)
                              Text(
                                'Resend in ${_remainingSeconds}s',
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.black, fontSize: 14, fontWeight: FontWeight.w700),
                              )
                            else
                              GestureDetector(
                                onTap: _resendOTP,
                                child: Text(
                                  'Resend Code',
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Resend section pinned at bottom
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpCircle(int index) {
    return SizedBox(
      width: 48,
      height: 48,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) {
          if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_controllers[index].text.isEmpty && index > 0) {
              _focusNodes[index - 1].requestFocus();
            }
          }
        },
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          autofocus: index == 0,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
          maxLength: 1,
          showCursor: false,
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700, fontSize: 18),
          decoration: InputDecoration(
            counterText: '',
            hintText: '–',
            hintStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.primaryGray.withOpacity(0.5), fontWeight: FontWeight.w400, fontSize: 18),
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50),
              borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.35), width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(50),
              borderSide: BorderSide(color: AppColors.accent.withOpacity(0.6), width: 1.5),
            ),
          ),
          onChanged: (value) {
            if (value.isNotEmpty && index < 5) {
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
}
