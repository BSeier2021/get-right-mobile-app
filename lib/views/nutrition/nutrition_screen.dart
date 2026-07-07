import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/controllers/nutrition_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/nutrition/nutrition_tracker_tab.dart';
import 'package:get_right/views/nutrition/recipes_tab.dart';
import 'package:get_right/views/planner/planner_screen.dart';

/// Main Nutrition Screen with Tracker and Recipes tabs
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final nutritionController = Get.put(NutritionController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      nutritionController.fetchNutritionTracker();
    } else if (_tabController.index == 1) {
      nutritionController.refreshRecipesTab();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 48,
        clipBehavior: Clip.none,
        leading: Obx(() {
          final notificationController = Get.find<NotificationController>();
          final unreadCount = notificationController.unreadCount.value;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Image.asset('assets/images/humburger.png', width: 25.w)],
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ).paddingOnly(left: 10),
              if (unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 4,
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
          );
        }),
        title: AnimatedBuilder(
          animation: _tabController,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    _tabController.animateTo(0);
                    nutritionController.fetchNutritionTracker();
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tracker',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 16.sp,
                          color: _tabController.index == 0 ? AppColors.accent : const Color(0xFF000000),
                          fontWeight: _tabController.index == 0 ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                      if (_tabController.index == 0) Container(height: 3, width: 80, margin: const EdgeInsets.only(top: 2), color: AppColors.accent),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                GestureDetector(
                  onTap: () {
                    _tabController.animateTo(1);
                    nutritionController.refreshRecipesTab();
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Recipes',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 16.sp,
                          color: _tabController.index == 1 ? AppColors.accent : const Color(0xFF000000),
                          fontWeight: _tabController.index == 1 ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                      if (_tabController.index == 1) Container(height: 3, width: 80, margin: const EdgeInsets.only(top: 2), color: AppColors.accent),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          GestureDetector(
            onTap: () => Get.to(const PlannerScreen()),
            child: Image.asset('assets/images/calendar-222.png', width: 25.w),
          ).paddingOnly(right: 15, bottom: 10),
        ],

        centerTitle: true,
      ),
      body: TabBarView(controller: _tabController, children: [NutritionTrackerTab(), const RecipesTab()]),
    );
  }
}
