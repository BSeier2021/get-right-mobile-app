import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/services/gps_service.dart';
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
  GoogleMapController? _headerMapController;
  Position? _currentPosition;
  bool _isMapInitialized = false;

  @override
  void initState() {
    super.initState();
    _navController = Get.find<HomeNavigationController>();
    _tabController = TabController(length: 2, vsync: this, initialIndex: _navController.journalTabIndex.value.clamp(0, 1));
    _tabController.addListener(() {
      // Keep controller in sync (and update UI)
      final idx = _tabController.index.clamp(0, 1);
      if (_navController.journalTabIndex.value != idx) {
        _navController.journalTabIndex.value = idx;
      }
      // Initialize map when switching to Runner Log tab
      if (idx == 1 && !_isMapInitialized) {
        _initializeMap();
      }
      setState(() {});
    });

    // Initialize map if starting on Runner Log tab
    if (_tabController.index == 1) {
      _initializeMap();
    }

    // If something (e.g. dashboard quick actions) requests a specific tab, jump there.
    _journalTabWorker = ever<int>(_navController.journalTabIndex, (idx) {
      if (!mounted) return;
      final target = idx.clamp(0, 1);
      if (_tabController.index != target) {
        _tabController.animateTo(target);
      }
    });
  }

  Future<void> _initializeMap() async {
    if (_isMapInitialized) return;

    try {
      final gpsService = GpsService.getInstance();
      final position = await gpsService.getCurrentLocation();
      if (mounted && position != null) {
        setState(() {
          _currentPosition = position;
          _isMapInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error getting position for header map: $e');
    }
  }

  @override
  void dispose() {
    _journalTabWorker.dispose();
    _tabController.dispose();
    _headerMapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRunnerLogTab = _tabController.index == 1;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFD6D6D6), Color(0xFFE8E8E8), Color(0xFFC0C0C0)]),
      ),
      child: Scaffold(
        backgroundColor: AppColors.background,
        extendBodyBehindAppBar: isRunnerLogTab,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 56,
          clipBehavior: Clip.none,
          flexibleSpace: isRunnerLogTab && _currentPosition != null
              ? Stack(
                  children: [
                    // Map background
                    Positioned.fill(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude), zoom: 13),
                        onMapCreated: (controller) {
                          _headerMapController = controller;
                        },
                        myLocationEnabled: false,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        liteModeEnabled: false,
                        buildingsEnabled: true,
                        trafficEnabled: false,
                        zoomGesturesEnabled: false,
                        scrollGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                      ),
                    ),
                    // Gradient overlay for better text visibility
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.1), Colors.transparent],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ],
                )
              : null,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isRunnerLogTab ? Brightness.light : Brightness.dark,
            statusBarBrightness: isRunnerLogTab ? Brightness.dark : Brightness.light,
          ),
          leading: Obx(() {
            final notificationController = Get.find<NotificationController>();
            final unreadCount = notificationController.unreadCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Image.asset('assets/images/humburger.png'),
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
                onTap: () => _tabController.animateTo(0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Workout Journal',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 16.sp,
                        color: _tabController.index == 0 ? AppColors.accent : const Color(0xFF000000),
                        fontWeight: _tabController.index == 0 ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                    if (_tabController.index == 0) Container(height: 3, width: 100, margin: const EdgeInsets.only(top: 2), color: AppColors.accent),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              GestureDetector(
                onTap: () => _tabController.animateTo(1),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Runner Log',
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
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month, color: AppColors.accent),
              onPressed: () {
                Get.toNamed('/planner');
              },
            ),
          ],
          centerTitle: true,
        ),
        body: TabBarView(controller: _tabController, children: const [WorkoutJournalScreen(isEmbedded: true), RunTrackerScreen()]),
      ),
    );
  }
}
