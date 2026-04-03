import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Help & Feedback Screen
class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  int _expandedFAQ = -1; // index of currently expanded FAQ, -1 = none

  final List<Map<String, String>> _faqs = [
    {'q': 'How Do I Log A Workout?', 'a': 'Navigate to the Journal tab and tap the "+" button to add a new workout entry.'},
    {'q': 'Can I Track My Runs With GPS?', 'a': 'Yes! Go to the Run tab and tap "Start Run" to begin GPS tracking.'},
    {'q': 'How Do I Purchase A Program?', 'a': 'Browse available programs in the Marketplace tab and follow the checkout process.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text('Help & Feedback', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        children: [
          // ── FAQ Section ──────────────────────────────────────────────
          Text('Frequently Asked Questions', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 14.h),
          ...List.generate(_faqs.length, (i) => _buildFAQItem(i, _faqs[i]['q']!, _faqs[i]['a']!)),

          SizedBox(height: 28.h),

          // ── Contact Support ──────────────────────────────────────────
          Text('Contact Support', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 14.h),
          _buildContactCard(
            icon: Icons.email_outlined,
            iconBg: const Color(0xFFF5E6C8),
            iconColor: const Color(0xFFD4A24C),
            title: 'Email Support',
            subtitle: 'support@getrightfom',
          ),
          _buildContactCard(icon: Icons.chat_bubble_outline, iconBg: const Color(0xFFCCDFF3), iconColor: const Color(0xFF5A9BD5), title: 'Live Chat', subtitle: 'Coming soon'),

          SizedBox(height: 28.h),

          // ── Send Feedback ────────────────────────────────────────────
          Text('Send Feedback', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 14.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FFE9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6F0DA), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("We'd Love To Hear From You!", style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: 4.h),
                Text('Email us at feedback@getright.com', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),
          ),

          SizedBox(height: 24.h),
        ],
      ),
    );
  }

  // ─── FAQ expandable card ──────────────────────────────────────────────
  Widget _buildFAQItem(int index, String question, String answer) {
    final isExpanded = _expandedFAQ == index;

    return GestureDetector(
      onTap: () => setState(() => _expandedFAQ = isExpanded ? -1 : index),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FFE9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6F0DA), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(question, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                ),
                Icon(isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.onBackground, size: 24),
              ],
            ),
            if (isExpanded) ...[SizedBox(height: 8.h), Text(answer, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.5))],
          ],
        ),
      ),
    );
  }

  // ─── Contact card ─────────────────────────────────────────────────────
  Widget _buildContactCard({required IconData icon, required Color iconBg, Color? iconColor, required String title, required String subtitle}) {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor ?? AppColors.accent, size: 22),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: 2.h),
                Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
