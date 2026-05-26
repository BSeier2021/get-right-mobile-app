import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';

/// Payment Form Screen
class PaymentFormScreen extends StatefulWidget {
  const PaymentFormScreen({super.key});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final Map<String, dynamic> paymentData = Get.arguments ?? {};
  final StorageService _storageService = Get.find<StorageService>();

  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  bool _isProcessing = false;

  String _enrolledItemTitle() {
    if (paymentData['isBundle'] == true) {
      final bundle = paymentData['bundle'];
      if (bundle is Map) {
        final title = bundle['title']?.toString().trim();
        if (title != null && title.isNotEmpty) return title;
      }
      return paymentData['title']?.toString().trim() ?? 'Bundle';
    }
    final program = paymentData['program'];
    if (program is Map) {
      final title = program['title']?.toString().trim();
      if (title != null && title.isNotEmpty) return title;
    }
    return paymentData['title']?.toString().trim() ?? 'Program';
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    setState(() {
      _isProcessing = true;
    });

    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));

    // Check if this is a subscription payment
    final isSubscription = paymentData['type'] == 'subscription';

    if (isSubscription) {
      // Unlock premium features immediately
      final subscriptionType = paymentData['subscriptionType'] ?? 'yearly'; // monthly, quarterly, yearly
      final now = DateTime.now();
      DateTime expiryDate;

      // Calculate expiry date based on subscription type
      switch (subscriptionType) {
        case 'monthly':
          expiryDate = DateTime(now.year, now.month + 1, now.day);
          break;
        case 'quarterly':
          expiryDate = DateTime(now.year, now.month + 3, now.day);
          break;
        case 'yearly':
        default:
          expiryDate = DateTime(now.year + 1, now.month, now.day);
          break;
      }

      // Save subscription to storage
      await _storageService.saveSubscription(true, expiryDate: expiryDate, subscriptionType: subscriptionType);

      // Verify subscription was saved
      final subscriptionSaved = _storageService.hasActiveSubscription();
      debugPrint('Subscription saved: $subscriptionSaved');

      // Unlock nutrition tab immediately so it updates when user goes back
      if (Get.isRegistered<NutritionController>()) {
        Get.find<NutritionController>().refreshSubscription();
      }

      setState(() {
        _isProcessing = false;
      });

      // Show success message
      Get.snackbar(
        'Success!',
        'Premium features unlocked!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.accent,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );

      // Navigate back to previous screen
      // Add delay to ensure storage is fully committed and UI can refresh
      await Future.delayed(const Duration(milliseconds: 500));
      Get.back(); // Go back to previous screen
    } else {
      setState(() {
        _isProcessing = false;
      });

      final title = _enrolledItemTitle();
      Get.offNamed(AppRoutes.myPrograms, arguments: {'enrolled': true, 'program': paymentData});

      Future.delayed(const Duration(milliseconds: 500), () {
        Get.snackbar(
          'Success!',
          'You have been successfully enrolled in $title',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppColors.completed,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
          icon: const Icon(Icons.check_circle, color: Colors.white),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = paymentData['total'] ?? 0.0;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          centerTitle: true,
          title: Text(
            'Payment',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
            ),
            onPressed: () => Get.back(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FFE9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8EFE0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Amount', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark)),
                    const SizedBox(height: 4),
                    Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Featured Workouts',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),

              // Card Number
              Text(
                'Card Number',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              CustomTextField(
                controller: _cardNumberController,
                hintText: '1234 5678 9012 3456',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(16), _CardNumberFormatter()],
              ),
              const SizedBox(height: 20),

              // Card Holder Name
              Text(
                'Card Holder Name',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              CustomTextField(controller: _cardHolderController, hintText: 'JOHN DOE', keyboardType: TextInputType.name),
              const SizedBox(height: 20),

              // Expiry and CVV
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expiry Date',
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _expiryController,
                          hintText: 'MM/YY',
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4), _ExpiryDateFormatter()],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CVV',
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _cvvController,
                          hintText: '123',
                          keyboardType: TextInputType.number,
                          obscureText: false,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Security Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FFE9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8EFE0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: Color(0xFFFCE7F3), shape: BoxShape.circle),
                      child: const Icon(Icons.verified_user_outlined, color: AppColors.onBackground, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Your payment is secured with 256-bit SSL encryption', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentVariant,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                disabledBackgroundColor: AppColors.primaryGray,
              ),
              child: _isProcessing
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.onAccent))),
                        const SizedBox(width: 12),
                        Text('Processing...', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onAccent)),
                      ],
                    )
                  : Text('Pay Now', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onAccent)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card number formatter to add spaces
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i != text.length - 1) {
        buffer.write(' ');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Expiry date formatter to add slash
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '');
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(text[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
