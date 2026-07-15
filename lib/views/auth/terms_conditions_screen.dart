import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Terms & Conditions screen
class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  static const String _lastUpdated = 'July 15, 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.15), width: 1),
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Terms & Conditions',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 8),

            _buildPlainSection(
              title: 'Agreement to Terms',
              content:
                  'These Terms & Conditions ("Terms") govern your access to and use of the Get Right mobile application, website, marketplace, and related services (collectively, the "Service") operated by Get Right ("Get Right," "we," "our," or "us").\n\nBy creating an account, accessing, or using the Service, you agree to be bound by these Terms and our Privacy Policy. If you do not agree, you must not use the Service.',
            ),

            _buildCardSection(
              title: '1. Eligibility',
              intro:
                  'You must be at least 13 years old, or the minimum age required in your jurisdiction, to use the Service. If you are under the age of majority where you live, you may use the Service only with the consent and supervision of a parent or legal guardian who agrees to these Terms on your behalf.\n\nYou represent that the information you provide is accurate and that you have the legal capacity to enter into this agreement.',
            ),

            _buildCardSection(
              title: '2. Account Registration and Security',
              intro: 'When you create an account, you agree to:',
              bullets: [
                'Provide accurate, current, and complete registration information.',
                'Maintain the confidentiality of your login credentials.',
                'Notify us promptly of any unauthorized access to or use of your account.',
                'Accept responsibility for all activity that occurs under your account, except where caused by our failure to maintain reasonable security.',
              ],
              footer: 'We may suspend or terminate accounts that contain false information, are inactive, or violate these Terms.',
            ),

            _buildCardSection(
              title: '3. Description of the Service',
              intro: 'Get Right provides fitness and wellness tools that may include, among other features:',
              bullets: [
                'Workout journaling, exercise tracking, and program scheduling.',
                'Calendar planning, progress photos, and nutrition summaries.',
                'Outdoor run tracking using location services, where enabled.',
                'Communication with trainers and other users through in-app messaging.',
                'Access to training programs, bundles, and marketplace content.',
                'Social and content features such as reels, shared workouts, and activity summaries.',
              ],
              footer: 'We may add, modify, or remove features at any time. Some features may require additional permissions, subscriptions, or purchases.',
            ),

            _buildCardSection(
              title: '4. Health and Fitness Disclaimer',
              intro:
                  'Get Right provides fitness, wellness, and educational content for informational purposes only. The Service is not a substitute for professional medical advice, diagnosis, or treatment.\n\nYou acknowledge that physical exercise involves inherent risks, including injury, illness, or death. You are solely responsible for determining whether any workout, program, nutrition plan, or activity is appropriate for your health and fitness level.',
              bullets: [
                'Consult a physician or qualified healthcare provider before starting any exercise or nutrition program.',
                'Stop exercising immediately and seek medical attention if you experience pain, dizziness, shortness of breath, or other adverse symptoms.',
                'Get Right does not guarantee specific fitness results, weight loss, performance improvements, or health outcomes.',
              ],
            ),

            _buildCardSection(
              title: '5. Trainer and Marketplace Services',
              intro:
                  'Trainers, coaches, and program creators available through Get Right are independent providers unless we expressly state otherwise. Get Right facilitates connections, scheduling, communication, and content delivery but does not control or guarantee the quality, safety, legality, or outcome of third-party services.',
              bullets: [
                'Your relationship with a trainer or program provider may be subject to additional program-specific terms presented at enrollment.',
                'Purchases for certain programs and bundles may be completed through our website or approved payment channels rather than directly inside the mobile app.',
                'Refunds, cancellations, and program-specific policies may vary and will be disclosed at the time of purchase or enrollment where applicable.',
              ],
              footer: 'Any dispute arising from trainer services should first be addressed with the relevant provider, although we may assist with platform-related support requests where appropriate.',
            ),

            _buildCardSection(
              title: '6. User Content and Conduct',
              intro: 'You may submit, upload, or share content through the Service, including messages, photos, workout data, and other materials ("User Content"). You retain ownership of your User Content, but you grant Get Right a worldwide, non-exclusive, royalty-free license to host, store, reproduce, display, and distribute your User Content solely as necessary to operate and improve the Service.',
              bullets: [
                'You are responsible for your User Content and represent that you have all rights necessary to share it.',
                'You must not upload unlawful, harassing, abusive, defamatory, infringing, obscene, or otherwise objectionable content.',
                'You must not impersonate others, spam users, scrape the Service, reverse engineer the app, or attempt to gain unauthorized access to systems or accounts.',
                'You must not use the Service in any manner that violates applicable law or the rights of others.',
              ],
              footer: 'We may remove content or restrict accounts that violate these Terms or create risk for users or the platform.',
            ),

            _buildCardSection(
              title: '7. Privacy',
              intro:
                  'Your use of the Service is also governed by our Privacy Policy, which explains how we collect, use, and share information. By using the Service, you consent to our data practices as described in the Privacy Policy.',
            ),

            _buildCardSection(
              title: '8. Subscriptions, Purchases, and Billing',
              intro: 'Certain features, programs, or memberships may require payment. When you make a purchase, you agree that:',
              bullets: [
                'You will provide current, complete, and accurate billing and account information.',
                'Prices, fees, taxes, and billing intervals may change with notice where required by law.',
                'Payments are processed through approved payment providers, and additional terms from those providers may apply.',
                'Except where required by law or expressly stated in a purchase offer, fees are non-refundable once access has been granted.',
              ],
              footer: 'If you believe a charge was made in error, contact support@getright.com within a reasonable time so we can review the transaction.',
            ),

            _buildCardSection(
              title: '9. Intellectual Property',
              intro:
                  'The Service, including its software, design, branding, text, graphics, logos, videos, program structures, and other materials provided by Get Right, is owned by Get Right or its licensors and is protected by intellectual property laws.\n\nExcept for the limited right to use the Service in accordance with these Terms, no license or ownership rights are transferred to you. You may not copy, modify, distribute, sell, lease, or create derivative works from any part of the Service without our prior written consent.',
            ),

            _buildCardSection(
              title: '10. Prohibited Uses',
              intro: 'You agree not to use the Service to:',
              bullets: [
                'Engage in fraudulent, deceptive, or illegal activity.',
                'Interfere with the security or operation of the Service.',
                'Collect or harvest personal information from other users without authorization.',
                'Upload malware, viruses, or harmful code.',
                'Use automated systems to access the Service in a manner that exceeds reasonable use or violates our policies.',
              ],
            ),

            _buildCardSection(
              title: '11. Suspension and Termination',
              intro:
                  'We may suspend or terminate your access to the Service at any time, with or without notice, if we reasonably believe you have violated these Terms, created legal or security risk, or if we discontinue the Service.\n\nYou may stop using the Service at any time and may request account deletion as described in our Privacy Policy. Upon termination, your right to access the Service ends immediately, but sections that by their nature should survive will remain in effect.',
            ),

            _buildCardSection(
              title: '12. Disclaimers',
              intro:
                  'THE SERVICE IS PROVIDED ON AN "AS IS" AND "AS AVAILABLE" BASIS TO THE MAXIMUM EXTENT PERMITTED BY LAW. GET RIGHT DISCLAIMS ALL WARRANTIES, WHETHER EXPRESS, IMPLIED, OR STATUTORY, INCLUDING WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, AND NON-INFRINGEMENT.\n\nWe do not warrant that the Service will be uninterrupted, error-free, secure, or free of harmful components, or that any content, trainer advice, or program outcome will meet your expectations.',
            ),

            _buildCardSection(
              title: '13. Limitation of Liability',
              intro:
                  'TO THE MAXIMUM EXTENT PERMITTED BY LAW, GET RIGHT AND ITS OFFICERS, DIRECTORS, EMPLOYEES, AFFILIATES, AGENTS, AND LICENSORS WILL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, OR FOR ANY LOSS OF PROFITS, DATA, GOODWILL, OR OTHER INTANGIBLE LOSSES, ARISING OUT OF OR RELATED TO YOUR USE OF OR INABILITY TO USE THE SERVICE.\n\nTO THE MAXIMUM EXTENT PERMITTED BY LAW, OUR TOTAL LIABILITY FOR ANY CLAIM ARISING OUT OF OR RELATING TO THE SERVICE OR THESE TERMS WILL NOT EXCEED THE GREATER OF (A) THE AMOUNT YOU PAID TO GET RIGHT FOR THE SERVICE IN THE TWELVE (12) MONTHS BEFORE THE EVENT GIVING RISE TO THE CLAIM, OR (B) ONE HUNDRED U.S. DOLLARS (USD \$100).\n\nSome jurisdictions do not allow certain limitations of liability, so some of the above limitations may not apply to you.',
            ),

            _buildCardSection(
              title: '14. Indemnification',
              intro:
                  'You agree to defend, indemnify, and hold harmless Get Right and its affiliates, officers, directors, employees, and agents from and against any claims, liabilities, damages, losses, and expenses, including reasonable legal fees, arising out of or related to your use of the Service, your User Content, your violation of these Terms, or your violation of any rights of another person or entity.',
            ),

            _buildCardSection(
              title: '15. Governing Law and Disputes',
              intro:
                  'These Terms are governed by the laws applicable in the jurisdiction where Get Right is established, without regard to conflict-of-law principles, except where mandatory consumer protection laws in your country require otherwise.\n\nBefore filing a formal legal claim, you agree to contact us at legal@getright.app and attempt to resolve the dispute informally. If a dispute cannot be resolved informally, it will be handled in the courts or arbitration forum specified by applicable law and our operating jurisdiction, unless local law grants you the right to bring claims in your home jurisdiction.',
            ),

            _buildCardSection(
              title: '16. Changes to These Terms',
              intro:
                  'We may update these Terms from time to time. When we make material changes, we will post the updated Terms in the app and revise the "Last updated" date above. If required by law, we will provide additional notice. Your continued use of the Service after the effective date of updated Terms constitutes acceptance of the changes.',
            ),

            _buildCardSection(
              title: '17. Contact Information',
              intro: 'If you have questions about these Terms, contact us at:',
              bullets: [
                'Email: legal@getright.app',
                'Support: support@getright.com',
                'Website: www.getright.app/contact',
              ],
            ),

            _buildAcknowledgmentCard(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.accent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.description_outlined, size: 32, color: AppColors.accent),
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
                  Text(
                    'Last updated: $_lastUpdated',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcknowledgmentCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 20, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'By continuing to use Get Right, you acknowledge that you have read, understood, and agree to these Terms & Conditions and our Privacy Policy.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground.withOpacity(0.7), fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlainSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(content, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.75), fontSize: 14.5, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildCardSection({required String title, String? intro, List<String>? bullets, String? footer}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FFE9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (intro != null) ...[
              const SizedBox(height: 14),
              Text(intro, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.75), fontSize: 14, height: 1.55)),
            ],
            if (bullets != null && bullets.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...bullets.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(b, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.75), fontSize: 14, height: 1.55)),
                ),
              ),
            ],
            if (footer != null) ...[
              const SizedBox(height: 4),
              Text(footer, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground.withOpacity(0.75), fontSize: 14, height: 1.55)),
            ],
          ],
        ),
      ),
    );
  }
}
