import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/support_ticket_email.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help & Feedback Screen
class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  static const String _supportEmail = 'support@getright.com';

  int _expandedFAQ = -1;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _launchingEmail = false;

  final List<Map<String, String>> _faqs = [
    {
      'q': 'How do I log a workout?',
      'a': 'Open the Journal tab, tap the "+" button, and add your exercises, sets, and reps. You can save the workout to your calendar when you are done.',
    },
    {
      'q': 'Can I track my runs with GPS?',
      'a': 'Yes. Go to the Run tab and tap "Start Run" to begin GPS tracking. Location permission is required for route mapping, distance, and pace data.',
    },
    {
      'q': 'How do I enroll in a training program?',
      'a': 'Browse programs in the Marketplace. Some purchases are completed on the Get Right website, after which your program schedule appears in your calendar.',
    },
    {
      'q': 'How do I complete a program workout from my calendar?',
      'a': 'Open the Planner, select a scheduled program day, and tap an exercise to start the program workout screen. You can use the timer or enter duration manually when finished.',
    },
    {
      'q': 'How do I contact a trainer?',
      'a': 'Use in-app chat to message trainers you are connected with. You can also share workouts and run summaries directly in a conversation.',
    },
    {
      'q': 'How do I submit a support ticket?',
      'a': 'Open Support Tickets from the menu to view existing requests or create a new ticket linked to your account email.',
    },
    {
      'q': 'How do I change my password or update my profile?',
      'a': 'Go to Settings from the menu, then open Personal Profile or Change Password to update your account details.',
    },
    {
      'q': 'How do I delete my account?',
      'a': 'Open Settings, scroll to Account Actions, and choose Delete Account. This permanently removes your account and associated data.',
    },
  ];

  List<Map<String, String>> get _filteredFaqs {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _faqs;
    return _faqs
        .where(
          (faq) => faq['q']!.toLowerCase().contains(query) || faq['a']!.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openEmailSupport() async {
    if (_launchingEmail) return;
    setState(() => _launchingEmail = true);

    try {
      final accountEmail = await resolveSupportTicketEmail();
      final platformLabel = switch (defaultTargetPlatform) {
        TargetPlatform.android => 'Android',
        TargetPlatform.iOS => 'iOS',
        TargetPlatform.macOS => 'macOS',
        TargetPlatform.windows => 'Windows',
        TargetPlatform.linux => 'Linux',
        TargetPlatform.fuchsia => 'Fuchsia',
      };

      final body = '''
Hi Get Right Support,

Please describe your issue below:


---
Account email: ${accountEmail ?? 'Not signed in'}
App version: ${AppConstants.appVersion}
Platform: $platformLabel
''';

      final uri = Uri(
        scheme: 'mailto',
        path: _supportEmail,
        queryParameters: {
          'subject': 'Get Right Support Request',
          'body': body,
        },
      );

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        await _copySupportEmail(showConfirmation: true);
        Get.snackbar(
          'Email app unavailable',
          'Support email copied to clipboard. Paste it into your mail app.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.accent,
          colorText: AppColors.onError,
          margin: const EdgeInsets.all(16),
        );
      }
    } catch (_) {
      if (!mounted) return;
      await _copySupportEmail(showConfirmation: true);
      Get.snackbar(
        'Could not open email',
        'Support email copied to clipboard instead.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.accent,
        colorText: AppColors.onError,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      if (mounted) setState(() => _launchingEmail = false);
    }
  }

  Future<void> _copySupportEmail({bool showConfirmation = false}) async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (showConfirmation && mounted) return;
    if (!mounted) return;
    Get.snackbar(
      'Copied',
      'Support email copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.completed,
      colorText: AppColors.onError,
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _filteredFaqs;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        centerTitle: true,
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
          'Help & Feedback',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
        children: [
          _buildSectionLabel('Get Help Fast'),
          SizedBox(height: 12.h),
          _buildQuickActions(),
          SizedBox(height: 28.h),
          _buildSectionLabel('Frequently Asked Questions'),
          SizedBox(height: 12.h),
          _buildFaqSearch(),
          SizedBox(height: 14.h),
          if (filteredFaqs.isEmpty)
            _buildEmptySearchState()
          else
            ...List.generate(filteredFaqs.length, (i) {
              final faq = filteredFaqs[i];
              final originalIndex = _faqs.indexOf(faq);
              return _buildFAQItem(originalIndex, faq['q']!, faq['a']!);
            }),
          SizedBox(height: 20.h),
          _buildStillNeedHelpCard(),
        ],
      ),
    );
  }

  

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      children: [
        _buildActionTile(
          icon: Icons.email_outlined,
          iconBg: const Color(0xFFF5E6C8),
          iconColor: const Color(0xFFD4A24C),
          title: 'Email Support',
          subtitle: _supportEmail,
          trailing: _launchingEmail
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Copy email',
                      onPressed: _copySupportEmail,
                      icon: Icon(Icons.copy_rounded, size: 18.sp, color: AppColors.primaryGray),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray, size: 22.sp),
                  ],
                ),
          onTap: _openEmailSupport,
        ),
        SizedBox(height: 10.h),
        _buildActionTile(
          icon: Icons.confirmation_number_outlined,
          iconBg: const Color(0xFFD5EBEB),
          iconColor: const Color(0xFF4A9B9B),
          title: 'Support Tickets',
          subtitle: 'Track requests and get updates',
          onTap: () => Get.toNamed(AppRoutes.supportTickets),
        ),
      
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FFE9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6F0DA), width: 0.8),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            child: Row(
              children: [
                Container(
                  width: 46.w,
                  height: 46.w,
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 22.sp),
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
                trailing ?? Icon(Icons.chevron_right_rounded, color: AppColors.primaryGray, size: 22.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget _buildCompactActionTile({
  //   required IconData icon,
  //   required String title,
  //   required VoidCallback onTap,
  // }) {
  //   return Material(
  //     color: Colors.transparent,
  //     child: InkWell(
  //       borderRadius: BorderRadius.circular(14),
  //       onTap: onTap,
  //       child: Ink(
  //         decoration: BoxDecoration(
  //           color: const Color(0xFFF8FFE9),
  //           borderRadius: BorderRadius.circular(14),
  //           border: Border.all(color: const Color(0xFFE6F0DA), width: 0.8),
  //         ),
  //         child: Padding(
  //           padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 16.h),
  //           child: Row(
  //             mainAxisAlignment: MainAxisAlignment.center,
  //             children: [
  //               Icon(icon, color: AppColors.accent, size: 20.sp),
  //               SizedBox(width: 8.w),
  //               Text(title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Widget _buildFaqSearch() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() {
        _searchQuery = value;
        _expandedFAQ = -1;
      }),
      decoration: InputDecoration(
        hintText: 'Search help topics...',
        hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
        prefixIcon: Icon(Icons.search_rounded, color: AppColors.primaryGray, size: 22.sp),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: AppColors.primaryGray, size: 20.sp),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _expandedFAQ = -1;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF8FFE9),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE6F0DA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE6F0DA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.accent.withOpacity(0.6)),
        ),
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 28.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA)),
      ),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 36.sp, color: AppColors.primaryGray),
          SizedBox(height: 10.h),
          Text(
            'No matching topics found',
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 6.h),
          Text(
            'Try another keyword or contact support directly.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(int index, String question, String answer) {
    final isExpanded = _expandedFAQ == index;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _expandedFAQ = isExpanded ? -1 : index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: isExpanded ? const Color(0xFFF3FBE3) : const Color(0xFFF8FFE9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isExpanded ? AppColors.accent.withOpacity(0.35) : const Color(0xFFE6F0DA),
                width: isExpanded ? 1.2 : 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28.w,
                      height: 28.w,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.help_outline_rounded, size: 16.sp, color: AppColors.accent),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        question,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.onBackground, size: 24.sp),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: EdgeInsets.only(top: 12.h, left: 38.w),
                    child: Text(
                      answer,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.55),
                    ),
                  ),
                  crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                  sizeCurve: Curves.easeOutCubic,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStillNeedHelpCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Still need help?',
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 8.h),
          Text(
            'Our team typically responds within 1–2 business days. Include screenshots and steps to reproduce the issue for faster support.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, height: 1.5),
          ),
          SizedBox(height: 14.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _launchingEmail ? null : _openEmailSupport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onError,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.mail_outline_rounded, size: 20.sp),
              label: Text(
                _launchingEmail ? 'Opening email...' : 'Email Support',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.onError),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
