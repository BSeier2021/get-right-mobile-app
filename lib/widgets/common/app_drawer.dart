import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/views/library/library_screen.dart';

/// Professional App Drawer
///
/// A sleek and elegant navigation drawer matching the Get Right theme.
/// Features:
/// - User profile header
/// - Organized navigation sections
/// - Settings and help options
/// - Logout functionality
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    // Safely get StorageService with fallback
    String userName = 'Demo User';
    String userEmail = 'demo@getright.com';
    final NotificationController notificationController = Get.put(NotificationController());

    try {
      final storageService = Get.find<StorageService>();
      userName = storageService.getName() ?? 'Demo User';
      userEmail = storageService.getEmail() ?? 'demo@getright.com';
    } catch (e) {
      // If service not found, use default values
      debugPrint('StorageService not found: $e');
    }

    return Drawer(
      backgroundColor: AppColors.primary, // Black background
      child: Column(
        children: [
          // User Profile Header
          _buildUserHeader(userName, userEmail),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 16),

                // Fitness Section
                _buildSectionLabel('FITNESS'),

                _buildDrawerItem(
                  icon: Icons.trending_up,
                  activeIcon: Icons.trending_up,
                  title: 'Progress',
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.progress);
                  },
                ),

                _buildDrawerItem(
                  icon: Icons.track_changes_outlined,
                  activeIcon: Icons.track_changes,
                  title: 'My Programs',
                  onTap: () {
                    Get.toNamed(AppRoutes.myPrograms);
                  },
                ),

                _buildDrawerItem(
                  icon: Icons.sports_gymnastics_rounded,
                  activeIcon: Icons.library_books,
                  title: 'Library',
                  onTap: () {
                    Get.to(() => const LibraryScreen());
                  },
                ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.primaryGray, thickness: 0.5, height: 1),
                const SizedBox(height: 16),

                // Community Section
                _buildSectionLabel('COMMUNITY'),

                // Notifications item with badge
                Obx(
                  () => _buildDrawerItemWithBadge(
                    icon: Icons.notifications_outlined,
                    activeIcon: Icons.notifications,
                    title: 'Notifications',
                    unreadCount: notificationController.unreadCount,
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.notifications);
                    },
                  ),
                ),

                // _buildDrawerItem(
                //   icon: Icons.people_outline,
                //   activeIcon: Icons.people,
                //   title: 'Trainers',
                //   onTap: () {
                //     Get.back();
                //     Get.toNamed(AppRoutes.marketplace);
                //   },
                // ),
                // _buildDrawerItem(
                //   icon: Icons.history_outlined,
                //   activeIcon: Icons.history,
                //   title: 'Program History',
                //   onTap: () {
                //     Get.back();
                //     Get.toNamed(AppRoutes.programHistory);
                //   },
                // ),
                const SizedBox(height: 16),
                const Divider(color: AppColors.primaryGray, thickness: 0.5, height: 1),
                const SizedBox(height: 16),

                // Help & Support Section
                _buildSectionLabel('HELP & SUPPORT'),
                _buildDrawerItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  title: 'Settings',
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.settings);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.help_outline,
                  activeIcon: Icons.help,
                  title: 'Help & Feedback',
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.helpFeedback);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.info_outline,
                  activeIcon: Icons.info,
                  title: 'About',
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.about);
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.privacy_tip_outlined,
                  activeIcon: Icons.privacy_tip,
                  title: 'Privacy Policy',
                  onTap: () {
                    Get.back();
                    Get.toNamed(AppRoutes.privacyPolicy);
                  },
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // Logout Button
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  /// User Profile Header
  Widget _buildUserHeader(String userName, String userEmail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      decoration: BoxDecoration(
        color: const Color.fromARGB(108, 192, 192, 192),
        border: Border(bottom: BorderSide(color: AppColors.primaryGray.withOpacity(0.3), width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent, // Green accent
              border: Border.all(color: AppColors.primaryGray, width: 2),
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // User Name
          Text(
            userName,
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // User Email
          Text(
            "abc@gmail.com",
            style: AppTextStyles.bodySmall.copyWith(color: const Color.fromARGB(255, 55, 56, 58)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          // View Profile Button
          // InkWell(
          //   onTap: () {
          //     Get.back();
          //     Get.toNamed(AppRoutes.profile);
          //   },
          //   child: Container(
          //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          //     decoration: BoxDecoration(
          //       border: Border.all(color: AppColors.accent, width: 1.5),
          //       borderRadius: BorderRadius.circular(20),
          //     ),
          //     child: Text(
          //       'View Profile',
          //       style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  /// Section Label
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        label,
        style: AppTextStyles.overline.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600, letterSpacing: 1.2),
      ),
    );
  }

  /// Drawer Item
  Widget _buildDrawerItem({required IconData icon, required IconData activeIcon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent, size: 24),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      hoverColor: AppColors.accent.withOpacity(0.1),
      selectedTileColor: AppColors.accent.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  /// Drawer Item with Badge (for notifications)
  Widget _buildDrawerItemWithBadge({required IconData icon, required IconData activeIcon, required String title, required int unreadCount, required VoidCallback onTap}) {
    return ListTile(
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: AppColors.accent, size: 24),
          if (unreadCount > 0)
            Positioned(
              right: -8,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.0),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
      hoverColor: AppColors.accent.withOpacity(0.1),
      selectedTileColor: AppColors.accent.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  /// Logout Button
  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.primaryGray.withOpacity(0.3), width: 1)),
      ),
      child: InkWell(
        onTap: () {
          _showLogoutDialog(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.primaryVariant,
            border: Border.all(color: AppColors.error, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Text(
                'Logout',
                style: AppTextStyles.buttonMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show Logout Confirmation Dialog
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
        content: Text('Are you sure you want to logout?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.primaryGray)),
          ),
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              Get.back(); // Close drawer
              try {
                final authController = Get.find<AuthController>();
                authController.logout();
              } catch (e) {
                // If controller not found, navigate to login directly
                debugPrint('AuthController not found: $e');
                Get.offAllNamed(AppRoutes.login);
              }
            },
            child: Text('Logout', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
