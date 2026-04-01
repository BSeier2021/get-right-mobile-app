import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_right/models/planned_route_model.dart';
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

  /// Save planned route
  Future<void> _saveRoute() async {
    if (_routePoints.isEmpty) {
      Get.snackbar('No Route', 'Please add at least one point to your route', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: AppColors.white);
      return;
    }

    final route = PlannedRouteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Planned Route ${DateTime.now().toString().substring(0, 16)}',
      routePoints: _routePoints,
      estimatedDistance: _totalDistance,
      createdAt: DateTime.now(),
      isSaved: true,
    );

    // Save to storage
    final storageService = Get.find<StorageService>();
    final saved = await storageService.addPlannedRoute(route);

    if (saved) {
      Get.back(result: route);
      Get.snackbar('Route Saved', 'Your planned route has been saved', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.completed, colorText: AppColors.white);
    } else {
      Get.snackbar('Error', 'Failed to save route', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: AppColors.white);
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

    // Return to activity type screen with route
    Get.back(result: route);
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

                // Distance card (bottom)
                _buildDistanceCard(),

                // Action buttons
                _buildActionButtons(),
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
          color: AppColors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.touch_app, color: AppColors.accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _routePoints.isEmpty ? 'Tap to add start point' : 'Tap to add more points • Drag markers to adjust',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build distance card
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

  /// Build action buttons
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
}
