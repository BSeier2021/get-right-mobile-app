import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/views/planner/planner_screen.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/journal/workout_journal_screen.dart';
import 'package:get_right/views/tracker/run_tracker_screen.dart';
import 'package:get_right/views/home/dashboard_screen.dart';

/// Combined Journal Screen with tabs for Workout Journal and Runner Log
class CombinedJournalScreen extends StatefulWidget {
  const CombinedJournalScreen({super.key});

  @override
  State<CombinedJournalScreen> createState() => _CombinedJournalScreenState();
}

class _CombinedJournalScreenState extends State<CombinedJournalScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final HomeNavigationController _navController;
  late final Worker _journalTabWorker;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _navController = Get.find<HomeNavigationController>();
    _tabController = TabController(length: 2, vsync: this, initialIndex: _navController.journalTabIndex.value.clamp(0, 1));
    _tabController.addListener(_handleTabChange);

    // If something (e.g. dashboard quick actions) requests a specific tab, jump there.
    _journalTabWorker = ever<int>(_navController.journalTabIndex, (idx) {
      if (_isDisposed || !mounted) return;
      final target = idx.clamp(0, 1);
      if (_tabController.index != target && _tabController.indexIsChanging == false) {
        try {
          _tabController.animateTo(target);
        } catch (e) {
          debugPrint('Error animating tab: $e');
        }
      }
    });
  }

  void _handleTabChange() {
    if (_isDisposed || !mounted) return;
    // Keep controller in sync (and update UI)
    final idx = _tabController.index.clamp(0, 1);
    if (_navController.journalTabIndex.value != idx) {
      _navController.journalTabIndex.value = idx;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Color _journalTabColor({required bool isActive, required bool isRunnerLogTab}) {
    if (isActive) return AppColors.accent;
    return isRunnerLogTab ? AppColors.primaryGrayDark : AppColors.onBackground;
  }

  Widget _runnerLogHeaderScrim() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.backgroundColor.withValues(alpha: 0.97),
            AppColors.backgroundColor.withValues(alpha: 0.92),
            AppColors.backgroundColor.withValues(alpha: 0.72),
            AppColors.backgroundColor.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.45, 0.78, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tabController.removeListener(_handleTabChange);
    _journalTabWorker.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRunnerLogTab = _tabController.index == 1;

    return Container(
      color: AppColors.backgroundColor,
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        extendBodyBehindAppBar: isRunnerLogTab,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 56,
          clipBehavior: Clip.none,
          flexibleSpace: isRunnerLogTab ? _runnerLogHeaderScrim() : null,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          leading: Obx(() {
            final notificationController = Get.find<NotificationController>();
            final unreadCount = notificationController.unreadCount.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Image.asset('assets/images/humburger.png', width: 25.w),
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
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  if (!_isDisposed && mounted) {
                    try {
                      _tabController.animateTo(0);
                    } catch (e) {
                      debugPrint('Error animating to tab 0: $e');
                    }
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Workout Journal',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 16.sp,
                        color: _journalTabColor(isActive: _tabController.index == 0, isRunnerLogTab: isRunnerLogTab),
                        fontWeight: _tabController.index == 0 ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                    if (_tabController.index == 0) Container(height: 3, width: 100, margin: const EdgeInsets.only(top: 2), color: AppColors.accent),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: () {
                  if (!_isDisposed && mounted) {
                    try {
                      _tabController.animateTo(1);
                    } catch (e) {
                      debugPrint('Error animating to tab 1: $e');
                    }
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Runner Log',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 16.sp,
                        color: _journalTabColor(isActive: _tabController.index == 1, isRunnerLogTab: isRunnerLogTab),
                        fontWeight: _tabController.index == 1 ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                    if (_tabController.index == 1) Container(height: 3, width: 80, margin: const EdgeInsets.only(top: 2), color: AppColors.accent),
                  ],
                ),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            GestureDetector(
              onTap: () => Get.to(const PlannerScreen()),
              child: Image.asset('assets/images/calendar-222.png', width: 25.w),
            ).paddingOnly(right: 15, bottom: 10),
          ],
        ),

        body: !_isDisposed && mounted
            ? TabBarView(controller: _tabController, children: const [WorkoutJournalScreen(isEmbedded: true), RunTrackerScreen()])
            : const SizedBox.shrink(),
      ),
    );
  }
}
