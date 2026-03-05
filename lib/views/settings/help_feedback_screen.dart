import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Help & Feedback Screen - Placeholder for Alpha
class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        title: Text('Help & Feedback', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // FAQ Section
          Text('Frequently Asked Questions', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
          const SizedBox(height: 16),
          _buildFAQItem('How do I log a workout?', 'Navigate to the Journal tab and tap the "+" button to add a new workout entry.'),
          _buildFAQItem('Can I track my runs with GPS?', 'Yes! Go to the Run tab and tap "Start Run" to begin GPS tracking.'),
          _buildFAQItem('How do I purchase a program?', 'Browse available programs in the Marketplace tab and follow the checkout process.'),
          const SizedBox(height: 32),

          // Contact Section
          Text('Contact Support', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
          const SizedBox(height: 16),
          _buildContactCard(icon: Icons.email_outlined, title: 'Email Support', subtitle: 'support@getright.com'),
          _buildContactCard(icon: Icons.chat_bubble_outline, title: 'Live Chat', subtitle: 'Coming soon'),
          const SizedBox(height: 32),

          // Feedback Section
          Text('Send Feedback', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryGray, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('We\'d love to hear from you!', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                const SizedBox(height: 8),
                Text('Email us at feedback@getright.com', style: AppTextStyles.bodySmall.copyWith(color: AppColors.accent)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
          const SizedBox(height: 8),
          Text(answer, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
        ],
      ),
    );
  }

  Widget _buildContactCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
