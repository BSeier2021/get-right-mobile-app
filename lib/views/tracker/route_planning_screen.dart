import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_right/models/planned_route_model.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/gps_service.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/widgets/common/custom_text_field.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum _RouteEndpoint { start, end }

/// Route Planning Screen - plan a route with searchable or map-tapped start/end points.
class RoutePlanningScreen extends StatefulWidget {
  const RoutePlanningScreen({super.key});

  @override
  State<RoutePlanningScreen> createState() => _RoutePlanningScreenState();
}

class _RoutePlanningScreenState extends State<RoutePlanningScreen> {
  GoogleMapController? _mapController;
  final GpsService _gpsService = GpsService.getInstance();

  final TextEditingController _startSearchController = TextEditingController();
  final TextEditingController _endSearchController = TextEditingController();

  final List<LatLng> _routePoints = [];
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  LatLng? _startPoint;
  LatLng? _endPoint;
  _RouteEndpoint _activeEndpoint = _RouteEndpoint.start;

  double _totalDistance = 0.0;
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isSavingRoute = false;
  bool _isSearching = false;

  Timer? _searchDebounce;
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
    _searchDebounce?.cancel();
    _startSearchController.dispose();
    _endSearchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  bool get _hasCompleteRoute => _startPoint != null && _endPoint != null;

  void _syncRoutePoints() {
    _routePoints
      ..clear()
      ..addAll([if (_startPoint != null) _startPoint!, if (_endPoint != null) _endPoint!]);
    _recalculateDistance();
    _updateMarkers();
    _updatePolyline();
  }

  void _setStartPoint(LatLng point, {String? label}) {
    setState(() {
      _startPoint = point;
      if (label != null && label.trim().isNotEmpty) {
        _startSearchController.text = label.trim();
      }
      _syncRoutePoints();
    });
  }

  void _setEndPoint(LatLng point, {String? label}) {
    setState(() {
      _endPoint = point;
      if (label != null && label.trim().isNotEmpty) {
        _endSearchController.text = label.trim();
      }
      _syncRoutePoints();
    });
  }

  void _onMapTap(LatLng point) {
    FocusScope.of(context).unfocus();
    if (_activeEndpoint == _RouteEndpoint.start) {
      _setStartPoint(point);
      _reverseGeocode(point, isStart: true);
      if (_endPoint == null) setState(() => _activeEndpoint = _RouteEndpoint.end);
    } else {
      _setEndPoint(point);
      _reverseGeocode(point, isStart: false);
    }
    _animateToPoint(point);
  }

