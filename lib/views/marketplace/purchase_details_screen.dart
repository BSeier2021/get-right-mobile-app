import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Purchase Details Screen with Payment Gateway Integration
class PurchaseDetailsScreen extends StatefulWidget {
  const PurchaseDetailsScreen({super.key});

  @override
  State<PurchaseDetailsScreen> createState() => _PurchaseDetailsScreenState();
}

class _PurchaseDetailsScreenState extends State<PurchaseDetailsScreen> {
  final Map<String, dynamic> programData = Get.arguments ?? {};
  String _selectedPaymentMethod = 'card';

  double get _subtotal => programData['price']?.toDouble() ?? 0.0;
  double get _tax => _subtotal * 0.1; // 10% tax
  double get _total => _subtotal + _tax;

  void _proceedToPayment() {
    if (_selectedPaymentMethod.isEmpty) {
      Get.snackbar('Payment Method Required', 'Please select a payment method', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    // Navigate to payment form
    Get.toNamed(AppRoutes.paymentForm, arguments: {...programData, 'paymentMethod': _selectedPaymentMethod, 'total': _total, 'subtotal': _subtotal, 'tax': _tax});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        centerTitle: true,
        title: Text(
          'Purchase Detail',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: IconButton(
            onPressed: () => Get.back(),
            icon: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: const Color(0xFFE7F1E7), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 18),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Program Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FFE9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE8EFE0)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              programData['title'] ?? 'Complete Strength Program',
                              style: AppTextStyles.titleMedium.copyWith(color: AppColors.black, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('by', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Trainer mini card row like screenshot
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.accent,
                        child: Image.asset('assets/images/avatar.png', width: 24.w, height: 24.h),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              programData['trainer'] ?? 'Sarah Johnson',
                              style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rate_rounded, size: 16, color: Color(0xFFF6A623)),
                      const SizedBox(width: 8),
                      Text('Start Date: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                      Expanded(
                        child: Text(
                          "3/25/2026",
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rate_rounded, size: 16, color: Color(0xFFF6A623)),
                      const SizedBox(width: 8),
                      Text('End Date: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                      Expanded(
                        child: Text(
                          "4/15/2026",
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star_rate_rounded, size: 16, color: Color(0xFFF6A623)),
                      const SizedBox(width: 8),
                      Text('Duration: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                      Expanded(
                        child: Text(
                          "12 weeks",
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Featured Workouts / Price Summary
            Text(
              'Featured Workouts',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FFE9),

                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8EFE0)),
              ),
              child: Column(
                children: [
                  _buildPriceRow('Program Fee', _subtotal),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('End Date', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                      Text(
                        _formatDate(programData['endDate']),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${_subtotal.toStringAsFixed(2)}',
                        style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Payment Method Selection
            Text(
              'Select Payment Method',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildPaymentOption('card', 'Credit / Debit Card', 'Visa, MasterCard, Amex', asset: 'assets/images/card.png'),
            const SizedBox(height: 12),
            _buildPaymentOption('paypal', 'PayPal', 'Fast & secure payment', asset: 'assets/icons/paypal.png'),
            const SizedBox(height: 12),
            _buildPaymentOption('google_pay', 'Google Pay', 'Quick checkout', asset: 'assets/images/google000.png'),
            const SizedBox(height: 12),
            _buildPaymentOption('apple_pay', 'Apple Pay', 'Secure payment', asset: 'assets/images/apple000.png'),
            const SizedBox(height: 24),

            // Security Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.completed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.completed.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: AppColors.completed, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Secure Payment',
                          style: AppTextStyles.titleSmall.copyWith(color: AppColors.completed, fontWeight: FontWeight.bold),
                        ),
                        Text('Your payment information is encrypted and secure', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                      ],
                    ),
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
            onPressed: _proceedToPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: Text('Proceed to Payment', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onAccent)),
          ),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(String value, String title, String subtitle, {String? asset, IconData? icon}) {
    final isSelected = _selectedPaymentMethod == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.primaryGray.withOpacity(0.3), width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isSelected ? AppColors.accent.withOpacity(0.2) : AppColors.primaryGray.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: asset != null
                  ? Image.asset(asset, width: 24, height: 24, color: null)
                  : Icon(icon ?? Icons.credit_card, color: isSelected ? AppColors.accent : AppColors.primaryGray, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                  ),
                  Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: AppColors.accent, size: 24) else Icon(Icons.circle_outlined, color: AppColors.primaryGray, size: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';

    DateTime dateTime;
    if (date is DateTime) {
      dateTime = date;
    } else if (date is String) {
      dateTime = DateTime.parse(date);
    } else {
      return '';
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
  }
}
