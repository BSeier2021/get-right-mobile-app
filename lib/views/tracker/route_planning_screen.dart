import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_right/models/planned_route_model.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/services/gps_service.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Route Planning Screen - Allow users to plan routes before running
class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({super.key});

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  GoogleMapController? _mapController;
  final GpsService _gpsService = GpsService.getInstance();

  final List<LatLng> _routePoints = [];
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  double _totalDistance = 0.0;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isSavingRoute = false;
  final RunningLogRepository _runningLogRepo = RunningLogRepository();

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    final position = await _gpsService.getCurrentLocation();
    if (mounted) {
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Add point to route
  void _addRoutePoint(LatLng point) {
    setState(() {
      _routePoints.add(point);

      // Update distance calculation
      if (_routePoints.length > 1) {
        final lastPoint = _routePoints[_routePoints.length - 2];
        final distance = _gpsService.calculateDistance(startLat: lastPoint.latitude, startLng: lastPoint.longitude, endLat: point.latitude, endLng: point.longitude);
        _totalDistance += distance;
      }

      // Update markers
      _updateMarkers();

      // Update polyline
      _updatePolyline();
    });
  }

  /// Update markers
  void _updateMarkers() {
    _markers.clear();

    for (int i = 0; i < _routePoints.length; i++) {
      final point = _routePoints[i];
      BitmapDescriptor icon;
      String label;

      if (i == 0) {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
        label = 'Start';
      } else if (i == _routePoints.length - 1) {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
        label = 'Finish';
      } else {
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
        label = 'Point ${i + 1}';
      }

      _markers.add(
        Marker(
          markerId: MarkerId('point_$i'),
          position: point,
          icon: icon,
          infoWindow: InfoWindow(title: label),
          draggable: true,
          onDragEnd: (newPosition) => _updatePointPosition(i, newPosition),
        ),
      );
    }
  }

  /// Update point position when dragged
  void _updatePointPosition(int index, LatLng newPosition) {
    setState(() {
      _routePoints[index] = newPosition;
      _recalculateDistance();
      _updateMarkers();
      _updatePolyline();
    });
  }

  /// Recalculate total distance
  void _recalculateDistance() {
    _totalDistance = 0.0;
    for (int i = 1; i < _routePoints.length; i++) {
      final distance = _gpsService.calculateDistance(
        startLat: _routePoints[i - 1].latitude,
        startLng: _routePoints[i - 1].longitude,
        endLat: _routePoints[i].latitude,
        endLng: _routePoints[i].longitude,
      );
      _totalDistance += distance;
    }
  }

  /// Update polyline
  void _updatePolyline() {
    _polylines.clear();
    if (_routePoints.length > 1) {
      _polylines.add(
        Polyline(polylineId: const PolylineId('planned_route'), points: _routePoints, color: AppColors.accent, width: 5, patterns: [PatternItem.dash(20), PatternItem.gap(10)]),
      );
    }
  }

  /// Clear route
  void _clearRoute() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Route?', style: AppTextStyles.titleLarge.copyWith()),
        content: Text('This will remove all points from your planned route.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGray)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _routePoints.clear();
                _markers.clear();
                _polylines.clear();
                _totalDistance = 0.0;
              });
              Get.back();
            },
            child: Text('Clear', style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  /// Save planned route to backend (`POST /customer/planned-routes`) and local storage.
  Future<void> _saveRoute() async {
    if (_routePoints.isEmpty) {
      Get.snackbar('No Route', 'Please add at least one point to your route', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: AppColors.white);
      return;
    }
    if (_isSavingRoute) return;

    setState(() => _isSavingRoute = true);

    try {
      final estimatedTimeSeconds = (_totalDistance / 1000 * 6 * 60).round();
      final route = await _runningLogRepo.savePlannedRouteFromMapPoints(
        points: List<LatLng>.from(_routePoints),
        estimatedDistanceMeters: _totalDistance,
        estimatedTimeSeconds: estimatedTimeSeconds,
      );

      final storageService = Get.find<StorageService>();
      await storageService.addPlannedRoute(route);

      if (!mounted) return;
      Get.back(result: route);
      Get.snackbar('Route Saved', 'Your planned route has been saved', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.completed, colorText: AppColors.white);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Could not save route',
        e.toString().replaceFirst('Exception: ', ''),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    } finally {
      if (mounted) setState(() => _isSavingRoute = false);
    }
  }

  /// Start run with this route
  void _startRunWithRoute() {
    if (_routePoints.isEmpty) {
      Get.snackbar('No Route', 'Please add at least one point to your route', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: AppColors.white);
      return;
    }

    final route = PlannedRouteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Active Route',
      routePoints: _routePoints,
      estimatedDistance: _totalDistance,
      createdAt: DateTime.now(),
    );

    // Navigate directly to live tracking screen with this planned route
    Get.toNamed(AppRoutes.runTracking, arguments: {'plannedRoute': route, 'activityType': 'run'});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.onPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text('Plan Route', style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent)),
        centerTitle: true,
        actions: [
          if (_routePoints.isNotEmpty)
            TextButton(
              onPressed: _clearRoute,
              child: Text('Clear', style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : Stack(
              children: [
                // Map
                _buildMap(),

                // Instructions overlay (top)
                _buildInstructions(),

                // Bottom sheet card (distance + actions)
                _buildBottomSheetCard(),
              ],
            ),
    );
  }

  /// Build map
  Widget _buildMap() {
    final initialPosition = _currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : const LatLng(37.7749, -122.4194); // Default to SF

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialPosition, zoom: 15),
      onMapCreated: (controller) {
        _mapController = controller;
        _setMapStyle(controller);
      },
      onTap: _addRoutePoint,
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );
  }

  void _setMapStyle(GoogleMapController controller) {
    // "Light" map - essentially disables custom styling so Google's normal light map shows.
    // If you want a pure white background, use below (but it will hide features).
    // To closely resemble Google Maps "default" light mode, just set to null or empty.
    controller.setMapStyle(null);
  }

  /// Build instructions overlay
  Widget _buildInstructions() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.accent.withOpacity(0.9), width: 1.2),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.25), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Icon(Icons.gps_fixed, color: AppColors.white, size: 16),

            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _routePoints.isEmpty ? 'Tap to add start point and end point' : 'Tap to add more points • Drag markers to adjust',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDistanceCard() {
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 2),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Text('Route Distance', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (_totalDistance / 1000).toStringAsFixed(2),
                  style: AppTextStyles.headlineLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 42),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 6),
                  child: Text(
                    'km',
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (_routePoints.length > 1) ...[
              const SizedBox(height: 8),
              Text(
                '${_routePoints.length} points • Est. ${(_totalDistance / 1000 * 6).toStringAsFixed(0)} min',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildActionButtons() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Save Route button
            Expanded(
              child: SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _saveRoute,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _routePoints.isEmpty ? AppColors.primaryGray : AppColors.accent, width: 2),
                    foregroundColor: _routePoints.isEmpty ? AppColors.primaryGray : AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    backgroundColor: AppColors.black.withOpacity(0.7),
                  ),
                  icon: const Icon(Icons.save_outlined, size: 24),
                  label: Text('Save', style: AppTextStyles.buttonLarge.copyWith(color: _routePoints.isEmpty ? AppColors.primaryGray : AppColors.accent)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _startRunWithRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _routePoints.isEmpty ? AppColors.primaryGray : AppColors.accent,
                    foregroundColor: AppColors.onAccent,
                    disabledBackgroundColor: AppColors.primaryGray,
                    elevation: 4,
                    shadowColor: AppColors.accent.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 20),
                      const SizedBox(width: 2),
                      Text('Start', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onAccent)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet style card (distance + actions)
  Widget _buildBottomSheetCard() {
    String _formatHmsFromDistance(double meters) {
      final seconds = (meters / 1000 * 6 * 60).round();
      final h = (seconds ~/ 3600).toString().padLeft(2, '0');
      final m = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
      final s = (seconds % 60).toString().padLeft(2, '0');
      return '$h:$m:$s';
    }

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 10),
              Text(
                'Route Distance',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _formatHmsFromDistance(_totalDistance),
                style: AppTextStyles.headlineLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 42),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSavingRoute ? null : _saveRoute,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.onAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          elevation: 0,
                        ),
                        icon: _isSavingRoute
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                            : const Icon(Icons.save, size: 20, color: AppColors.white),
                        label: Text(_isSavingRoute ? 'Saving...' : 'Save', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onAccent)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _startRunWithRoute,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primaryGray, width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          foregroundColor: AppColors.onSurface,
                          backgroundColor: Colors.transparent,
                        ),
                        icon: SvgPicture.asset('assets/icons/play.svg', width: 20, height: 20, color: AppColors.onSurface),

                        label: Text('Start', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onSurface)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
