import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_right/controllers/run_tracking_controller.dart';
import 'package:get_right/models/planned_route_model.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/gps_service.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/views/home/dashboard_screen.dart';

/// Run Tracker - GPS tracking and run history
class RunTrackerScreen extends StatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen> with AutomaticKeepAliveClientMixin {
  final RunTrackingController _trackingController = Get.put(RunTrackingController());
  final RunningLogRepository _runningLogRepo = RunningLogRepository();
  GoogleMapController? _mapController;
  // ignore: unused_field
  int _totalRuns = 0;
  // ignore: unused_field
  double _totalDistance = 0.0;
  bool _mapLoadError = false;
  bool _isMapCreated = false;
  Widget? _cachedMapWidget;
  Position? _lastCameraPosition;
  DateTime? _lastCameraUpdate;
  Worker? _plannerReloadWorker;
  Worker? _journalTabWorker;
  Worker? _runnerLogVisibilityWorker;
  MapType _mapType = MapType.normal;

  /// GoogleMap should only be created after the Runner Log tab is first shown.
  bool _isRunnerLogVisible = false;
  PlannedRouteModel? _reusedPlannedRoute;
  bool _isLoadingReusedRoute = false;
  String? _pendingPlannedRouteId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<HomeNavigationController>()) {
      final nav = Get.find<HomeNavigationController>();
      _isRunnerLogVisible = nav.journalTabIndex.value == 1;
      _plannerReloadWorker = ever<int>(nav.journalPlannerReloadNonce, (_) => _applyPlannerRunContext());
      _journalTabWorker = ever<int>(nav.journalTabIndex, (_) => _applyPlannerRunContext());
      _runnerLogVisibilityWorker = ever<int>(nav.journalTabIndex, (idx) {
        final visible = idx == 1;
        if (visible == _isRunnerLogVisible) return;
        _isRunnerLogVisible = visible;
        if (visible) {
          _onRunnerLogBecameVisible();
        }
        // Keep the GoogleMap instance alive when leaving the tab — recreating it
        // on every swipe is a major source of lag. Only pause camera updates.
        if (mounted) setState(() {});
      });
    } else {
      // Opened outside the journal tabs — map can create immediately.
      _isRunnerLogVisible = true;
    }
    _applyPlannerRunContext();
    _loadStats();
    // Controller already requests location in onInit; only retry if still missing.
    if (_trackingController.currentPosition.value == null) {
      _initializeLocation();
    }
    // Listen to position updates and update camera only (with debouncing)
    ever(_trackingController.currentPosition, (position) {
      if (!_isRunnerLogVisible) return;
      if (position != null && _mapController != null && _isMapCreated && mounted) {
        final now = DateTime.now();
        // Debounce camera updates to prevent buffer overflow (max 1 update per 500ms)
        if (_lastCameraUpdate == null ||
            _lastCameraPosition == null ||
            now.difference(_lastCameraUpdate!) > const Duration(milliseconds: 500) ||
            _hasSignificantPositionChange(position, _lastCameraPosition!)) {
          _lastCameraPosition = position;
          _lastCameraUpdate = now;
          _updateCameraPosition(position);
        }
      }
    });
  }

  void _onRunnerLogBecameVisible() {
    // Map is kept alive across tab switches; only refresh location if needed.
    if (_trackingController.currentPosition.value == null) {
      _initializeLocation();
    } else if (_mapController != null && _isMapCreated) {
      final position = _trackingController.currentPosition.value!;
      _updateCameraPosition(position);
    }
  }

  void _tearDownMapForOffstage() {
    _mapController?.dispose();
    _mapController = null;
    _isMapCreated = false;
    _cachedMapWidget = null;
  }

  /// Initialize location with proper error handling
  Future<void> _initializeLocation() async {
    try {
      final gpsService = GpsService.getInstance();

      // Check if location services are enabled
      final serviceEnabled = await gpsService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          Get.snackbar(
            'Location Disabled',
            'Please enable location services to use the Run Tracker',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 5),
            mainButton: TextButton(onPressed: () => gpsService.openLocationSettings(), child: const Text('Open Settings')),
          );
        }
        return;
      }

      // Check and request permission if needed
      var permission = await gpsService.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await gpsService.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            Get.snackbar(
              'Permission Required',
              'Location permission is required to track your runs',
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 5),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          Get.snackbar(
            'Permission Denied',
            'Please enable location permission in app settings',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 5),
            mainButton: TextButton(onPressed: () => gpsService.openAppSettings(), child: const Text('Open Settings')),
          );
        }
        return;
      }

      // Get current location
      final position = await gpsService.getCurrentLocation();
      if (position != null && mounted) {
        _trackingController.currentPosition.value = position;
        debugPrint('✅ Location initialized: ${position.latitude}, ${position.longitude}');
      } else {
        debugPrint('❌ Failed to get location');
      }
    } catch (e) {
      debugPrint('❌ Location initialization error: $e');
      if (mounted) {
        Get.snackbar('Location Error', 'Failed to initialize location: $e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 3));
      }
    }
  }

  @override
  void dispose() {
    _plannerReloadWorker?.dispose();
    _journalTabWorker?.dispose();
    _runnerLogVisibilityWorker?.dispose();
    _tearDownMapForOffstage();
    _lastCameraPosition = null;
    _lastCameraUpdate = null;
    super.dispose();
  }

  /// Check if position change is significant enough to update camera
  bool _hasSignificantPositionChange(Position newPos, Position oldPos) {
    // Update if moved more than ~10 meters
    const threshold = 0.0001; // approximately 10 meters
    return (newPos.latitude - oldPos.latitude).abs() > threshold || (newPos.longitude - oldPos.longitude).abs() > threshold;
  }

  /// Update camera position without rebuilding the map (with error handling)
  void _updateCameraPosition(position) {
    if (_mapController != null && _isMapCreated && mounted) {
      try {
        _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)));
      } catch (e) {
        debugPrint('⚠️ Camera update error: $e');
        // Don't throw, just log the error to prevent crashes
      }
    }
  }

  Future<void> _loadStats() async {
    final storageService = Get.find<StorageService>();
    final runsCount = await storageService.getTotalRunsCount();
    final distance = await storageService.getTotalDistance();
    setState(() {
      _totalRuns = runsCount;
      _totalDistance = distance;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Stack(
        children: [
          _buildMapPreview(),
          _buildMapControls(),
          if (_isLoadingReusedRoute)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(color: AppColors.accent, minHeight: 3),
            ),
          if (_reusedPlannedRoute != null) _buildReusedRouteChip(),
          _buildSelectWorkoutButton(),
        ],
      ),
    );
  }

  /// Build map preview with Google Maps - Full Screen
  Widget _buildMapPreview() {
    return Obx(() {
      final position = _trackingController.currentPosition.value;
      final hasPosition = position != null;

      // Build the map widget separately - it should never rebuild once created
      Widget mapContent;
      if (_isMapCreated && _cachedMapWidget != null) {
        // Keep the map mounted even while this tab is offstage so swipe stays smooth.
        mapContent = _cachedMapWidget!;
      } else if (!_isRunnerLogVisible) {
        // First visit still pending — show a light placeholder until the tab is opened.
        mapContent = Container(color: AppColors.surface);
      } else if (!hasPosition) {
        mapContent = Container(
          color: AppColors.surface,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.location_searching, size: 40, color: AppColors.accent),
                ),
                const SizedBox(height: 16),
                Text(
                  'Finding your location...',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3)),
              ],
            ),
          ),
        );
      } else if (_mapLoadError) {
        mapContent = _buildMapErrorState(position);
      } else {
        // Build map only once - this should only happen once
        mapContent = _buildGoogleMapWidgetOnce(position);
      }

      return SizedBox(
        height: double.infinity,
        width: double.infinity,
        child: ColoredBox(color: AppColors.surface, child: mapContent),
      );
    });
  }

  /// Build Google Map widget once and cache it to prevent buffer overflow
  Widget _buildGoogleMapWidgetOnce(position) {
    // CRITICAL: Return cached widget immediately if map is already created
    // This prevents ANY rebuilds that cause buffer overflow
    if (_isMapCreated && _cachedMapWidget != null) {
      // Don't even check _mapController here to avoid any overhead
      return _cachedMapWidget!;
    }

    // Only build if not already created
    if (_isMapCreated && _cachedMapWidget == null) {
      // Map is being created but widget not cached yet, return loading state
      return Container(
        color: AppColors.surface,
        child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    debugPrint('🗺️ Building GoogleMap widget - Position: ${position.latitude}, ${position.longitude}');

    try {
      final mapWidget = GoogleMap(
        key: ValueKey('runner_log_map_${_reusedPlannedRoute?.id ?? 'none'}'),
        initialCameraPosition: CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 15),
        polylines: _plannedRoutePolylines(),
        onMapCreated: (controller) {
          debugPrint('✅ Map created successfully');
          if (!_isMapCreated || _mapController == null) {
            _mapController = controller;
            _isMapCreated = true;
            _lastCameraPosition = position;
            if (mounted) {
              setState(() {
                _mapLoadError = false;
              });
            }
            try {
              _setMapStyle(controller);
              debugPrint('✅ Map style applied');
            } catch (e) {
              debugPrint('⚠️ Map style error: $e');
              // Style error doesn't prevent map from working
            }
            final reusedRoute = _reusedPlannedRoute;
            if (reusedRoute != null && reusedRoute.routePoints.isNotEmpty) {
              _fitMapToPlannedRoute(reusedRoute);
            }
          }
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        mapType: _mapType,
        liteModeEnabled: false, // Disable lite mode to prevent buffer issues
        buildingsEnabled: true,
        indoorViewEnabled: false,
        trafficEnabled: false,
      );

      // Cache the widget immediately (before onMapCreated fires)
      _cachedMapWidget = mapWidget;
      return mapWidget;
    } catch (e) {
      debugPrint('❌ Error building map: $e');
      // Schedule error state update for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _mapLoadError = true;
          });
        }
      });
      // Return loading state while error is being set
      return Container(
        color: AppColors.surface,
        child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
  }

  /// Build map error state with location info
  Widget _buildMapErrorState(position) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: AppColors.upcoming.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.map_outlined, size: 40, color: AppColors.upcoming),
              ),
              const SizedBox(height: 16),
              Text(
                'Map Unavailable',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please add your Google Maps API key to enable maps',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: AppColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'GPS Location Ready',
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${position.latitude.toStringAsFixed(6)}\nLng: ${position.longitude.toStringAsFixed(6)}',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _mapLoadError = false;
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () {
                      Get.snackbar(
                        'Setup Required',
                        'Please check GET_GOOGLE_MAPS_API_KEY.md for instructions',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 5),
                      );
                    },
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('How to fix?'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Set custom map style for dark theme
  void _setMapStyle(GoogleMapController controller) {
    // "Light" map - essentially disables custom styling so Google's normal light map shows.
    // If you want a pure white background, use below (but it will hide features).
    // To closely resemble Google Maps "default" light mode, just set to null or empty.
    controller.setMapStyle(null);
  }

  Widget _buildMapControls() {
    final top = MediaQuery.paddingOf(context).top + 72;
    return Positioned(
      top: top,
      right: 16,
      child: Column(
        children: [
          _mapControlButton(
            icon: Icons.my_location,
            onTap: _recenterOnUser,
          ),
          const SizedBox(height: 10),
          _mapControlButton(
            icon: Icons.layers_outlined,
            onTap: _cycleMapType,
          ),
        ],
      ),
    );
  }

  Widget _mapControlButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: AppColors.white,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: AppColors.black.withValues(alpha: 0.18),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.primaryGrayDark, size: 22),
        ),
      ),
    );
  }

  void _recenterOnUser() {
    final position = _trackingController.currentPosition.value;
    if (position == null) {
      _initializeLocation();
      return;
    }
    _updateCameraPosition(position);
  }

  void _cycleMapType() {
    setState(() {
      _mapType = switch (_mapType) {
        MapType.normal => MapType.hybrid,
        MapType.hybrid => MapType.satellite,
        _ => MapType.normal,
      };
      // MapType is baked into the cached GoogleMap — rebuild once on user toggle.
      _cachedMapWidget = null;
      _isMapCreated = false;
      _mapController = null;
    });
  }

  Widget _buildReusedRouteChip() {
    final route = _reusedPlannedRoute!;
    return Positioned(
      left: 20,
      right: 20,
      bottom: 88,
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        elevation: 2,
        shadowColor: AppColors.black.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.route, color: AppColors.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Route ready · ${(route.estimatedDistance / 1000).toStringAsFixed(2)} km',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: _clearReusedPlannedRoute,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectWorkoutButton() {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 20,
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: _openWorkoutSelection,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.onAccent,
            elevation: 4,
            shadowColor: AppColors.black.withValues(alpha: 0.25),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_run, size: 22, color: AppColors.onAccent),
              const SizedBox(width: 10),
              Text(
                'Select Workout',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.onAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWorkoutSelection() {
    final args = <String, dynamic>{};
    if (_reusedPlannedRoute != null) {
      args['plannedRoute'] = _reusedPlannedRoute;
    }
    Get.toNamed(AppRoutes.cardioLibrary, arguments: args.isEmpty ? null : args)?.then((_) {
      if (mounted) _loadStats();
    });
  }

  Set<Polyline> _plannedRoutePolylines() {
    final route = _reusedPlannedRoute;
    if (route == null || route.routePoints.isEmpty) return const {};
    return {
      Polyline(polylineId: const PolylineId('reused_planned_route'), points: route.routePoints, color: const Color(0xFF7C49E2), width: 5, geodesic: true),
    };
  }

  void _clearReusedPlannedRoute() {
    setState(() {
      _reusedPlannedRoute = null;
      _pendingPlannedRouteId = null;
      _cachedMapWidget = null;
      _isMapCreated = false;
      _mapController = null;
    });
    _trackingController.plannedRouteId = null;
  }

  Future<void> _applyPlannerRunContext() async {
    if (!Get.isRegistered<HomeNavigationController>()) return;
    final nav = Get.find<HomeNavigationController>();
    if (nav.journalTabIndex.value != 1) return;

    final routeId = nav.plannedRouteIdForSession.value ?? _pendingPlannedRouteId;
    if (!WorkoutRepository.isValidMongoId(routeId)) return;

    final trimmedId = routeId!.trim();
    if (nav.plannedRouteIdForSession.value != null) {
      nav.plannedRouteIdForSession.value = null;
    }
    _pendingPlannedRouteId = trimmedId;
    _trackingController.plannedRouteId = trimmedId;

    if (_reusedPlannedRoute?.id == trimmedId || _isLoadingReusedRoute) return;
    await _loadReusedPlannedRoute(trimmedId);
  }

  Future<void> _loadReusedPlannedRoute(String routeId) async {
    setState(() => _isLoadingReusedRoute = true);
    try {
      final route = await _runningLogRepo.fetchPlannedRouteDetail(routeId);
      if (!mounted) return;
      setState(() {
        _reusedPlannedRoute = route;
        _pendingPlannedRouteId = null;
        _isLoadingReusedRoute = false;
        _cachedMapWidget = null;
        _isMapCreated = false;
        _mapController = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitMapToPlannedRoute(route));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingReusedRoute = false);
      Get.snackbar(
        'Saved route',
        'Could not load the saved route. You can still plan a new one.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
      );
    }
  }

  Future<void> _fitMapToPlannedRoute(PlannedRouteModel route) async {
    if (route.routePoints.isEmpty || _mapController == null) return;
    try {
      final bounds = _boundsForPoints(route.routePoints);
      await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
    } catch (_) {
      /* map may not be ready yet */
    }
  }

  LatLngBounds _boundsForPoints(List<LatLng> points) {
    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points.skip(1)) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }
}
