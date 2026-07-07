import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/controllers/chat_controller.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/models/customer_profile_dto.dart';
import 'package:get_right/services/api_service.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/views/library/library_screen.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:get_right/widgets/safe_network_image.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  int _chatUnreadCount = 0;
  Worker? _chatUnreadWorker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!Get.isRegistered<AuthController>()) return;
      final auth = Get.find<AuthController>();
      if (!auth.isLoggedIn() || auth.isSessionInvalidating) return;
      if (auth.customerProfile == null && !auth.customerProfileLoading) {
        auth.fetchCustomerProfile();
      }
      await _ensureChatUnreadCountLoaded();
      _attachChatUnreadListener();
    });
  }

  @override
  void dispose() {
    _chatUnreadWorker?.dispose();
    super.dispose();
  }

  void _attachChatUnreadListener() {
    if (!Get.isRegistered<ChatController>()) return;

    final controller = Get.find<ChatController>();
    if (mounted) {
      setState(() => _chatUnreadCount = controller.totalUnreadCount.value);
    }

    _chatUnreadWorker?.dispose();
    _chatUnreadWorker = ever<int>(controller.totalUnreadCount, (count) {
      if (mounted) setState(() => _chatUnreadCount = count);
    });
  }

  Future<void> _ensureChatUnreadCountLoaded() async {
    try {
      if (!Get.isRegistered<AuthController>()) return;
      final auth = Get.find<AuthController>();
      if (!auth.isLoggedIn() || auth.isSessionInvalidating) return;

      ChatController controller;
      if (Get.isRegistered<ChatController>()) {
        controller = Get.find<ChatController>();
      } else {
        final apiService = await ApiService.getInstance();
        final storageService = await StorageService.getInstance();
        controller = Get.put(ChatController(apiService, storageService));
      }
      await controller.loadUnreadCount();
      if (mounted) {
        setState(() => _chatUnreadCount = controller.totalUnreadCount.value);
      }
    } catch (_) {}
  }

  String _displayName(CustomerProfileDto? p, StorageService storage) {
    final n = p?.fullName?.trim();
    if (n != null && n.isNotEmpty) return n;
    return storage.getName()?.trim().isNotEmpty == true ? storage.getName()!.trim() : 'Demo User';
  }

  String _displayEmail(CustomerProfileDto? p, StorageService storage) {
    if (p != null) {
      final e = p.email.trim();
      if (e.isNotEmpty) return e;
    }
    return storage.getEmail()?.trim().isNotEmpty == true ? storage.getEmail()!.trim() : 'demo@getright.com';
  }

  String? _photoUrl(CustomerProfileDto? p, StorageService? storage) {
    final fromProfile = p?.profilePictureUrl?.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
    final fromStorage = storage?.getProfilePictureUrl()?.trim();
    if (fromStorage != null && fromStorage.isNotEmpty) return fromStorage;
    return null;
  }

  void _navigateToWorkoutJournal() {
    Get.back();
    if (Get.isRegistered<HomeNavigationController>()) {
      if (Get.currentRoute != AppRoutes.home) {
        Get.until((route) => route.settings.name == AppRoutes.home);
      }
      Get.find<HomeNavigationController>().changeTab(2, journalTab: 0);
      return;
    }
    Get.offNamed(AppRoutes.home, arguments: {'navigateToTab': 2, 'journalTabIndex': 0});
  }

  @override
  Widget build(BuildContext context) {
    final NotificationController notificationController = Get.put(NotificationController());
    StorageService? storage;
    try {
      storage = Get.find<StorageService>();
    } catch (e) {
      debugPrint('StorageService not found: $e');
    }

    return Drawer(
      backgroundColor: AppColors.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            GetBuilder<AuthController>(
              builder: (auth) {
                final p = auth.customerProfile;
                final name = storage != null ? _displayName(p, storage) : (p?.fullName?.trim().isNotEmpty == true ? p!.fullName!.trim() : 'Demo User');
                final email = storage != null ? _displayEmail(p, storage) : (p?.email.trim().isNotEmpty == true ? p!.email.trim() : 'demo@getright.com');
                final photo = _photoUrl(p, storage);
                final loadingHeader = auth.customerProfileLoading && p == null && (storage?.getName()?.trim().isEmpty ?? true);
                return _buildUserHeader(name, email, photo, loadingHeader);
              },
            ),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  const SizedBox(height: 20),

                  _sectionLabel('FITNESS'),
                  const SizedBox(height: 4),
                  _drawerItem(asset: 'assets/images/Vector.png', fallbackIcon: Icons.fitness_center_outlined, title: 'Workout Journal', onTap: _navigateToWorkoutJournal),
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
                    fallbackIcon: Icons.receipt_long_outlined,
                    title: 'Transaction History',
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.transactionHistory);
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

                  _sectionLabel('COMMUNITY'),
                  const SizedBox(height: 4),
                  _drawerItem(
                    fallbackIcon: Icons.explore_outlined,
                    title: 'Discover',
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.discover);
                    },
                  ),
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
                  _drawerItem(
                    fallbackIcon: Icons.chat_bubble_outline_rounded,
                    title: 'Chat',
                    badgeCount: _chatUnreadCount,
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.chatList)?.then((_) async {
                        await _ensureChatUnreadCountLoaded();
                        _attachChatUnreadListener();
                      });
                    },
                  ),
                  _drawerItem(
                    fallbackIcon: Icons.bookmark_added_outlined,
                    title: 'Save Reels',
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.savedReels);
                    },
                  ),

                  const SizedBox(height: 24),

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
                    fallbackIcon: Icons.support_agent_outlined,
                    title: 'Support Tickets',
                    onTap: () {
                      Get.back();
                      Get.toNamed(AppRoutes.supportTickets);
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

            _buildLogoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUserHeader(String name, String email, String? photoUrl, bool loadingProfile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 70.w,
                height: 70.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipOval(
                      child: SafeNetworkImage(
                        url: photoUrl,
                        width: 70.w,
                        height: 70.w,
                        fit: BoxFit.cover,
                        fallback: Image.asset('assets/images/Ellipse 8.png', width: 70.w, fit: BoxFit.cover),
                      ),
                    ),
                    if (loadingProfile)
                      Positioned.fill(
                        child: ClipOval(
                          child: Container(
                            color: Colors.black26,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 22.w,
                              height: 22.w,
                              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                name,
                style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.onPrimary, fontSize: 20.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontSize: 13.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.w800, fontSize: 15.sp, letterSpacing: 1.2),
      ),
    );
  }

  Widget _drawerItem({String? asset, required IconData fallbackIcon, required String title, required VoidCallback onTap, int badgeCount = 0}) {
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
                  asset != null
                      ? Image.asset(
                          asset,
                          width: 20,
                          height: 20,
                          color: AppColors.accent,
                          errorBuilder: (c, e, s) => Icon(fallbackIcon, color: AppColors.accent, size: 22),
                        )
                      : Icon(fallbackIcon, color: AppColors.accent, size: 24),
                  if (badgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
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
                  Image.asset('assets/images/notification (1).png', width: 22, height: 22),
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
            onPressed: () async {
              Get.back();
              Get.back();
              try {
                final authController = Get.find<AuthController>();
                await authController.logout();
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
