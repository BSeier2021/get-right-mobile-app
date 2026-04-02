import 'package:flutter/material.dart' hide Split;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/helpers.dart';

/// Run Summary Screen - Display completed run with map and stats
class RunSummaryScreen extends StatefulWidget {
  const RunSummaryScreen({super.key});

  @override
  State<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends State<RunSummaryScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get run data from arguments
    final RunModel run = Get.arguments as RunModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 40.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.onPrimary),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Image.asset('assets/images/Container.png'),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Run Complete!',
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
                    ),
                    Text(DateFormat('EEEE, MMM d, yyyy').format(run.startTime), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 20),

                _buildStatsSection(run),
                const SizedBox(height: 20),
                _buildMapSection(run),

                _buildDetailedStats(run),
                if (run.splits != null && run.splits!.isNotEmpty) _buildSplitsSection(run),
                _buildActionButtons(run),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build app bar with run title

  /// Build map section with Google Maps
  Widget _buildMapSection(RunModel run) {
    if (run.routePoints == null || run.routePoints!.isEmpty) {
      return const SizedBox.shrink();
    }

    final points = run.routePoints!.map((p) => LatLng(p.latitude, p.longitude)).toList();
    final center = _calculateCenter(points);

    // Create polyline
    final Set<Polyline> polylines = {Polyline(polylineId: const PolylineId('run_route'), points: points, color: AppColors.accent, width: 5)};

    // Create markers
    final Set<Marker> markers = {
      Marker(
        markerId: const MarkerId('start'),
        position: points.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Start'),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: points.last,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Finish'),
      ),
    };

    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 14),
        onMapCreated: (controller) {
          _mapController = controller;
          _setMapStyle(controller);
        },
        polylines: polylines,
        markers: markers,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
        mapToolbarEnabled: false,
        compassEnabled: true,
      ),
    );
  }

  void _setMapStyle(GoogleMapController controller) {
    // "Light" map - essentially disables custom styling so Google's normal light map shows.
    // If you want a pure white background, use below (but it will hide features).
    // To closely resemble Google Maps "default" light mode, just set to null or empty.
    controller.setMapStyle(null);
  }

  /// Build main stats section
  Widget _buildStatsSection(RunModel run) {
    return Column(
      children: [
        // Activity Type Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getActivityColor(run.activityType).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _getActivityColor(run.activityType), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getActivityIcon(run.activityType), color: _getActivityColor(run.activityType), size: 20),
              const SizedBox(width: 8),
              Text(
                run.activityType.toUpperCase(),
                style: AppTextStyles.labelMedium.copyWith(color: _getActivityColor(run.activityType), fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Distance - main stat
        Column(
          children: [
            Text('Total Distance', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryGray, letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (run.distanceMeters / 1000).toStringAsFixed(2),
                  style: AppTextStyles.headlineLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 48, height: 1),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text('km', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(color: AppColors.primaryGray, height: 1),
        const SizedBox(height: 24),
        // Secondary stats grid
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSecondaryStatItem(Icons.timer_rounded, 'Time', _formatDuration(run.duration)),
            Container(width: 1, height: 40, color: AppColors.primaryGray.withOpacity(0.3)),
            _buildSecondaryStatItem(Icons.speed_rounded, 'Avg Pace', run.averagePace != null ? '${run.averagePace!.toStringAsFixed(1)}\'/km' : '--'),
            Container(width: 1, height: 40, color: AppColors.primaryGray.withOpacity(0.3)),
            _buildSecondaryStatItem(Icons.local_fire_department_rounded, 'Calories', run.caloriesBurned != null ? '${run.caloriesBurned}' : '--'),
          ],
        ),
      ],
    );
  }

  Widget _buildSecondaryStatItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 11)),
      ],
    );
  }

  /// Build detailed stats section
  Widget _buildDetailedStats(RunModel run) {
    final timeFormat = DateFormat('h:mm a');

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Run Details',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildDetailRow('Activity Type', run.activityType),
          _buildDetailRow('Start Time', timeFormat.format(run.startTime)),
          _buildDetailRow('End Time', timeFormat.format(run.endTime)),
          _buildDetailRow('Duration', _formatDuration(run.duration)),
          _buildDetailRow('Distance', '${(run.distanceMeters / 1000).toStringAsFixed(2)} km'),
          if (run.averagePace != null) _buildDetailRow('Average Pace', '${run.averagePace!.toStringAsFixed(2)} min/km'),
          if (run.maxPace != null) _buildDetailRow('Best Pace', '${run.maxPace!.toStringAsFixed(2)} min/km'),
          if (run.elevationGain != null) _buildDetailRow('Elevation Gain', '${run.elevationGain!.toStringAsFixed(0)} m'),
          if (run.caloriesBurned != null) _buildDetailRow('Calories Burned', '${run.caloriesBurned} cal'),
          if (run.routePoints != null) _buildDetailRow('Route Points', '${run.routePoints!.length}'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  /// Build splits section
  Widget _buildSplitsSection(RunModel run) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.splitscreen_rounded, color: AppColors.accent, size: 24),
              const SizedBox(width: 8),
              Text(
                'Splits',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...run.splits!.map((split) => _buildSplitItem(split)).toList(),
        ],
      ),
    );
  }

  Widget _buildSplitItem(Split split) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text(
                '${split.splitNumber}',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(split.distanceMeters / 1000).toStringAsFixed(2)} km',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Time: ${_formatDuration(split.duration)}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                    const SizedBox(width: 16),
                    Text('Pace: ${split.pace.toStringAsFixed(1)}\'/km', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build notes section

  /// Build action buttons
  Widget _buildActionButtons(RunModel run) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Share Run button

          // New Run button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {
                Get.back();
                Get.toNamed(AppRoutes.activityTypeSelection);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.accent.withOpacity(0.5), width: 2),
                foregroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text('New Run', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.accent)),
            ),
          ),
          const SizedBox(height: 12),
          // Done button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () {
                Get.close(3);
                Get.find<HomeNavigationController>().changeTab(2, journalTab: 1);
              },
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primaryGray.withOpacity(0.5), width: 2),
                foregroundColor: AppColors.onSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Done', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onSurface)),
            ),
          ),
        ],
      ),
    );
  }

  /// Calculate center point of route
  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return LatLng(0, 0);

    double lat = 0;
    double lng = 0;

    for (var point in points) {
      lat += point.latitude;
      lng += point.longitude;
    }

    return LatLng(lat / points.length, lng / points.length);
  }

  /// Format duration
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    }
    return '${minutes}m ${seconds}s';
  }

  /// Save run to journal
  void _saveToJournal(RunModel run) async {
    final storageService = Get.find<StorageService>();

    final success = await storageService.syncRunToJournal(run);
    if (success) {
      Helpers.showSuccessThen('Run saved to journal!', () => Get.back());
    } else {
      Get.snackbar('Error', 'Failed to save run to journal', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: AppColors.white);
    }
  }

  /// Get activity color
  Color _getActivityColor(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walk':
        return const Color(0xFF4CAF50);
      case 'jog':
        return const Color(0xFFFF9800);
      case 'run':
        return const Color(0xFFF44336);
      case 'bike':
        return const Color(0xFF2196F3);
      default:
        return AppColors.accent;
    }
  }

  /// Get activity icon
  IconData _getActivityIcon(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walk':
        return Icons.directions_walk;
      case 'jog':
        return Icons.directions_walk_outlined;
      case 'run':
        return Icons.directions_run;
      case 'bike':
        return Icons.directions_bike;
      default:
        return Icons.directions_run;
    }
  }
}
