import 'package:flutter/material.dart';
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
        title: Text('Purchase Details', style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: Icon(Icons.arrow_back_ios_new, color: AppColors.accent),
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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.8), AppColors.accentVariant]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.fitness_center, color: AppColors.onAccent, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              programData['title'] ?? '',
                              style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('by ${programData['trainer'] ?? ''}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(Icons.calendar_today, 'Start Date', _formatDate(programData['startDate'])),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.flag, 'End Date', _formatDate(programData['endDate'])),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.schedule, 'Duration', programData['duration'] ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Price Breakdown
            Text(
              'Price Breakdown',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  _buildPriceRow('Program Fee', _subtotal),
                  const SizedBox(height: 12),
                  _buildPriceRow('Tax (10%)', _tax),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${_total.toStringAsFixed(2)}',
                        style: AppTextStyles.headlineSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
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
            _buildPaymentOption('card', 'Credit / Debit Card', Icons.credit_card, 'Visa, MasterCard, Amex'),
            const SizedBox(height: 12),
            _buildPaymentOption('paypal', 'PayPal', Icons.account_balance_wallet, 'Fast & secure payment'),
            const SizedBox(height: 12),
            _buildPaymentOption('google_pay', 'Google Pay', Icons.payment, 'Quick checkout'),
            const SizedBox(height: 12),
            _buildPaymentOption('apple_pay', 'Apple Pay', Icons.apple, 'Secure payment'),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Proceed to Payment', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onAccent)),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryGray),
        const SizedBox(width: 8),
        Text('$label: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
        Text(
          value,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        ),
      ],
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

  Widget _buildPaymentOption(String value, String title, IconData icon, String subtitle) {
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
              child: Icon(icon, color: isSelected ? AppColors.accent : AppColors.primaryGray, size: 24),
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
