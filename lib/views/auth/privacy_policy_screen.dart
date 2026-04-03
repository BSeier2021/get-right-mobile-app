import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Privacy Policy screen
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
              border: Border.all(color: AppColors.accent.withOpacity(0.15), width: 1),
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 20),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Privacy Policy',
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
            // ── Introduction (plain, no card) ──
            _buildPlainSection(
              title: 'Introduction',
              content:
                  'Get Right ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
            ),

            // ── Information We Collect (card) ──
            _buildCardSection(
              title: 'Information We Collect',
              intro: 'We collect information that you provide directly to us, including:',
              bullets: [
                'Personal Information: Name, email address, age, gender, and profile picture',
                'Fitness Data: Workout history, fitness goals, preferences, and GPS location data for run tracking',
                'Usage Information: How you interact with our app, features used, and engagement metrics',
                'Device Information: Device type, operating system, unique device identifiers',
              ],
            ),

            // ── How We Use Your Information (card) ──
            _buildCardSection(
              title: 'How We Use Your Information',
              intro: 'We use the information we collect to:',
              bullets: [
                'Provide, maintain, and improve our services',
                'Personalize your fitness experience and recommendations',
                'Process transactions and send related information',
                'Send you technical notices, updates, and support messages',
                'Respond to your comments and questions',
                'Monitor and analyze trends, usage, and activities',
                'Detect, prevent, and address technical issues',
              ],
            ),

            // ── Information Sharing (card) ──
            _buildCardSection(
              title: 'Information Sharing',
              intro: 'We may share your information in the following circumstances:',
              bullets: [
                'With Trainers: When you engage with a trainer, we share relevant profile information',
                'With Service Providers: Third-party vendors who perform services on our behalf',
                'For Legal Purposes: When required by law or to protect rights and safety',
                'Business Transfers: In connection with any merger, sale, or acquisition',
              ],
              footer: 'We do not sell your personal information to third parties.',
            ),

            // ── Data Security (card) ──
            _buildCardSection(
              title: 'Data Security',
              intro:
                  'We implement appropriate technical and organizational measures to protect your personal information. However, no method of transmission over the internet or electronic storage is 100% secure. While we strive to protect your data, we cannot guarantee absolute security.',
            ),

            // ── GPS and Location Data (card) ──
            _buildCardSection(
              title: 'GPS and Location Data',
              intro: 'With your permission, we collect precise location data when you use our run tracking feature. This data is used to:',
              bullets: ['Track your running routes and distance', 'Provide pace and elevation data', 'Generate workout summaries'],
              footer: 'You can disable location services at any time through your device settings.',
            ),

            // ── Health Data (card) ──
            _buildCardSection(
              title: 'Health Data',
              intro:
                  'Get Right may collect and process health-related information, including fitness activities, workout data, and goals. This information is stored securely and used solely for providing fitness services. We comply with applicable health data protection regulations.',
            ),

            // ── Your Rights (card) ──
            _buildCardSection(
              title: 'Your Rights',
              intro: 'Depending on your location, you may have the following rights:',
              bullets: [
                'Access your personal data',
                'Correct inaccurate data',
                'Request deletion of your data',
                'Object to or restrict processing',
                'Data portability',
                'Withdraw consent',
              ],
              footer: 'To exercise these rights, please contact us at privacy@getright.app',
            ),

            // ── Children's Privacy (card) ──
            _buildCardSection(
              title: "Children's Privacy",
              intro:
                  'Our app is not intended for users under 13 years of age. We do not knowingly collect personal information from children under 13. If you become aware that a child has provided us with personal information, please contact us.',
            ),

            // ── Third-Party Services (card) ──
            _buildCardSection(
              title: 'Third-Party Services',
              intro:
                  'Our app may contain links to third-party websites and services. We are not responsible for the privacy practices of these third parties. We encourage you to read their privacy policies.',
            ),

            // ── Data Retention (card) ──
            _buildCardSection(
              title: 'Data Retention',
              intro:
                  'We retain your personal information for as long as necessary to fulfill the purposes outlined in this Privacy Policy, unless a longer retention period is required or permitted by law. When you delete your account, we will delete or anonymize your data.',
            ),

            // ── International Data Transfers (card) ──
            _buildCardSection(
              title: 'International Data Transfers',
              intro:
                  'Your information may be transferred to and processed in countries other than your country of residence. These countries may have data protection laws different from your jurisdiction. We ensure appropriate safeguards are in place.',
            ),

            // ── Changes to This Policy (card) ──
            _buildCardSection(
              title: 'Changes to This Policy',
              intro:
                  'We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last updated" date. You are advised to review this Privacy Policy periodically.',
            ),

            // ── Contact Us (card) ──
            _buildCardSection(
              title: 'Contact Us',
              intro: 'If you have questions about this Privacy Policy, please contact us:',
              bullets: ['Email: privacy@getright.app', 'Website: www.getright.app/privacy'],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Plain section (no card wrapper) ──────────────────────────
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

  // ── Card section ─────────────────────────────────────────────
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
            // Title
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
