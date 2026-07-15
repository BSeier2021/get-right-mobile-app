import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Privacy Policy screen
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
            _buildHeaderCard(),
            const SizedBox(height: 8),

            _buildPlainSection(
              title: 'Introduction',
              content:
                  'Get Right ("Get Right," "we," "our," or "us") operates the Get Right mobile application and related services (collectively, the "Service"). This Privacy Policy describes how we collect, use, disclose, and safeguard your information when you create an account, use our fitness tools, communicate with trainers, enroll in programs, or otherwise interact with the Service.\n\nBy using the Service, you agree to the collection and use of information in accordance with this Privacy Policy. If you do not agree, please do not use the Service.',
            ),

            _buildCardSection(
              title: 'Information We Collect',
              intro: 'We collect information in the following categories:',
              bullets: [
                'Account and profile information: name, email address, username, password (stored in hashed form), age, gender, profile photo, and preferences you provide during onboarding or in settings.',
                'Fitness and wellness data: workout logs, exercise history, sets and reps, program progress, calendar entries, nutrition summaries, fitness goals, and manually entered health-related information.',
                'Location and activity data: with your permission, precise GPS location, route maps, distance, pace, elevation, and related run-tracking metrics when you use outdoor running features.',
                'Media you upload: progress photos, chat attachments, and other content you choose to share in the app.',
                'Communications: messages sent through in-app chat, support requests, and feedback you submit to us or to trainers through the platform.',
                'Marketplace and enrollment data: programs and bundles you view or enroll in, purchase-related references, and scheduling information linked to your calendar.',
                'Usage and device data: app interactions, feature usage, crash logs, IP address, device type, operating system, app version, language settings, and unique device or session identifiers.',
                'Payment-related information: when purchases are processed through our website or approved payment partners, we may receive transaction status, billing contact details, and purchase history. Payment card details are handled by our payment processors, not stored directly by us in the app.',
              ],
            ),

            _buildCardSection(
              title: 'How We Use Your Information',
              intro: 'We use the information we collect to:',
              bullets: [
                'Create and manage your account and authenticate your access to the Service.',
                'Provide core features such as workout journaling, program scheduling, calendar planning, run tracking, nutrition summaries, and progress tracking.',
                'Enable communication between you and trainers, including sharing workouts, runs, and program content where you choose to do so.',
                'Personalize your experience, including program recommendations and fitness insights based on your activity.',
                'Process enrollments, subscriptions, and purchases made through approved channels.',
                'Send service-related notices, security alerts, and support responses.',
                'Monitor, maintain, and improve the performance, reliability, and security of the Service.',
                'Detect, investigate, and prevent fraud, abuse, unauthorized access, and violations of our Terms & Conditions.',
                'Comply with legal obligations and respond to lawful requests from authorities.',
              ],
            ),

            _buildCardSection(
              title: 'Legal Bases for Processing',
              intro: 'Where applicable under data protection laws, we process personal information based on one or more of the following legal bases:',
              bullets: [
                'Performance of a contract: to provide the Service you request, including account access and program features.',
                'Consent: for optional features such as location tracking, progress photos, marketing communications, or other permissions you grant through your device or in-app settings.',
                'Legitimate interests: to secure the Service, prevent misuse, improve features, and support users, where those interests are not overridden by your rights.',
                'Legal obligation: to comply with applicable laws, regulations, court orders, or regulatory requests.',
              ],
            ),

            _buildCardSection(
              title: 'Information Sharing and Disclosure',
              intro: 'We do not sell your personal information. We may share information in these situations:',
              bullets: [
                'With trainers and program providers: when you enroll in a program, book sessions, or communicate through the platform, we share information necessary for delivery of those services, such as your profile details, workout activity, and messages relevant to your training.',
                'With other users: only when you choose to share content, such as sending a workout or run summary in chat or posting content in social features.',
                'With service providers: trusted vendors that help us operate the Service, including hosting, analytics, customer support, email delivery, payment processing, and security monitoring. These providers may access information only to perform services for us and are contractually required to protect it.',
                'For business transfers: if we are involved in a merger, acquisition, financing, reorganization, or sale of assets, your information may be transferred as part of that transaction, subject to continued protection.',
                'For legal and safety reasons: when we believe disclosure is necessary to comply with law, enforce our terms, protect the rights and safety of users or the public, or respond to legal process.',
              ],
              footer: 'We require third parties to use shared information only for authorized purposes and in accordance with this Privacy Policy.',
            ),

            _buildCardSection(
              title: 'Location Data',
              intro: 'Location data is collected only when you enable location permissions and use features that require it, such as outdoor run tracking. We use location data to:',
              bullets: [
                'Record your route, distance, pace, and related workout metrics.',
                'Display run summaries and historical activity on maps.',
                'Improve the accuracy and reliability of activity tracking features.',
              ],
              footer:
                  'You may disable location access at any time through your device settings. Some run-tracking features may not function without location permission. Background location, if used, will be requested separately and only for features that require it.',
            ),

            _buildCardSection(
              title: 'Health and Fitness Data',
              intro:
                  'Get Right may process health and fitness-related information, including workouts, program completion status, nutrition entries, body progress photos, and goals. This information is used to provide fitness planning, tracking, and coaching features within the Service.\n\nGet Right is not a medical provider. Information in the app is not intended to diagnose, treat, cure, or prevent any disease. You should consult a qualified healthcare professional before starting or changing any exercise or nutrition program.',
            ),

            _buildCardSection(
              title: 'Cookies, Analytics, and Similar Technologies',
              intro:
                  'We and our service providers may use cookies, mobile analytics SDKs, and similar technologies to understand how the Service is used, diagnose technical issues, and improve performance. Depending on your device and settings, you may be able to limit certain analytics or advertising identifiers through your operating system preferences.',
            ),

            _buildCardSection(
              title: 'Data Retention',
              intro:
                  'We retain personal information for as long as reasonably necessary to provide the Service, fulfill the purposes described in this Privacy Policy, comply with legal obligations, resolve disputes, and enforce our agreements.\n\nWhen you delete your account, we will delete or anonymize your personal information within a reasonable period, except where retention is required by law or necessary for legitimate business purposes such as fraud prevention, backup integrity, or dispute resolution.',
            ),

            _buildCardSection(
              title: 'Data Security',
              intro:
                  'We implement administrative, technical, and organizational safeguards designed to protect your information, including access controls, encryption in transit where supported, and monitoring for unauthorized activity. No method of transmission or storage is completely secure, and we cannot guarantee absolute security.',
            ),

            _buildCardSection(
              title: 'International Data Transfers',
              intro:
                  'Your information may be processed in countries other than the country where you live. Those countries may have data protection laws that differ from the laws in your jurisdiction. Where required, we implement appropriate safeguards for cross-border transfers, such as contractual protections with service providers.',
            ),

            _buildCardSection(
              title: 'Your Privacy Rights',
              intro: 'Depending on your location, you may have rights regarding your personal information, including the right to:',
              bullets: [
                'Access the personal information we hold about you.',
                'Request correction of inaccurate or incomplete information.',
                'Request deletion of your personal information, subject to legal exceptions.',
                'Object to or restrict certain processing activities.',
                'Receive a portable copy of information you provided, where applicable.',
                'Withdraw consent where processing is based on consent.',
                'Opt out of certain targeted advertising or profiling, where applicable by law.',
              ],
              footer:
                  'To exercise these rights, contact us at privacy@getright.app. We may need to verify your identity before responding. You may also have the right to lodge a complaint with your local data protection authority.',
            ),

            _buildCardSection(
              title: 'Account Deletion',
              intro:
                  'You may request deletion of your account through in-app settings, where available, or by contacting privacy@getright.app. After account deletion, you may lose access to workout history, program progress, messages, and other stored content. Some information may remain in backups or logs for a limited period as described in our retention practices.',
            ),

            _buildCardSection(
              title: "Children's Privacy",
              intro:
                  'The Service is not intended for children under 13 years of age, or the minimum age required in your jurisdiction. We do not knowingly collect personal information from children. If you believe a child has provided us with personal information, please contact us and we will take appropriate steps to delete it.',
            ),

            _buildCardSection(
              title: 'Third-Party Links and Services',
              intro:
                  'The Service may contain links to third-party websites, payment pages, or services, including our marketplace website. We are not responsible for the privacy practices of third parties. We encourage you to review the privacy policies of any third-party service you use.',
            ),

            _buildCardSection(
              title: 'Changes to This Privacy Policy',
              intro:
                  'We may update this Privacy Policy from time to time. When we make material changes, we will post the updated policy in the app and revise the "Last updated" date above. Your continued use of the Service after the effective date of an updated policy constitutes acceptance of the changes, unless otherwise required by law.',
            ),

            _buildCardSection(
              title: 'Contact Us',
              intro: 'If you have questions, concerns, or requests regarding this Privacy Policy or our privacy practices, contact us at:',
              bullets: [
                'Email: privacy@getright.app',
                'Legal inquiries: legal@getright.app',
                'Website: www.getright.app/privacy',
              ],
            ),

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
            const Icon(Icons.privacy_tip_outlined, size: 32, color: AppColors.accent),
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
