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
import 'package:flutter_svg/flutter_svg.dart';

/// Home screen with bottom navigation - 5 tabs
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final HomeNavigationController _navController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool? _hasSubscriptionCache;

  final List<Widget> _screens = const [MarketplaceScreen(), FeedScreen(), CombinedJournalScreen(), NutritionScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize navigation controller
    _navController = Get.put(HomeNavigationController());
    // Store scaffold key in controller for global access
    _navController.scaffoldKey = _scaffoldKey;
    // Initialize notification controller
    Get.put(NotificationController());

    // Cache subscription status after first frame to avoid build-time issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshSubscriptionStatus();
    });

    // Check if we should redirect based on preference from auth questionnaire or navigateToTab argument
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments as Map<String, dynamic>?;

      // Check for navigateToTab argument (used from favorites screen, drawer, etc.)
      final navigateToTab = args?['navigateToTab'] as int?;
      final journalTabIndex = args?['journalTabIndex'] as int?;
      if (navigateToTab != null) {
        _navController.changeTab(navigateToTab, journalTab: journalTabIndex);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh subscription status when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshSubscriptionStatus();
    }
  }

  /// Refresh subscription status and update UI
  void _refreshSubscriptionStatus() {
    if (!mounted) return;
    try {
      final newStatus = _hasSubscription();
      if (_hasSubscriptionCache != newStatus) {
        debugPrint('Subscription status updated: $_hasSubscriptionCache → $newStatus');
        if (mounted) {
          setState(() {
            _hasSubscriptionCache = newStatus;
          });
          _navController.triggerRefresh();
        }
      }
    } catch (e) {
      debugPrint('Error refreshing subscription status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Refresh subscription when returning from any route (especially payment screen)
        if (didPop && mounted) {
          // Add a small delay to ensure storage is updated
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _refreshSubscriptionStatus();
            }
          });
        }
      },
      child: Obx(() {
        // Rebuild shell when subscription refresh trigger bumps (bottom nav key / premium UI).
        final _ = _navController.refreshTrigger.value;

        return Scaffold(
          backgroundColor: AppColors.backgroundColor,
          key: _scaffoldKey,
          drawer: const AppDrawer(), // Professional app drawer
          body: IndexedStack(index: _navController.currentIndex, children: _screens),
          bottomNavigationBar: _buildProfessionalBottomNav(key: ValueKey('nav_${_hasSubscriptionCache}_${_navController.currentIndex}')),
        );
      }),
    );
  }

  Widget _buildProfessionalBottomNav({Key? key}) {
    final navItems = [
      // Left
      {'icon': 'assets/icons/shop.svg', 'activeIcon': 'assets/icons/shop.svg', 'label': 'Market'},
      {'icon': 'assets/icons/feed.svg', 'activeIcon': 'assets/icons/feed.svg', 'label': 'Feed'},
      {'icon': 'assets/images/Vector (4).png', 'activeIcon': 'assets/images/Vector (4).png', 'label': 'Journal'},
      {'icon': 'assets/icons/nutrition.svg', 'activeIcon': 'assets/icons/nutrition.svg', 'label': 'Nutrition'},
      {'icon': 'assets/icons/personal.svg', 'activeIcon': 'assets/icons/personal.svg', 'label': 'Profile'},
    ];

    return ClipRRect(
      key: key,
      clipBehavior: Clip.none,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.primaryGrayLight, width: 1)),
          ),
          child: SafeArea(
            top: false,
            child: Container(
              height: 80,
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
    const greenAccent = Color(0xFF214E31);
    const blackPrimary = Color(0xFF000000);
    const textSecondary = Color(0xFF404040);

    // Check if this is the nutrition tab (index 3) and user doesn't have subscription
    final isNutritionTab = index == 3;
    // Always check fresh subscription status to ensure it's up to date
    final hasSubscription = _hasSubscriptionCache ?? _hasSubscription();
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
          clipBehavior: Clip.none,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, isCenter ? -18 : 0),
                    child: AnimatedContainer(
                      clipBehavior: Clip.none,

                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: isCenter ? 65 : (isSelected ? 40 : 34),
                      height: isCenter ? 65 : (isSelected ? 40 : 34),
                      decoration: BoxDecoration(
                        color: isCenter
                            ? greenAccent
                            : isSelected
                            ? greenAccent.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(isCenter ? 50 : 50),
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
                                    : _buildNavGraphic(
                                        activeIcon,
                                        isCenter: isCenter,
                                        isSelected: true,
                                        selectedColor: isCenter ? Colors.white : greenAccent,
                                        unselectedColor: textSecondary,
                                      ),
                              )
                            : isLocked
                            ? Icon(Icons.lock, key: ValueKey('$index-$isSelected-$isLocked-lock'), color: isCenter ? Colors.white : textSecondary, size: isCenter ? 24 : 20)
                            : _buildNavGraphic(icon, isCenter: isCenter, isSelected: false, selectedColor: isCenter ? Colors.white : greenAccent, unselectedColor: textSecondary),
                      ),
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

  Widget _buildNavGraphic(String assetPath, {required bool isCenter, required bool isSelected, required Color selectedColor, required Color unselectedColor}) {
    final targetColor = isSelected ? selectedColor : unselectedColor;
    final size = isCenter ? 35.0 : 20.0;
    if (assetPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(assetPath, width: size, height: size, colorFilter: ColorFilter.mode(targetColor, BlendMode.srcIn), key: ValueKey('svg-$assetPath-$isSelected'));
    } else {
      return Image.asset(assetPath, width: size, height: size, key: ValueKey('img-$assetPath-$isSelected'));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Get.delete<HomeNavigationController>();
    super.dispose();
  }
}
