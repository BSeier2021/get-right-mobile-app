import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/run_tracking_controller.dart';
import 'package:get_right/models/planned_route_model.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Active Run Screen - Live GPS tracking with map and stats
class ActiveRunScreen extends StatefulWidget {
  const ActiveRunScreen({super.key});

  @override
  State<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends State<ActiveRunScreen> with SingleTickerProviderStateMixin {
  late final RunTrackingController _controller;
  final RunningLogRepository _runningLogRepo = RunningLogRepository();
  final Rxn<PlannedRouteModel> _plannedRouteRx = Rxn<PlannedRouteModel>();
  GoogleMapController? _mapController;
  late AnimationController _pulseController;
  Timer? _mapUpdateTimer;
  bool _isLocked = false;
  bool _followUserOnMap = true;
  PlannedRouteModel? _plannedRoute;

  PlannedRouteModel? get _activePlannedRoute => _plannedRouteRx.value ?? _plannedRoute;

  @override
  void initState() {
    super.initState();
    // Initialize controller (put if doesn't exist, find if it does)
    _controller = Get.put(RunTrackingController(), permanent: false);
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    // Load args, apply planned route, then start tracking once.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeRun());

    _startMapUpdates();
  }

  PlannedRouteModel? _parsePlannedRouteFromArgs(Map<String, dynamic>? args) {
    if (args == null) return null;
    final raw = args['plannedRoute'];
    if (raw is PlannedRouteModel) return raw;
    if (raw is Map) {
      try {
        return PlannedRouteModel.fromJson(Map<String, dynamic>.from(raw));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<PlannedRouteModel?> _resolvePlannedRoute(PlannedRouteModel? route) async {
    if (route == null) return null;
    if (route.routePoints.isNotEmpty) return route;
    if (!WorkoutRepository.isValidMongoId(route.id)) return route;

    try {
      return await _runningLogRepo.fetchPlannedRouteDetail(route.id);
    } catch (e) {
      if (mounted) {
        Get.snackbar('Saved route', 'Could not load route points. Showing your live track only.', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 3));
      }
      return route;
    }
  }

  Future<void> _initializeRun() async {
    if (!mounted) return;

    final args = Get.arguments as Map<String, dynamic>?;
    var plannedRoute = _parsePlannedRouteFromArgs(args);
    String? plannedRouteId;

    if (args != null && args['activityType'] != null) {
      _controller.activityType.value = args['activityType'].toString();
    }

    if (plannedRoute != null) {
      plannedRoute = await _resolvePlannedRoute(plannedRoute);
      if (WorkoutRepository.isValidMongoId(plannedRoute?.id)) {
        plannedRouteId = plannedRoute!.id;
      }
    }

    if (!_controller.isTracking.value) {
      _controller.runStatus.value = 'Ready';
    }

    if (plannedRoute != null) {
      _applyPlannedRoute(plannedRoute, routeId: plannedRouteId);
    }

    if (!_controller.isTracking.value) {
      await _controller.startTracking(activity: _controller.activityType.value, plannedRouteId: plannedRouteId);
    }

    if (plannedRoute != null) {
      _scheduleMapFit();
    }
  }

  void _applyPlannedRoute(PlannedRouteModel route, {String? routeId}) {
    setState(() {
      _plannedRoute = route;
      _followUserOnMap = false;
    });
    _plannedRouteRx.value = route;
    _controller.plannedRouteId = routeId ?? (WorkoutRepository.isValidMongoId(route.id) ? route.id : _controller.plannedRouteId);
  }

  void _scheduleMapFit() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fitMapToRouteAndUser();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapUpdateTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startMapUpdates() {
    _mapUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_followUserOnMap || _activePlannedRoute != null) return;
      final position = _controller.currentPosition.value;
      if (position != null && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showExitDialog();
        return false;
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          body: Stack(
            children: [
              // Map Layer
              _buildMap(),

              // Running header (like screenshot)
              if (!_isLocked) _buildRunningHeader(),

              // Bottom controls bar (Stop / Pause / Map)
              if (!_isLocked) _buildBottomControlsBar(),

              // Lock overlay (shown when locked)
              if (_isLocked) _buildLockOverlay(),

              // Corner overlay buttons on map (e.g., re-center)
              if (!_isLocked) _buildCornerButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build map with route
  Widget _buildMap() {
    return Obx(() {
      final position = _controller.currentPosition.value;
      final routePoints = _controller.routePoints;
      final plannedRoute = _activePlannedRoute;

      LatLng? mapCenter;
      if (position != null) {
        mapCenter = LatLng(position.latitude, position.longitude);
      } else if (plannedRoute != null && plannedRoute.routePoints.isNotEmpty) {
        mapCenter = plannedRoute.routePoints.first;
      }

      if (mapCenter == null) {
        return Container(
          color: AppColors.surface,
          child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        );
      }

      // Create polylines from route points and planned route
      final Set<Polyline> polylines = {};

      // Add planned route polyline
      if (plannedRoute != null && plannedRoute.routePoints.isNotEmpty) {
        polylines.add(Polyline(polylineId: const PolylineId('planned_route'), points: plannedRoute.routePoints, color: const Color(0xFF7C49E2), width: 5, geodesic: true));
      }

      // Add actual run route polyline (solid line for the path traveled)
      if (routePoints.length > 1) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('run_route'),
            points: routePoints.map((point) => LatLng(point.latitude, point.longitude)).toList(),
            color: AppColors.accent,
            width: 5,
          ),
        );
      }

      // Create markers set
      final Set<Marker> markers = {};

      // Add current position marker
      if (position != null) {
        markers.add(
          Marker(
            markerId: const MarkerId('current_position'),
            position: LatLng(position.latitude, position.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            anchor: const Offset(0.5, 0.5),
          ),
        );
      }

      // Add planned route start/end markers
      if (plannedRoute != null && plannedRoute.routePoints.isNotEmpty) {
        final startPoint = plannedRoute.routePoints.first;
        markers.add(
          Marker(
            markerId: const MarkerId('planned_route_start'),
            position: startPoint,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Route Start'),
          ),
        );

        if (plannedRoute.routePoints.length > 1) {
          final endPoint = plannedRoute.routePoints.last;
          if (endPoint.latitude != startPoint.latitude || endPoint.longitude != startPoint.longitude) {
            markers.add(
              Marker(
                markerId: const MarkerId('planned_route_end'),
                position: endPoint,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: const InfoWindow(title: 'Route End'),
              ),
            );
          }
        }
      }

      return GoogleMap(
        key: ValueKey('active_run_map_${plannedRoute?.id ?? 'none'}_${plannedRoute?.routePoints.length ?? 0}'),
        initialCameraPosition: CameraPosition(target: mapCenter, zoom: 16),
        onMapCreated: (controller) {
          _mapController = controller;
          _setMapStyle(controller);
          if (plannedRoute != null && plannedRoute.routePoints.isNotEmpty) {
            _scheduleMapFit();
          }
        },
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        polylines: polylines,
        markers: markers,
      );
    });
  }

  /// Fit camera to show planned route and current location together.
  void _fitMapToRouteAndUser() {
    if (_mapController == null) return;

    final points = <LatLng>[];
    final plannedRoute = _activePlannedRoute;
    if (plannedRoute != null && plannedRoute.routePoints.isNotEmpty) {
      points.addAll(plannedRoute.routePoints);
    }

    final position = _controller.currentPosition.value;
    if (position != null) {
      points.add(LatLng(position.latitude, position.longitude));
    }

    if (points.isEmpty) return;

    if (points.length == 1) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(points.first, 16));
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    final bounds = LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  /// Set custom map style for dark theme
  void _setMapStyle(GoogleMapController controller) {
    controller.setMapStyle(null);
  }

  /// Build top bar with status
  // ignore: unused_element
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 12, left: 12, right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.black.withOpacity(0.8), AppColors.black.withOpacity(0)]),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.white, size: 28),
              onPressed: _showExitDialog,
            ),
            Expanded(
              child: Center(
                child: Obx(() {
                  final status = _controller.runStatus.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: status == 'Paused' ? AppColors.upcoming.withOpacity(0.9) : AppColors.accent.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  /// Header card like the screenshot (Running, big timer, three mini stats)
  Widget _buildRunningHeader() {
    return Obx(() {
      final time = _controller.formatDuration(_controller.elapsedTime.value);
      final distanceKm = (_controller.distanceMeters.value / 1000).toStringAsFixed(2);
      final pace = _controller.formatPace(_controller.currentPace.value);
      final kcal = _controller.caloriesBurned.value > 0 ? _controller.caloriesBurned.value.toStringAsFixed(0) : '0';

      return Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, left: 16, right: 16, bottom: 14),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  _smallRoundButton(icon: Icons.arrow_back_ios_new_rounded, onTap: _showExitDialog),
                  const Spacer(),
                  Text(
                    'Running',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const SizedBox(width: 36),
                ],
              ),
              if (_activePlannedRoute != null && _activePlannedRoute!.routePoints.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6EAFE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF7C49E2).withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.route, color: Color(0xFF7C49E2), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activePlannedRoute!.name,
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(_activePlannedRoute!.estimatedDistance / 1000).toStringAsFixed(2)} km • ${_activePlannedRoute!.routePoints.length} points',
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                time,
                style: AppTextStyles.headlineLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 36),
              ),
              const SizedBox(height: 2),
              Text('mins', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _miniStat(value: distanceKm, label: 'km'),
                  _verticalDivider(),
                  _miniStat(value: pace, label: 'Pace (Min/km)'),
                  _verticalDivider(),
                  _miniStat(value: kcal, label: 'kcal'),
                ],
              ),
              const SizedBox(height: 4),
              Icon(Icons.keyboard_arrow_up_rounded, color: AppColors.primaryGrayDark, size: 18),
            ],
          ),
        ),
      );
    });
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 22, color: AppColors.primaryGray.withOpacity(0.35));
  }

  Widget _smallRoundButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.2), shape: BoxShape.circle),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(icon, size: 16, color: AppColors.onSurface),
        ),
      ),
    );
  }

  Widget _miniStat({required String value, required String label}) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 11)),
      ],
    );
  }

  /// Bottom controls bar like screenshot
  Widget _buildBottomControlsBar() {
    return Obx(() {
      final isPaused = _controller.isPaused.value;
      return Positioned(
        left: 0,
        right: 0,
        bottom: 20,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Stop (red)
                _roundIconButton(
                  color: AppColors.error,
                  onTap: _showStopDialog,
                  customChild: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Pause/Resume (green)
                _roundIconButton(
                  color: AppColors.accent,
                  icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  onTap: () {
                    if (isPaused) {
                      _controller.resumeTracking();
                    } else {
                      _controller.pauseTracking();
                    }
                  },
                  large: true,
                ),
                const SizedBox(width: 20),
                // Lock (grey)
                _roundIconButton(
                  color: AppColors.primaryGray,
                  icon: _isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  onTap: () {
                    setState(() {
                      _isLocked = !_isLocked;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _roundIconButton({required Color color, IconData? icon, Widget? customChild, required VoidCallback onTap, bool large = false}) {
    final double size = large ? 64 : 50;
    final double iconSize = large ? 28 : 22;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 12)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: customChild ?? Icon(icon, color: AppColors.white, size: iconSize),
        ),
      ),
    );
  }

  /// Corner overlay buttons for map (top-right re-center)
  Widget _buildCornerButtons() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      right: 12,
      child: _smallRoundButton(
        icon: Icons.my_location_rounded,
        onTap: () {
          if (_activePlannedRoute != null && _activePlannedRoute!.routePoints.isNotEmpty) {
            setState(() => _followUserOnMap = false);
            _fitMapToRouteAndUser();
            return;
          }
          final position = _controller.currentPosition.value;
          if (position != null && _mapController != null) {
            setState(() => _followUserOnMap = true);
            _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)));
          }
        },
      ),
    );
  }

  /// Build stats overlay (for Stack positioning)
  // ignore: unused_element
  Widget _buildStatsOverlay() {
    return Positioned(top: MediaQuery.of(context).padding.top + 80, left: 16, right: 16, child: _buildStatsContent());
  }

  /// Build stats content (without Positioned wrapper, for use in Column)
  Widget _buildStatsContent() {
    return Obx(() {
      return Column(
        children: [
          // Main stat cards - Row 1
          Row(
            children: [
              Expanded(child: _buildStatCard('Distance', _controller.formatDistance(_controller.distanceMeters.value), Icons.straighten_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Time', _controller.formatDuration(_controller.elapsedTime.value), Icons.timer_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2
          Row(
            children: [
              Expanded(child: _buildStatCard('Pace', '${_controller.formatPace(_controller.currentPace.value)}/km', Icons.speed_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Avg Pace', '${_controller.formatPace(_controller.averagePace.value)}/km', Icons.insights_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          // Row 3
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Calories', _controller.caloriesBurned.value > 0 ? '${_controller.caloriesBurned.value} cal' : '--', Icons.local_fire_department_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Elevation', _controller.formatElevation(_controller.elevationGain.value), Icons.terrain_rounded)),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(color: AppColors.lightGrey, blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 18),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.labelMedium.copyWith(color: AppColors.black, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build bottom sheet with controls
  // ignore: unused_element
  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.25,
      minChildSize: 0.25,
      maxChildSize: 0.6,
      builder: (context, scrollController) {
        return Obx(() {
          final isTracking = _controller.isTracking.value;
          final isPaused = _controller.isPaused.value;
          final activityType = _controller.activityType.value;

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -5))],
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        children: [
                          // Activity type and status
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activityType,
                                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(isTracking ? 'Active workout' : 'Tap to start your workout', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark)),
                                  ],
                                ),
                              ),
                              if (isTracking)
                                Obx(() {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                                    child: Text(
                                      _controller.formatDuration(_controller.elapsedTime.value),
                                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                }),
                            ],
                          ),
                          15.h.verticalSpace,
                          // Control buttons
                          if (!isTracking)
                            _buildStartButton()
                          else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Stop button
                                _buildControlButton(icon: Icons.stop_rounded, label: 'Stop', color: AppColors.error, onPressed: _showStopDialog),
                                const SizedBox(width: 20),
                                // Pause/Resume button
                                _buildControlButton(
                                  icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                  label: isPaused ? 'Resume' : 'Pause',
                                  color: isPaused ? AppColors.accent : AppColors.upcoming,
                                  onPressed: () {
                                    if (isPaused) {
                                      _controller.resumeTracking();
                                    } else {
                                      _controller.pauseTracking();
                                    }
                                  },
                                  isLarge: true,
                                ),
                                const SizedBox(width: 20),
                                // Lock button
                                _buildControlButton(
                                  icon: _isLocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                                  label: _isLocked ? 'Unlock' : 'Lock',
                                  color: _isLocked ? AppColors.accent : AppColors.primaryGray,
                                  onPressed: () {
                                    setState(() {
                                      _isLocked = !_isLocked;
                                    });
                                  },
                                ),
                              ],
                            ),
                            15.h.verticalSpace,
                            _buildStatsContent(),
                          ],

                          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  // ignore: unused_element
  Widget _buildBottomSheetStat(String label, String value, {bool showHeart = false}) {
    return Column(
      children: [
        if (showHeart)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite, color: Colors.red, size: 16),
              const SizedBox(width: 4),
            ],
          ),
        Text(
          value,
          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontSize: 11)),
      ],
    );
  }

  /// Build Start button
  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () async {
          final success = await _controller.startTracking(activity: _controller.activityType.value);
          if (!success) {
            Get.snackbar('Error', 'Failed to start tracking', snackPosition: SnackPosition.BOTTOM);
          }
        },
        icon: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: AppColors.onAccent, shape: BoxShape.circle),
          child: Icon(Icons.play_arrow, color: AppColors.accent, size: 18),
        ),
        label: Text('Start', style: AppTextStyles.buttonLarge),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required Color color, required VoidCallback onPressed, bool isLarge = false}) {
    final size = isLarge ? 75.0 : 65.0;
    final iconSize = isLarge ? 36.0 : 28.0;

    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.white, width: 3),
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Icon(icon, color: AppColors.white, size: iconSize),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: AppColors.black.withOpacity(0.8), blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  /// Show exit confirmation dialog
  void _showExitDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Discard Run?', style: AppTextStyles.titleLarge.copyWith()),
        content: Text('Are you sure you want to exit without saving this run?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGray)),
          ),
          TextButton(
            onPressed: () {
              _controller.cancelTracking();
              if (!mounted) return;
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Back to tracker
            },
            child: Text('Discard', style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  /// Show stop confirmation dialog
  void _showStopDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Finish Run?', style: AppTextStyles.titleLarge.copyWith()),
        content: Text('Do you want to save this run?', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGray)),
          ),
          TextButton(
            onPressed: () async {
              _controller.logPlannedRouteSavePayloadPreview();
              final run = await _controller.stopTracking();
              if (!mounted) return;
              // Use Navigator — Get.back() can assert when closing a snackbar already disposed by route pop.
              Navigator.of(context).pop(); // Close dialog
              if (run != null) {
                Navigator.of(context).pop(); // Leave active run screen
                Get.toNamed(AppRoutes.runDetail, arguments: run);
              } else {
                Navigator.of(context).pop(); // Back to tracker
              }
            },
            child: Text('Save', style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  /// Build lock overlay - shows minimal stats when screen is locked
  Widget _buildLockOverlay() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isLocked = false;
        });
      },
      child: Container(
        color: AppColors.black,
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lock icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryGray.withOpacity(0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 2),
                ),
                child: Icon(Icons.lock_rounded, color: AppColors.accent, size: 48),
              ),
              const SizedBox(height: 32),

              // Minimal stats display
              Obx(() {
                return Column(
                  children: [
                    // Time (large)
                    Text(
                      _controller.formatDuration(_controller.elapsedTime.value),
                      style: AppTextStyles.headlineLarge.copyWith(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 64),
                    ),
                    const SizedBox(height: 24),

                    // Distance and Pace
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLockStat('Distance', _controller.formatDistance(_controller.distanceMeters.value)),
                        const SizedBox(width: 32),
                        _buildLockStat('Pace', '${_controller.formatPace(_controller.currentPace.value)}/km'),
                        const SizedBox(width: 32),
                        _buildLockStat('Cal', _controller.caloriesBurned.value > 0 ? '${_controller.caloriesBurned.value}' : '--'),
                      ],
                    ),
                  ],
                );
              }),

              const SizedBox(height: 48),

              // Unlock hint
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.touch_app_rounded, color: AppColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tap to unlock',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
      ],
    );
  }
}
