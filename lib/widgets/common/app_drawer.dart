import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/views/library/library_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    String userName = 'Demo User';
    String userEmail = 'demo@getright.com';
    String? userPhoto;
    final NotificationController notificationController = Get.put(NotificationController());

    try {
      final storageService = Get.find<StorageService>();
      userName = storageService.getName() ?? 'Demo User';
      userEmail = storageService.getEmail() ?? 'demo@getright.com';
    } catch (e) {
      debugPrint('StorageService not found: $e');
    }

    return Drawer(
      backgroundColor: AppColors.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // ── User header ──────────────────────────────
            _buildUserHeader(userName, userEmail, userPhoto),

            // ── Menu items ───────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 20),

                  // FITNESS
                  _sectionLabel('FITNESS'),
                  const SizedBox(height: 4),
                  _drawerItem(
                    asset: 'assets/images/diagram.png',
                    fallbackIcon: Icons.show_chart_rounded,
                    title: 'Progress',
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.progress);
                    },
                  ),
                  _drawerItem(
                    asset: 'assets/images/radar-2.png',
                    fallbackIcon: Icons.track_changes_outlined,
                    title: 'My Programs',
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.myPrograms);
                    },
                  ),
                  _drawerItem(
                    asset: 'assets/images/music-library-2.png',
                    fallbackIcon: Icons.lock_outline_rounded,
                    title: 'Library',
                    onTap: () {
                      Get.back();
                      Get.to(() => const LibraryScreen());
                    },
                  ),

                  const SizedBox(height: 24),

                  // COMMUNITY
                  _sectionLabel('COMMUNITY'),
                  const SizedBox(height: 4),
                  Obx(
                    () => _drawerItemWithBadge(
                      fallbackIcon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      unreadCount: notificationController.unreadCount,
                      onTap: () {
                        Get.back();
                        Get.toNamed(AppRoutes.notifications);
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // HELP & SUPPORT
                  _sectionLabel('HELP & SUPPORT'),
                  const SizedBox(height: 4),
                  _drawerItem(
                    fallbackIcon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.settings);
                    },
                  ),
                  _drawerItem(
                    fallbackIcon: Icons.help_outline_rounded,
                    title: 'Help & Feedback',
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.helpFeedback);
                    },
                  ),
                  _drawerItem(
                    fallbackIcon: Icons.info_outline_rounded,
                    title: 'About',
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.about);
                    },
                  ),
                  _drawerItem(
                    asset: 'assets/images/danger.png',
                    fallbackIcon: Icons.privacy_tip_outlined,
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

            // ── Logout button ────────────────────────────
            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  // ─── User header ──────────────────────────────────────────────────────
  Widget _buildUserHeader(String name, String email, String? photoUrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Image.asset('assets/images/Ellipse 8.png', width: 70.w),

            const SizedBox(height: 14),

            // Name
            Text(
              "Billy Kane",
              style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.onPrimary, fontSize: 20.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 2),

            // Email
            Text(
              "billykane@domain.com",
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontSize: 13.sp),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    ).paddingOnly(left: 24, top: 24, right: 24, bottom: 24);
  }

  // ─── Section label ────────────────────────────────────────────────────
  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w800, fontSize: 15.sp, letterSpacing: 1.2),
      ),
    );
  }

  // ─── Drawer item ──────────────────────────────────────────────────────
  Widget _drawerItem({String? asset, required IconData fallbackIcon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        child: Row(
          children: [
            // Icon
            SizedBox(
              width: 24,
              height: 24,
              child: asset != null
                  ? Image.asset(
                      asset,
                      width: 20,
                      height: 20,
                      color: AppColors.accent,
                      errorBuilder: (c, e, s) => Icon(fallbackIcon, color: AppColors.accent, size: 22),
                    )
                  : Icon(fallbackIcon, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 16),
            // Title
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w500, fontSize: 14.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Drawer item with notification badge ──────────────────────────────
  Widget _drawerItemWithBadge({required IconData fallbackIcon, required String title, required int unreadCount, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Image.asset('assets/images/notification (1).png', width: 20, height: 20),
                  if (unreadCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, height: 1.0),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w500, fontSize: 14.sp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Logout button ────────────────────────────────────────────────────
  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showLogoutDialog(context),
          icon: Image.asset('assets/images/logout.png', width: 20, height: 20),
          label: Text(
            'Logout',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15.sp),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE85050),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ─── Logout dialog ────────────────────────────────────────────────────
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
              Get.back();
              Get.back();
              try {
                final authController = Get.find<AuthController>();
                authController.logout();
              } catch (e) {
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
