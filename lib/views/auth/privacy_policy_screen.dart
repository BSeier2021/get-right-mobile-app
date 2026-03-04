import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Privacy Policy screen - legal placeholder
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
              border: Border.all(color: AppColors.accent.withOpacity(0.1), width: 1),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Privacy Policy', style: AppTextStyles.titleLarge.copyWith(color: AppColors.black)),
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
                  Icon(Icons.privacy_tip_outlined, size: 32, color: AppColors.accent),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy Policy',
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

            // Introduction
            _buildSection(
              title: 'Introduction',
              content:
                  'Get Right ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
            ),

            // Content sections
            _buildSection(
              title: '1. Information We Collect',
              content:
                  'We collect information that you provide directly to us, including:\n\n• Personal Information: Name, email address, age, gender, and profile picture\n• Fitness Data: Workout history, fitness goals, preferences, and GPS location data for run tracking\n• Usage Information: How you interact with our app, features used, and engagement metrics\n• Device Information: Device type, operating system, unique device identifiers',
            ),
            _buildSection(
              title: '2. How We Use Your Information',
              content:
                  'We use the information we collect to:\n\n• Provide, maintain, and improve our services\n• Personalize your fitness experience and recommendations\n• Process transactions and send related information\n• Send you technical notices, updates, and support messages\n• Respond to your comments and questions\n• Monitor and analyze trends, usage, and activities\n• Detect, prevent, and address technical issues',
            ),
            _buildSection(
              title: '3. Information Sharing',
              content:
                  'We may share your information in the following circumstances:\n\n• With Trainers: When you engage with a trainer, we share relevant profile information\n• With Service Providers: Third-party vendors who perform services on our behalf\n• For Legal Purposes: When required by law or to protect rights and safety\n• Business Transfers: In connection with any merger, sale, or acquisition\n\nWe do not sell your personal information to third parties.',
            ),
            _buildSection(
              title: '4. Data Security',
              content:
                  'We implement appropriate technical and organizational measures to protect your personal information. However, no method of transmission over the internet or electronic storage is 100% secure. While we strive to protect your data, we cannot guarantee absolute security.',
            ),
            _buildSection(
              title: '5. GPS and Location Data',
              content:
                  'With your permission, we collect precise location data when you use our run tracking feature. This data is used to:\n\n• Track your running routes and distance\n• Provide pace and elevation data\n• Generate workout summaries\n\nYou can disable location services at any time through your device settings.',
            ),
            _buildSection(
              title: '6. Health Data',
              content:
                  'Get Right may collect and process health-related information, including fitness activities, workout data, and goals. This information is stored securely and used solely for providing fitness services. We comply with applicable health data protection regulations.',
            ),
            _buildSection(
              title: '7. Your Rights',
              content:
                  'Depending on your location, you may have the following rights:\n\n• Access your personal data\n• Correct inaccurate data\n• Request deletion of your data\n• Object to or restrict processing\n• Data portability\n• Withdraw consent\n\nTo exercise these rights, please contact us at privacy@getright.app',
            ),
            _buildSection(
              title: '8. Children\'s Privacy',
              content:
                  'Our app is not intended for users under 13 years of age. We do not knowingly collect personal information from children under 13. If you become aware that a child has provided us with personal information, please contact us.',
            ),
            _buildSection(
              title: '9. Third-Party Services',
              content:
                  'Our app may contain links to third-party websites and services. We are not responsible for the privacy practices of these third parties. We encourage you to read their privacy policies.',
            ),
            _buildSection(
              title: '10. Data Retention',
              content:
                  'We retain your personal information for as long as necessary to fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required or permitted by law. When you delete your account, we will delete or anonymize your data.',
            ),
            _buildSection(
              title: '11. International Data Transfers',
              content:
                  'Your information may be transferred to and processed in countries other than your country of residence. These countries may have data protection laws different from your jurisdiction. We ensure appropriate safeguards are in place.',
            ),
            _buildSection(
              title: '12. Changes to This Policy',
              content:
                  'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. You are advised to review this Privacy Policy periodically.',
            ),
            _buildSection(
              title: '13. Contact Us',
              content:
                  'If you have questions about this Privacy Policy, please contact us:\n\nEmail: privacy@getright.app\nWebsite: www.getright.app/privacy\nAddress: [Your Company Address]',
            ),

            const SizedBox(height: 32),

            // Disclaimer
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
                      'This privacy policy is placeholder content. Actual legal policy will be provided by your legal team and must comply with applicable regulations (GDPR, CCPA, etc.).',
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
