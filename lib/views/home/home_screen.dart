import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:get_right/views/journal/combined_journal_screen.dart';
import 'package:get_right/views/feed/feed_screen.dart';
import 'package:get_right/views/marketplace/marketplace_screen.dart';
import 'package:get_right/views/nutrition/nutrition_screen.dart';
import 'package:get_right/views/profile/profile_screen.dart';
import 'package:get_right/widgets/common/app_drawer.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Home screen with bottom navigation - 5 tabs
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeNavigationController _navController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = const [MarketplaceScreen(), FeedScreen(), CombinedJournalScreen(), NutritionScreen(), ProfileScreen()];

  @override
  void initState() {
    super.initState();
    // Initialize navigation controller
    _navController = Get.put(HomeNavigationController());
    // Store scaffold key in controller for global access
    _navController.scaffoldKey = _scaffoldKey;
    // Initialize notification controller
    Get.put(NotificationController());

    // Check if we should redirect based on preference from auth questionnaire or navigateToTab argument
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments as Map<String, dynamic>?;

      // Check for navigateToTab argument (used from favorites screen, drawer, etc.)
      final navigateToTab = args?['navigateToTab'] as int?;
      final journalTabIndex = args?['journalTabIndex'] as int?;
      if (navigateToTab != null) {
        _navController.changeTab(navigateToTab, journalTab: journalTabIndex);
        _applyJournalPlannerContextFromArgs(args);
        if (navigateToTab == 3) {
          _refreshNutritionAnalytics();
        }
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

  void _applyJournalPlannerContextFromArgs(Map<String, dynamic>? args) {
    final raw = args?['journalPlannerContext'];
    if (raw is! Map) return;
    final context = Map<String, dynamic>.from(raw);
    final dateRaw = context['date']?.toString();
    final date = dateRaw != null ? DateTime.tryParse(dateRaw) : null;
    if (date == null) return;
    _navController.setJournalPlannerContext(
      date: date,
      journalId: context['journalId']?.toString(),
      startFresh: context['startFresh'] == true,
      plannedRouteId: context['plannedRouteId']?.toString(),
    );
  }

  void _refreshNutritionAnalytics() {
    try {
      final nutritionController = Get.isRegistered<NutritionController>() ? Get.find<NutritionController>() : Get.put(NutritionController());
      nutritionController.fetchNutritionTracker();
    } catch (e) {
      debugPrint('Error refreshing nutrition analytics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Obx(() {
        final _ = _navController.refreshTrigger.value;
        final isFeedTab = _navController.currentIndex == 1;

        return Scaffold(
          backgroundColor: isFeedTab ? Colors.black : AppColors.backgroundColor,
          key: _scaffoldKey,
          drawer: const AppDrawer(),
          body: IndexedStack(index: _navController.currentIndex, children: _screens),
          bottomNavigationBar: _buildProfessionalBottomNav(
            key: ValueKey('nav_${_navController.currentIndex}'),
            darkMode: isFeedTab,
          ),
        );
      }),
    );
  }

  Widget _buildProfessionalBottomNav({Key? key, bool darkMode = false}) {
    final navItems = [
      // Left
      {'icon': 'assets/icons/shop.svg', 'activeIcon': 'assets/icons/shop.svg', 'label': 'Market'},
      {'icon': 'assets/icons/feed.svg', 'activeIcon': 'assets/icons/feed.svg', 'label': 'Feed'},
      {'icon': 'assets/images/Vector (4).png', 'activeIcon': 'assets/images/Vector (4).png', 'label': 'Journal'},
      {'icon': 'assets/icons/nutrition.svg', 'activeIcon': 'assets/icons/nutrition.svg', 'label': 'Nutrition'},
      {'icon': 'assets/icons/personal.svg', 'activeIcon': 'assets/icons/personal.svg', 'label': 'Profile'},
    ];

    final barColor = darkMode ? const Color(0xFF0B0B0B) : AppColors.white;
    final borderColor = darkMode ? Colors.white.withValues(alpha: 0.08) : AppColors.primaryGrayLight;

    return ClipRRect(
      key: key,
      clipBehavior: Clip.none,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Container(
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
            border: Border(top: BorderSide(color: borderColor, width: 1)),
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
                    darkMode: darkMode,
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Modern navigation item
  Widget _buildNavItem({
    required String icon,
    required String activeIcon,
    required String label,
    required int index,
    required bool isSelected,
    bool isCenter = false,
    bool darkMode = false,
  }) {
    const greenAccent = Color(0xFF214E31);
    final selectedLabel = darkMode ? Colors.white : const Color(0xFF000000);
    final unselectedLabel = darkMode ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF404040);
    final selectedIconBg = darkMode ? Colors.white.withValues(alpha: 0.12) : greenAccent.withValues(alpha: 0.12);
    final selectedIconColor = darkMode ? Colors.white : greenAccent;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (index == 2) {
            _navController.openWorkoutJournalFromNav();
          } else {
            _navController.changeTab(index);
          }
          if (index == 3) {
            _refreshNutritionAnalytics();
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
                            ? selectedIconBg
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: isCenter ? [BoxShadow(color: greenAccent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))] : null,
                      ),
                      child: Center(
                        child: isSelected
                            ? AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, animation) {
                                  return ScaleTransition(scale: animation, child: child);
                                },
                                child: _buildNavGraphic(
                                  activeIcon,
                                  isCenter: isCenter,
                                  isSelected: true,
                                  selectedColor: isCenter ? Colors.white : selectedIconColor,
                                  unselectedColor: unselectedLabel,
                                ),
                              )
                            : _buildNavGraphic(
                                icon,
                                isCenter: isCenter,
                                isSelected: false,
                                selectedColor: isCenter ? Colors.white : selectedIconColor,
                                unselectedColor: unselectedLabel,
                              ),
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
                    color: isSelected ? selectedLabel : unselectedLabel,
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
    Get.delete<HomeNavigationController>();
    super.dispose();
  }
}