  Future<void> _reverseGeocode(LatLng point, {required bool isStart}) async {
    try {
      final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isEmpty || !mounted) return;
      final p = placemarks.first;
      final parts = <String>[
        if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
        if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        if ((p.administrativeArea ?? '').trim().isNotEmpty) p.administrativeArea!.trim(),
      ];
      final label = parts.isNotEmpty ? parts.join(', ') : '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
      if (!mounted) return;
      setState(() {
        if (isStart) {
          _startSearchController.text = label;
        } else {
          _endSearchController.text = label;
        }
      });
    } catch (_) {
      /* keep coordinates-only label from map tap */
    }
  }

  void _scheduleSearch(String query, {required bool isStart}) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) return;
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _searchLocation(query, isStart: isStart, moveCamera: true);
    });
  }

  Future<void> _searchLocation(String query, {required bool isStart, bool moveCamera = true}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isSearching = true);
    try {
      final locations = await locationFromAddress(trimmed);
      if (locations.isEmpty) {
        Get.snackbar(
          'Location not found',
          'Try a different address or tap the map to set this point.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppColors.error,
          colorText: AppColors.white,
        );
        return;
      }

      final loc = locations.first;
      final point = LatLng(loc.latitude, loc.longitude);
      if (isStart) {
        _setStartPoint(point, label: trimmed);
        if (_endPoint == null) setState(() => _activeEndpoint = _RouteEndpoint.end);
      } else {
        _setEndPoint(point, label: trimmed);
      }
      if (moveCamera) _animateToPoint(point);
    } catch (_) {
      Get.snackbar(
        'Location not found',
        'Could not find "$trimmed". Tap the map or try another search.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _useCurrentLocationAsStart() async {
    setState(() => _activeEndpoint = _RouteEndpoint.start);
    final position = _currentPosition ?? await _gpsService.getCurrentLocation();
    if (position == null) {
      Get.snackbar(
        'Location unavailable',
        'Enable location services to use your current position.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
      return;
    }

    if (mounted) {
      setState(() => _currentPosition = position);
    }
    final point = LatLng(position.latitude, position.longitude);
    _setStartPoint(point);
    await _reverseGeocode(point, isStart: true);
    if (_endPoint == null && mounted) setState(() => _activeEndpoint = _RouteEndpoint.end);
    _animateToPoint(point);
  }

  void _animateToPoint(LatLng point) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(point, 15));
  }

  void _updateMarkers() {
    _markers.clear();

    if (_startPoint != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: _startPoint!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
          draggable: true,
          onDragEnd: (newPosition) {
            _setStartPoint(newPosition);
            _reverseGeocode(newPosition, isStart: true);
          },
        ),
      );
    }

    if (_endPoint != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: _endPoint!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Finish'),
          draggable: true,
          onDragEnd: (newPosition) {
            _setEndPoint(newPosition);
            _reverseGeocode(newPosition, isStart: false);
          },
        ),
      );
    }
  }

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

  void _updatePolyline() {
    _polylines.clear();
    if (_routePoints.length > 1) {
      _polylines.add(
        Polyline(polylineId: const PolylineId('planned_route'), points: _routePoints, color: AppColors.accent, width: 5, patterns: [PatternItem.dash(20), PatternItem.gap(10)]),
      );
    }
  }

  void _clearRoute() {
    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Route?', style: AppTextStyles.titleLarge.copyWith()),
        content: Text('This will remove your start and end locations.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGray)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _startPoint = null;
                _endPoint = null;
                _routePoints.clear();
                _markers.clear();
                _polylines.clear();
                _totalDistance = 0.0;
                _activeEndpoint = _RouteEndpoint.start;
                _startSearchController.clear();
                _endSearchController.clear();
              });
              Get.back();
            },
            child: Text('Clear', style: AppTextStyles.labelLarge.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRoute() async {
    if (!_hasCompleteRoute) {
      Get.snackbar(
        'Incomplete route',
        'Please set both a start and end location',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
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
        startName: _startSearchController.text.trim(),
        endName: _endSearchController.text.trim(),
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

  void _startRunWithRoute() {
    if (!_hasCompleteRoute) {
      Get.snackbar(
        'Incomplete route',
        'Please set both a start and end location',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
      return;
    }

    final route = PlannedRouteModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Active Route',
      routePoints: _routePoints,
      estimatedDistance: _totalDistance,
      createdAt: DateTime.now(),
      startPointName: _startSearchController.text.trim().isNotEmpty ? _startSearchController.text.trim() : null,
      endPointName: _endSearchController.text.trim().isNotEmpty ? _endSearchController.text.trim() : null,
    );

    Get.toNamed(AppRoutes.activityTypeSelection, arguments: {'plannedRoute': route});
  }

  void _selectEndpointForMap({required bool isStart}) {
    setState(() => _activeEndpoint = isStart ? _RouteEndpoint.start : _RouteEndpoint.end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
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
          if (_startPoint != null || _endPoint != null)
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
                _buildMap(),
                _buildCompactRouteBar(),
                // _buildMapHintBanner(),
                _buildBottomSheetCard(),
                if (_isSearching)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x22000000),
                      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildMap() {
    final initialPosition = _currentPosition != null ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude) : const LatLng(37.7749, -122.4194);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialPosition, zoom: 15),
      onMapCreated: (controller) {
        _mapController = controller;
        controller.setMapStyle(null);
      },
      onTap: _onMapTap,
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );
  }

  Widget _buildCompactRouteBar() {
    return Positioned(
      top: 8,
      left: 12,
      right: 12,
      child: Material(
        elevation: 5,
        shadowColor: Colors.black26,
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(mainAxisSize: MainAxisSize.min, children: [_buildCompactLocationRow(isStart: true), const SizedBox(height: 8), _buildCompactLocationRow(isStart: false)]),
        ),
      ),
    );
  }

  Widget _buildCompactLocationRow({required bool isStart}) {
    final controller = isStart ? _startSearchController : _endSearchController;
    final hint = isStart ? 'Search start or tap map' : 'Search end or tap map';

    return CustomTextField(
      controller: controller,
      hintText: hint,
      keyboardType: TextInputType.streetAddress,
      onTap: () => _selectEndpointForMap(isStart: isStart),
      onChanged: (value) => _scheduleSearch(value, isStart: isStart),
      prefixIcon: Icon(isStart ? Icons.trip_origin : Icons.location_on, size: 20),
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Search',
            onPressed: () {
              _selectEndpointForMap(isStart: isStart);
              FocusScope.of(context).unfocus();
              _searchLocation(controller.text, isStart: isStart);
            },
            icon: const Icon(Icons.search_rounded, size: 20),
          ),
          if (isStart)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Use current location',
              onPressed: _useCurrentLocationAsStart,
              icon: const Icon(Icons.my_location_rounded, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetCard() {
    String formatHmsFromDistance(double meters) {
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
                decoration: BoxDecoration(color: AppColors.background.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 10),
              Text(
                'Route Distance',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _hasCompleteRoute ? formatHmsFromDistance(_totalDistance) : '--:--:--',
                style: AppTextStyles.headlineLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900, fontSize: 42),
              ),
              if (_hasCompleteRoute) ...[
                const SizedBox(height: 4),
                Text('${(_totalDistance / 1000).toStringAsFixed(2)} km', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              ],
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
