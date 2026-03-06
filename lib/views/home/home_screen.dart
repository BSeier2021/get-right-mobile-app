import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:get_right/views/journal/combined_journal_screen.dart';
import 'package:get_right/views/feed/feed_screen.dart';
import 'package:get_right/views/marketplace/marketplace_screen.dart';
import 'package:get_right/views/nutrition/nutrition_screen.dart';
import 'package:get_right/views/profile/profile_screen.dart';
import 'package:get_right/widgets/common/app_drawer.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Home screen with bottom navigation - 5 tabs
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeNavigationController _navController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool? _hasSubscriptionCache;

  final List<Widget> _screens = const [
    MarketplaceScreen(), // Marketplace
    FeedScreen(), // Community Feed
    CombinedJournalScreen(), // Journal (Center - Workout Journal + Runner Log)
    NutritionScreen(), // Home
    ProfileScreen(), // Library
  ];

  @override
  void initState() {
    super.initState();
    // Initialize navigation controller
    _navController = Get.put(HomeNavigationController());
    // Store scaffold key in controller for global access
    _navController.scaffoldKey = _scaffoldKey;
    // Initialize notification controller
    Get.put(NotificationController());

    // Cache subscription status after first frame to avoid build-time issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hasSubscriptionCache = _hasSubscription();
      if (mounted) {
        setState(() {});
      }
    });

    // Check if we should redirect based on preference from auth questionnaire or navigateToTab argument
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments as Map<String, dynamic>?;

      // Check for navigateToTab argument (used from favorites screen)
      final navigateToTab = args?['navigateToTab'] as int?;
      if (navigateToTab != null) {
        _navController.changeTab(navigateToTab);
        return;
      }

      // Check for preference argument
      final preference = args?['preference'] as String?;
      if (preference != null) {
        // Navigate to journal tab (index 2)
        // Set journal tab index: 0 for Strength Training (Workout Journal), 1 for Running & Cardio (Runner Log)
        final journalTabIndex = preference == 'Strength Training' ? 0 : 1;
        _navController.changeTab(2, journalTab: journalTabIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: AppColors.backgroundColor,
          key: _scaffoldKey,
          drawer: const AppDrawer(), // Professional app drawer
          body: IndexedStack(index: _navController.currentIndex, children: _screens),
          bottomNavigationBar: _buildProfessionalBottomNav(),
        ),
      ),
    );
  }

  Widget _buildProfessionalBottomNav() {
    final navItems = [
      // {'icon': Icons.home_outlined, 'activeIcon': Icons.home_rounded, 'label': 'Home'},
      {'icon': 'assets/images/market1.png', 'activeIcon': 'assets/images/marketfill.png', 'label': 'Market'},
      {'icon': 'assets/images/feed1.png', 'activeIcon': 'assets/images/feedfill.png', 'label': 'Feed'},
      {'icon': 'assets/images/Vector (4).png', 'activeIcon': 'assets/images/Vector (4).png', 'label': 'Journal'},
      {'icon': 'assets/images/nutrition1.png', 'activeIcon': 'assets/images/nutritionfill.png', 'label': 'Nutrition'},
      {'icon': 'assets/images/profile1.png', 'activeIcon': 'assets/images/profilefill.png', 'label': 'Profile'},
    ];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.primaryGrayLight, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Container(
              height: 68,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(navItems.length, (index) {
                  final isCenter = index == 2;
                  return _buildNavItem(
                    icon: navItems[index]['icon'] as String,
                    activeIcon: navItems[index]['activeIcon'] as String,
                    label: navItems[index]['label'] as String,
                    index: index,
                    isSelected: _navController.currentIndex == index,
                    isCenter: isCenter,
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Check if user has subscription
  bool _hasSubscription() {
    try {
      final storageService = Get.find<StorageService>();
      return storageService.hasActiveSubscription();
    } catch (e) {
      return false;
    }
  }

  /// Show subscription required dialog
  void _showSubscriptionRequiredDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.lock, color: AppColors.accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Premium Feature',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nutrition tracking is a premium feature. Subscribe to unlock:', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 16),
            _buildBenefitItem(Icons.local_fire_department, 'Daily calorie & macro tracking', ''),
            const SizedBox(height: 8),
            _buildBenefitItem(Icons.restaurant_menu, 'Full cookbook access', ''),
            const SizedBox(height: 8),
            _buildBenefitItem(Icons.people, 'Community features', ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Later', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mediumGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed(AppRoutes.paymentForm, arguments: {'type': 'subscription'});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('View Plans'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
              ),
              if (description.isNotEmpty) ...[const SizedBox(height: 2), Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.mediumGray))],
            ],
          ),
        ),
      ],
    );
  }

  /// Modern navigation item
  Widget _buildNavItem({required String icon, required String activeIcon, required String label, required int index, required bool isSelected, bool isCenter = false}) {
    const greenAccent = Color(0xFF29603C);
    const blackPrimary = Color(0xFF000000);
    const textSecondary = Color(0xFF404040);

    // Check if this is the nutrition tab (index 4) and user doesn't have subscription
    final isNutritionTab = index == 3;
    final hasSubscription = _hasSubscriptionCache ?? false;
    final isLocked = isNutritionTab && !hasSubscription;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isLocked) {
            _showSubscriptionRequiredDialog();
          } else {
            _navController.changeTab(index);
          }
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: isCenter ? 48 : (isSelected ? 40 : 34),
                    height: isCenter ? 48 : (isSelected ? 40 : 34),
                    decoration: BoxDecoration(
                      color: isCenter
                          ? greenAccent
                          : isSelected
                          ? greenAccent.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(isCenter ? 26 : 22),
                      boxShadow: isCenter ? [BoxShadow(color: greenAccent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))] : null,
                    ),
                    child: Center(
                      child: isSelected
                          ? AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(scale: animation, child: child);
                              },
                              child: isLocked
                                  ? Icon(Icons.lock, key: ValueKey('$index-$isSelected-$isLocked-lock'), color: isCenter ? Colors.white : greenAccent, size: isCenter ? 24 : 20)
                                  : Image.asset(activeIcon, key: ValueKey('$index-$isSelected-$isLocked'), width: isCenter ? 24 : 20, height: isCenter ? 24 : 20),
                            )
                          : isLocked
                          ? Icon(Icons.lock, key: ValueKey('$index-$isSelected-$isLocked-lock'), color: isCenter ? Colors.white : textSecondary, size: isCenter ? 24 : 20)
                          : Image.asset(icon, key: ValueKey('$index-$isSelected-$isLocked'), width: isCenter ? 24 : 20, height: isCenter ? 24 : 20),
                    ),
                  ),
                  // Lock badge overlay for locked nutrition tab
                  if (isLocked && !isSelected)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.lock, size: 8, color: Colors.white),
                      ),
                    ),
                ],
              ),
              // Label (hidden for center item)
              if (!isCenter) ...[
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isLocked ? AppColors.accent : (isSelected ? blackPrimary : textSecondary),
                    letterSpacing: 0.2,
                    height: 1.0,
                  ),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<HomeNavigationController>();
    super.dispose();
  }
}
