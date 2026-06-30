import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/routes/app_routes.dart';

/// Live Run Tracking Screen
/// Real-time tracking during run/walk/bike activity
class LiveRunTrackingScreen extends StatefulWidget {
  const LiveRunTrackingScreen({super.key});

  @override
  State<LiveRunTrackingScreen> createState() => _LiveRunTrackingScreenState();
}

class _LiveRunTrackingScreenState extends State<LiveRunTrackingScreen> {
  GoogleMapController? _mapController;
  String _activityType = 'Run';
  bool _isTracking = false;
  bool _isPaused = false;
  bool _isLocked = false;
  Timer? _timer;

  // Tracking data
  int _seconds = 0;
  double _distanceMeters = 0;
  double _currentPace = 0;
  double _averagePace = 0;
  int _calories = 0;
  List<LatLng> _routePoints = [];
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      _activityType = args['activityType'] ?? 'Run';
    }
    _startTracking();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startTracking() {
    setState(() {
      _isTracking = true;
      _isPaused = false;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _seconds++;
          // Simulate tracking data
          _distanceMeters += 2.5; // ~150m/min = 9km/h
          _currentPace = _distanceMeters > 0 ? (_seconds / 60) / (_distanceMeters / 1000) : 0;
          _averagePace = _distanceMeters > 0 ? (_seconds / 60) / (_distanceMeters / 1000) : 0;
          _calories = (_seconds / 60 * 8).round(); // ~8 cal/min for running
        });
      }
    });
  }

  void _pauseTracking() {
    setState(() => _isPaused = true);
  }

  void _resumeTracking() {
    setState(() => _isPaused = false);
  }

  void _endActivity() {
    _timer?.cancel();

    final endTime = DateTime.now();
    final startTime = endTime.subtract(Duration(seconds: _seconds));
    final routePoints = _routePoints
        .map((p) => LocationPoint(latitude: p.latitude, longitude: p.longitude, timestamp: endTime))
        .toList();

    final run = RunModel(
      id: 'run_${DateTime.now().millisecondsSinceEpoch}',
      userId: 'user_1',
      activityType: _activityType,
      distanceMeters: _distanceMeters,
      duration: Duration(seconds: _seconds),
      startTime: startTime,
      endTime: endTime,
      routePoints: routePoints.isEmpty ? null : routePoints,
      averagePace: _averagePace,
      maxPace: _currentPace,
      caloriesBurned: _calories,
      createdAt: endTime,
    );

    // Navigate to post-run summary (pop this screen then push so home stays in stack)
    Get.back();
    Get.toNamed(AppRoutes.runDetail, arguments: run);
  }

  void _toggleLock() {
    setState(() => _isLocked = !_isLocked);
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    if (hours > 0) {
      return '${hours}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    final km = meters / 1000;
    return km.toStringAsFixed(2);
  }

  String _formatPace(double pace) {
    if (pace == 0) return '--:--';
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map View
          _buildMapView(),

          // Metrics Overlay
          if (!_isLocked) _buildMetricsOverlay(),

          // Control Buttons
          if (!_isLocked) _buildControlButtons(),

          // Lock Screen Overlay
          if (_isLocked) _buildLockOverlay(),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(37.7749, -122.4194), // San Francisco default
        zoom: 15,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      polylines: {if (_routePoints.isNotEmpty) Polyline(polylineId: const PolylineId('route'), points: _routePoints, color: AppColors.accent, width: 4)},
    );
  }

  Widget _buildMetricsOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              // Activity Type Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Icon(_getActivityIcon(), color: AppColors.accent, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _activityType,
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.onSurface),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Main Metrics Grid
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(label: 'Time', value: _formatTime(_seconds), icon: Icons.timer_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricItem(label: 'Distance', value: '${_formatDistance(_distanceMeters)} km', icon: Icons.straighten),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(label: 'Current Pace', value: '${_formatPace(_currentPace)}/km', icon: Icons.speed),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricItem(label: 'Avg Pace', value: '${_formatPace(_averagePace)}/km', icon: Icons.show_chart),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(label: 'Calories', value: '$_calories cal', icon: Icons.local_fire_department, iconColor: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricItem({required String label, required String value, required IconData icon, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primaryGrayLight.withOpacity(0.3), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor ?? AppColors.accent, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: AppColors.secondary.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, -4))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Lock Button
              _buildControlButton(icon: Icons.lock_outline, label: 'Lock', color: AppColors.primaryGrayDark, onTap: _toggleLock),

              // Pause/Resume Button
              _buildControlButton(
                icon: _isPaused ? Icons.play_arrow : Icons.pause,
                label: _isPaused ? 'Resume' : 'Pause',
                color: _isPaused ? AppColors.accent : Colors.orange,
                onTap: _isPaused ? _resumeTracking : _pauseTracking,
                isLarge: true,
              ),

              // End Button
              _buildControlButton(icon: Icons.stop, label: 'End', color: Colors.red, onTap: _showEndConfirmation),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required Color color, required VoidCallback onTap, bool isLarge = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isLarge ? 72 : 56,
            height: isLarge ? 72 : 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: isLarge ? 36 : 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLockOverlay() {
    return GestureDetector(
      onTap: _toggleLock,
      child: Container(
        color: AppColors.secondary.withOpacity(0.8),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                ),
                child: const Icon(Icons.lock, size: 48, color: AppColors.accent),
              ),
              const SizedBox(height: 24),
              Text(
                'Screen Locked',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Tap to unlock', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayLight)),
            ],
          ),
        ),
      ),
    );
  }

  void _showEndConfirmation() {
    Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stop_circle_outlined, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'End Activity?',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your progress will be saved',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primaryGray, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Cancel', style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onBackground)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        _endActivity();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('End Run', style: AppTextStyles.buttonMedium),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getActivityIcon() {
    switch (_activityType) {
      case 'Walk':
        return Icons.directions_walk;
      case 'Jog':
        return Icons.directions_walk_outlined;
      case 'Bike':
        return Icons.directions_bike;
      default:
        return Icons.directions_run;
    }
  }
}
