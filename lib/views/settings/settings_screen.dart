import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/settings_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/settings/change_password_screen.dart';

/// Settings screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsController controller = Get.put(SettingsController());

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.15), width: 1),
            ),
            child: const Icon(Icons.chevron_left, color: AppColors.accent, size: 25),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Settings',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Introduction section ─────────────────────────────
          _sectionLabel('Introduction'),

          // Personal Profile
          _settingsCard(
            iconBg: const Color(0xFFEBD9E6),
            image: 'assets/images/profile00.png',
            title: 'Personal Profile',
            subtitle: 'Manage your personal information',
            showChevron: true,
            onTap: () => Get.toNamed(AppRoutes.personalProfile),
          ),

          // Enable Notifications
          // _settingsCard(
          //   iconBg: const Color(0xFFF9E9C3),
          //   image: 'assets/images/notification333.png',
          //   title: 'Enable Notifications',
          //   subtitle: 'Receive workout reminders and updates',
          //   onTap: () => controller.toggleNotifications(!controller.notificationsEnabled),
          // ),

          // Change Password
          _settingsCard(
            iconBg: const Color(0xFFD5EBEB),
            image: 'assets/images/lock333.png',
            title: 'Change Password',
            subtitle: 'Update your account password',
            showChevron: true,
            onTap: () => Get.to(() => const ChangePasswordScreen()),
          ),

          // Blocked Users
          _settingsCard(
            iconBg: const Color(0xFFD9EBD3),
            image: 'assets/images/profile-delete.png',
            title: 'Blocked Users',
            subtitle: "Manage people you've blocked",
            showChevron: true,
            onTap: () => Get.toNamed(AppRoutes.blockedUsers),
          ),

          // Reports
          _settingsCard(
            iconBg: const Color(0xFFEBD9E6),
            image: 'assets/images/receipt-disscount333.png',
            title: 'Reports',
            subtitle: 'Reported users and posts',
            showChevron: true,
            onTap: () => Get.toNamed(AppRoutes.reports),
          ),

          // Transaction History
          _settingsCard(
            iconBg: const Color(0xFFF9E9C3),
            image: 'assets/images/receipt-item3333.png',
            title: 'Transaction History',
            subtitle: 'View your payment history',
            showChevron: true,
            onTap: () => Get.toNamed(AppRoutes.transactionHistory),
          ),

          // ── Account Actions section ──────────────────────────
          _sectionLabel('Account Actions'),

          // Logout
          _settingsCard(iconBg: const Color(0xFFF5D5D0), image: 'assets/images/logout333.png', title: 'Logout', onTap: controller.logout),

          // Delete Account
          _settingsCard(
            iconBg: const Color(0xFFF5D0D5),
            image: 'assets/images/trash.png',
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and data',
            showChevron: true,
            onTap: controller.deleteAccount,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Section label ──────────────────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12, left: 4),
      child: Text(
        text,
        style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  // ── Individual settings card ───────────────────────────────
  Widget _settingsCard({required Color iconBg, required String image, required String title, String? subtitle, bool showChevron = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7FCEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
            ),
            child: Row(
              children: [
                // Circular icon
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Image.asset(image),
                ),
                const SizedBox(width: 14),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (subtitle != null) ...[const SizedBox(height: 3), Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12.5))],
                    ],
                  ),
                ),
                if (showChevron) const Icon(Icons.chevron_right, color: AppColors.primaryGray, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
