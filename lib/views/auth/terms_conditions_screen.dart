import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Terms & Conditions screen - legal placeholder
class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ).paddingAll(8),
        ),
        title: Text('Terms & Conditions', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, size: 32, color: AppColors.accent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terms & Conditions',
                          style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('Last updated: November 2025', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground.withOpacity(0.6))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Content sections
            _buildSection(
              title: '1. Acceptance of Terms',
              content:
                  'By accessing and using Get Right ("the App"), you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.',
            ),
            _buildSection(
              title: '2. Use License',
              content:
                  'Permission is granted to temporarily download one copy of the materials (information or software) on Get Right for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title.',
            ),
            _buildSection(
              title: '3. User Account',
              content:
                  'When you create an account with us, you must provide information that is accurate, complete, and current at all times. Failure to do so constitutes a breach of the Terms, which may result in immediate termination of your account on our Service.',
            ),
            _buildSection(
              title: '4. Privacy',
              content:
                  'Your submission of personal information through the app is governed by our Privacy Policy. Please review our Privacy Policy to understand how we collect, use, and disclose information about you.',
            ),
            _buildSection(
              title: '5. Fitness Content Disclaimer',
              content:
                  'The workout programs, fitness advice, and health-related content provided through Get Right are for informational purposes only. Always consult with a healthcare professional before beginning any fitness program. Get Right is not responsible for any injuries or health issues that may result from using our service.',
            ),
            _buildSection(
              title: '6. Trainer Services',
              content:
                  'Trainers on the platform are independent contractors. Get Right does not guarantee the quality, safety, or legality of trainer services. Users engage with trainers at their own risk.',
            ),
            _buildSection(
              title: '7. Payment Terms',
              content:
                  'Certain features of the App may require payment. You agree to provide current, complete, and accurate purchase and account information for all purchases made via the App. Platform fees and commissions are subject to change with notice.',
            ),
            _buildSection(
              title: '8. Intellectual Property',
              content:
                  'The App and its original content, features, and functionality are and will remain the exclusive property of Get Right and its licensors. The App is protected by copyright, trademark, and other laws.',
            ),
            _buildSection(
              title: '9. Termination',
              content:
                  'We may terminate or suspend your account immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms. Upon termination, your right to use the App will immediately cease.',
            ),
            _buildSection(
              title: '10. Limitation of Liability',
              content:
                  'In no event shall Get Right, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential, or punitive damages, including without limitation, loss of profits, data, use, or other intangible losses.',
            ),
            _buildSection(
              title: '11. Changes to Terms',
              content:
                  'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material, we will try to provide at least 30 days\' notice prior to any new terms taking effect.',
            ),
            _buildSection(
              title: '12. Contact Information',
              content: 'If you have any questions about these Terms, please contact us at:\n\nEmail: legal@getright.app\nWebsite: www.getright.app/contact',
            ),

            const SizedBox(height: 32),

            // Accept button (if needed)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'These terms are placeholder content. Actual legal terms will be provided by your legal team.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground.withOpacity(0.7), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(content, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.8), fontSize: 15, height: 1.6)),
        ],
      ),
    );
  }
}
