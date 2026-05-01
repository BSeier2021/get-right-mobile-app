import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/auth_controller.dart';
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
  static final RegExp _mongoIdRe = RegExp(r'^[a-fA-F0-9]{24}$');

  late Map<String, dynamic> _args;
  late Map<String, dynamic> _item;
  late bool _isBundle;
  bool _skipEnrollApi = false;
  bool _enrolling = false;
  String _selectedPaymentMethod = 'card';

  @override
  void initState() {
    super.initState();
    _args = Map<String, dynamic>.from(Get.arguments as Map? ?? {});
    _isBundle = _args['isBundle'] == true;
    _skipEnrollApi = _args['skipEnrollApi'] == true;
    if (_isBundle) {
      _item = Map<String, dynamic>.from(_args['bundle'] as Map? ?? {});
    } else {
      _item = Map<String, dynamic>.from(_args['program'] as Map? ?? _args);
    }
  }

  double get _subtotal {
    if (_isBundle) {
      final bp = _parseDoubleLoose(_item['bundlePrice']);
      if (bp != null && bp > 0) return bp;
    }
    return _parseDoubleLoose(_item['price']) ?? 0.0;
  }

  static double? _parseDoubleLoose(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  /// Week count from API fields that may be num or numeric String (e.g. `"3"`).
  static int _durationWeeksFrom(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final s = value.toString().trim();
    if (s.isEmpty) return 0;
    return int.tryParse(s) ?? double.tryParse(s)?.round() ?? 0;
  }

  double get _tax => _subtotal * 0.1; // 10% tax
  double get _total => _subtotal + _tax;

  Map<String, dynamic>? get _enrollmentMap {
    final e = _item['enrollment'];
    if (e is Map) return Map<String, dynamic>.from(e);
    return null;
  }

  List<Map<String, dynamic>> get _bundlePrograms {
    final raw = _item['programs'];
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  dynamic _effectiveStartDate() {
    final enc = _enrollmentMap;
    if (enc != null && enc['startDate'] != null) return enc['startDate'];
    final list = enc?['enrollments'];
    if (list is List && list.isNotEmpty && list.first is Map) {
      final m = list.first as Map;
      if (m['startDate'] != null) return m['startDate'];
    }
    return _item['startDate'];
  }

  dynamic _effectiveEndDate() {
    final enc = _enrollmentMap;
    if (enc != null && enc['endDate'] != null) return enc['endDate'];
    final list = enc?['enrollments'];
    if (list is List && list.isNotEmpty && list.first is Map) {
      final m = list.first as Map;
      if (m['endDate'] != null) return m['endDate'];
    }
    return _item['endDate'];
  }

  String _trainerDisplayName() {
    final t = _item['trainer'];
    if (t is Map) {
      final name = t['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    if (t is String && t.trim().isNotEmpty && !_mongoIdRe.hasMatch(t.trim())) return t.trim();
    for (final p in _bundlePrograms) {
      final tp = p['trainer'];
      if (tp is Map) {
        final n = tp['name']?.toString().trim();
        if (n != null && n.isNotEmpty) return n;
      }
    }
    return 'Trainer';
  }

  String _durationDisplay() {
    final start = _effectiveStartDate();
    final end = _effectiveEndDate();
    if (start != null && end != null) {
      try {
        final s = DateTime.parse(start.toString());
        final e = DateTime.parse(end.toString());
        final days = e.difference(s).inDays;
        if (days >= 7) return '${(days / 7).round()} weeks';
        if (days > 0) return '$days days';
      } catch (_) {}
    }
    if (_isBundle && _bundlePrograms.isNotEmpty) {
      var sum = 0;
      for (final p in _bundlePrograms) {
        sum += _durationWeeksFrom(p['duration']);
      }
      if (sum > 0) return '$sum weeks (estimated)';
    }
    final d = _item['duration'];
    final weeksTop = _durationWeeksFrom(d);
    if (weeksTop > 0) return '$weeksTop weeks';
    final ds = d?.toString();
    if (ds != null && ds.isNotEmpty) return ds;
    return '—';
  }

  String _dateLabelOrDash(dynamic value) {
    final formatted = _formatDate(value);
    return formatted.isEmpty ? '—' : formatted;
  }

  String? _bundleProgramSubtitle(Map<String, dynamic> p) {
    final dur = p['duration'];
    final diff = p['difficultyLevel']?.toString().trim();
    final parts = <String>[];
    if (dur != null) parts.add('$dur weeks');
    if (diff != null && diff.isNotEmpty) parts.add(diff);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Widget _buildBundleProgramRow(Map<String, dynamic> program, {required bool showTopDivider}) {
    final subtitle = _bundleProgramSubtitle(program);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTopDivider) const Divider(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline, size: 20.sp, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program['title']?.toString() ?? 'Program',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null) Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String? _enrollMongoId() {
    final a = _item['_id']?.toString().trim();
    if (a != null && _mongoIdRe.hasMatch(a)) return a;
    final b = _item['id']?.toString().trim();
    if (b != null && _mongoIdRe.hasMatch(b)) return b;
    return null;
  }

  Future<void> _proceedToPayment() async {
    if (_selectedPaymentMethod.isEmpty) {
      Get.snackbar('Payment Method Required', 'Please select a payment method', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (!_skipEnrollApi) {
      final id = _enrollMongoId();
      if (id == null || !Get.isRegistered<AuthController>()) {
        Get.snackbar('Enroll', 'Cannot enroll: missing valid program id.', snackPosition: SnackPosition.BOTTOM);
        return;
      }
      setState(() => _enrolling = true);
      final enrollment = await Get.find<AuthController>().enrollProgram(programOrBundleId: id, isBundle: _isBundle);
      if (!mounted) return;
      setState(() => _enrolling = false);
      if (enrollment == null) return;
      if (enrollment.isNotEmpty) _item['enrollment'] = enrollment;
    }

    _openPaymentForm();
  }

  /// Pushes after the current frame so the Navigator is not `_debugLocked`
  /// (can happen when navigating right after [setState], e.g. after enroll).
  void _openPaymentForm() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Get.toNamed(
        AppRoutes.paymentForm,
        arguments: {..._item, 'isBundle': _isBundle, 'paymentMethod': _selectedPaymentMethod, 'total': _total, 'subtotal': _subtotal, 'tax': _tax},
      );
    });
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
              width: 45.w,
              height: 35.h,
              decoration: BoxDecoration(color: const Color(0xFFE7F1E7), borderRadius: BorderRadius.circular(6)),
              child: Icon(Icons.chevron_left, color: AppColors.accent, size: 20.sp),
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
                              _item['title']?.toString() ?? (_isBundle ? 'Bundle deal' : 'Program'),
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
                              _trainerDisplayName(),
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
                      Icon(Icons.calendar_today_outlined, size: 16.sp, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text('Start Date: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                      Expanded(
                        child: Text(
                          _dateLabelOrDash(_effectiveStartDate()),
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.event_outlined, size: 16.sp, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text('End Date: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                      Expanded(
                        child: Text(
                          _dateLabelOrDash(_effectiveEndDate()),
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule_outlined, size: 16.sp, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text('Duration: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                      Expanded(
                        child: Text(
                          _durationDisplay(),
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

            if (_isBundle && _bundlePrograms.isNotEmpty) ...[
              Text(
                'Programs included',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (var i = 0; i < _bundlePrograms.length; i++) _buildBundleProgramRow(_bundlePrograms[i], showTopDivider: i > 0)],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Order summary
            Text(
              _isBundle ? 'Bundle summary' : 'Order summary',
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
                  _buildPriceRow(_isBundle ? 'Bundle price' : 'Program fee', _subtotal),
                  const SizedBox(height: 8),
                  _buildPriceRow('Tax (10%)', _tax),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Access ends', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                      Text(
                        _dateLabelOrDash(_effectiveEndDate()),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '\$${_total.toStringAsFixed(2)}',
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
            onPressed: _enrolling ? null : _proceedToPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: _enrolling
                ? SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent))
                : Text('Proceed to Payment', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onAccent)),
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
