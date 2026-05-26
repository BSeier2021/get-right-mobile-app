import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Program Terms & Conditions Screen
class ProgramTermsScreen extends StatefulWidget {
  const ProgramTermsScreen({super.key});

  @override
  State<ProgramTermsScreen> createState() => _ProgramTermsScreenState();
}

class _ProgramTermsScreenState extends State<ProgramTermsScreen> {
  final Map<String, dynamic> programData = Get.arguments ?? {};
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _cancellationAccepted = false;

  bool get _allAccepted => _termsAccepted && _privacyAccepted && _cancellationAccepted;

  void _acceptTerms() {
    if (!_allAccepted) {
      Get.snackbar('Terms Required', 'Please accept all terms and policies to continue', snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    _openPurchaseDetails();
  }

  void _declineTerms() {
    Get.back();
  }

  void _openPurchaseDetails() {
    if (_isBundle) {
      final bundle = programData['bundle'];
      Get.toNamed(AppRoutes.purchaseDetails, arguments: {'isBundle': true, 'bundle': bundle is Map ? Map<String, dynamic>.from(bundle) : programData});
      return;
    }

    final program = programData['program'];
    Get.toNamed(AppRoutes.purchaseDetails, arguments: {'isBundle': false, 'program': program is Map ? Map<String, dynamic>.from(program) : Map<String, dynamic>.from(programData)});
  }

  bool get _isBundle => programData['isBundle'] == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Program Terms', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Please read and accept all terms and policies before enrollment', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Terms & Conditions
            _buildTermsSection('Terms & Conditions', Icons.description, _getTermsAndConditions(), _termsAccepted, (value) => setState(() => _termsAccepted = value ?? false)),
            const SizedBox(height: 20),

            // Privacy Policy
            _buildTermsSection('Privacy Policy', Icons.privacy_tip, _getPrivacyPolicy(), _privacyAccepted, (value) => setState(() => _privacyAccepted = value ?? false)),
            const SizedBox(height: 20),

            // Cancellation Policy
            _buildTermsSection(
              'Cancellation Policy',
              Icons.cancel,
              _getCancellationPolicy(),
              _cancellationAccepted,
              (value) => setState(() => _cancellationAccepted = value ?? false),
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
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _declineTerms,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppColors.primaryGray, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  child: Text('Decline', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onBackground)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _allAccepted ? _acceptTerms : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    disabledBackgroundColor: AppColors.primaryGray,
                  ),
                  child: Text('Accept', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, IconData icon, String content, bool isAccepted, Function(bool?) onChanged) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAccepted ? AppColors.accent.withOpacity(0.5) : AppColors.primaryGray.withOpacity(0.3), width: isAccepted ? 2 : 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isAccepted ? AppColors.accent.withOpacity(0.1) : AppColors.primaryGray.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: isAccepted ? AppColors.accent.withOpacity(0.2) : AppColors.primaryGray.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: isAccepted ? AppColors.accent : AppColors.primaryGray, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(content, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.5)),
            ),
          ),

          // Accept Checkbox
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.primaryGray.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Checkbox(value: isAccepted, onChanged: onChanged, activeColor: AppColors.accent),
                Expanded(
                  child: Text('I have read and accept the $title', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTermsAndConditions() {
    return '''By enrolling in this program, you agree to the following terms and conditions:

1. Program Access: You will have access to all program materials for the duration specified in your enrollment period.

2. Content Usage: All program content is for your personal use only and may not be shared, reproduced, or distributed.

3. Trainer-Client Relationship: Enrollment in this program establishes a professional trainer-client relationship. You agree to follow the trainer's guidance and communicate any health concerns.

4. Health & Safety: You acknowledge that you are physically capable of participating in the program and will consult with a healthcare provider if you have any medical concerns.

5. Payment: Payment for the program is non-refundable except as outlined in the Cancellation Policy.

6. Progress & Results: Individual results may vary. The trainer does not guarantee specific outcomes.

7. Code of Conduct: You agree to maintain respectful communication with your trainer and follow all program guidelines.''';
  }

  String _getPrivacyPolicy() {
    return '''Your privacy is important to us. This Privacy Policy outlines how we collect, use, and protect your personal information:

1. Information Collection: We collect personal information including your name, email, payment details, and fitness data to provide and improve our services.

2. Data Usage: Your information is used to deliver program content, track progress, facilitate trainer communication, and process payments.

3. Data Sharing: We do not sell your personal information. Data is shared only with your enrolled trainer and necessary service providers (payment processors).

4. Data Security: We implement industry-standard security measures to protect your information from unauthorized access.

5. Data Retention: Your program data is retained for the duration of your enrollment and may be kept for historical reference unless you request deletion.

6. Your Rights: You have the right to access, modify, or delete your personal information at any time through your account settings.

7. Cookies: We use cookies to enhance your experience and analyze platform usage.''';
  }

  String _getCancellationPolicy() {
    return '''Please review our cancellation and refund policy carefully:

1. Cancellation Period: You may cancel your enrollment within 7 days of purchase for a full refund, provided you have not accessed more than 25% of the program content.

2. Future Programs: Programs scheduled to start in the future can be cancelled up to 48 hours before the start date for a full refund.

3. Active Programs: Once a program has started and the 7-day period has passed, cancellations will not be eligible for a refund, but you will retain access for the remaining enrollment period.

4. Cancellation Process: To cancel, visit your "My Programs" section and select the cancel option, or contact support@getright.com.

5. Refund Timeline: Approved refunds will be processed within 5-7 business days to the original payment method.

6. Special Circumstances: Medical emergencies or extenuating circumstances will be reviewed on a case-by-case basis.

7. Trainer Cancellation: If a trainer cancels the program, you will receive a full refund or the option to transfer to another program.''';
  }
}
