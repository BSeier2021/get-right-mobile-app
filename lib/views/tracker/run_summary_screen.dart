import 'package:flutter/material.dart' hide Split;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:get_right/models/run_activity_model.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/repo/calendar_repo.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/helpers.dart';
import 'package:get_right/widgets/tracker/route_endpoint_labels.dart';

/// Run Summary Screen - Display completed run with map and stats
class RunSummaryScreen extends StatefulWidget {
  const RunSummaryScreen({super.key});

  @override
  State<RunSummaryScreen> createState() => _RunSummaryScreenState();
}

class _RunSummaryScreenState extends State<RunSummaryScreen> {
  GoogleMapController? _mapController;
  final CalendarRepository _calendarRepo = CalendarRepository();
  final RunningLogRepository _runningLogRepo = RunningLogRepository();
  bool _isSavingToCalendar = false;
  RunModel? _run;

  @override
  void initState() {
    super.initState();
    _run = _tryRunFromArguments();
  }

  RunModel? _tryRunFromArguments() {
    final args = Get.arguments;
    if (args is RunModel) return args;
    if (args is! Map) return null;

    final map = Map<String, dynamic>.from(args);
    if (map['run'] is RunModel) return map['run'] as RunModel;
    if (map['runModel'] is RunModel) return map['runModel'] as RunModel;

    final activity = map['activity'];
    if (activity is RunActivityModel) return _runFromActivity(activity);
    if (activity is Map) {
      return _runFromActivity(RunActivityModel.fromJson(Map<String, dynamic>.from(activity)));
    }

    return _runFromLooseMap(map);
  }

  RunModel _runFromActivity(RunActivityModel activity) {
    final start = activity.startedAt ?? activity.date;
    final end = activity.completedAt ?? start.add(Duration(seconds: activity.durationSeconds));
    final routePoints = activity.routePoints
        .map((p) => LocationPoint(latitude: p.latitude, longitude: p.longitude, timestamp: end))
        .toList();

    return RunModel(
      id: activity.id,
      userId: activity.userId,
      activityType: activity.activityType,
      distanceMeters: activity.distanceMeters,
      duration: Duration(seconds: activity.durationSeconds),
      startTime: start,
      endTime: end,
      routePoints: routePoints.isEmpty ? null : routePoints,
      elevationGain: activity.elevationGain,
      averagePace: activity.averagePace,
      maxPace: activity.maxPace,
      caloriesBurned: activity.caloriesBurned,
      notes: activity.notes,
      createdAt: activity.date,
    );
  }

  RunModel? _runFromLooseMap(Map<String, dynamic> map) {
    final distanceMeters = (map['distanceMeters'] as num?)?.toDouble();
    final durationSeconds = (map['durationSeconds'] as num?)?.toInt() ?? (map['duration'] as num?)?.toInt();
    if (distanceMeters == null && durationSeconds == null) return null;

    final startRaw = map['startTime'] ?? map['startedAt'];
    final endRaw = map['endTime'] ?? map['completedAt'];
    final start = startRaw != null ? DateTime.tryParse(startRaw.toString()) ?? DateTime.now() : DateTime.now();
    final end = endRaw != null ? DateTime.tryParse(endRaw.toString()) ?? start : start;

    return RunModel(
      id: map['id']?.toString() ?? 'run_${DateTime.now().millisecondsSinceEpoch}',
      userId: map['userId']?.toString() ?? 'user',
      activityType: map['activityType']?.toString() ?? 'Run',
      distanceMeters: distanceMeters ?? 0,
      duration: Duration(seconds: durationSeconds ?? 0),
      startTime: start,
      endTime: end,
      averagePace: (map['averagePace'] as num?)?.toDouble(),
      maxPace: (map['maxPace'] as num?)?.toDouble(),
      caloriesBurned: (map['caloriesBurned'] as num?)?.toInt(),
      backendLogId: map['backendLogId']?.toString(),
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? start,
    );
  }

  String? _calendarEntryIdFromArguments() {
    final args = Get.arguments;
    if (args is! Map) return null;
    final id = args['calendarEntryId']?.toString().trim();
    if (id != null && WorkoutRepository.isValidMongoId(id)) return id;
    return null;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final run = _run;
    if (run == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Run data unavailable', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: () => Get.back(), child: const Text('Go back')),
                ],
              ),
            ),
          ),
        ),
      );
    }

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
                    Text(DateFormat('EEEE, MMM d, yyyy').format(run.startTime.toLocal()), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 20),

                _buildStatsSection(run),
                const SizedBox(height: 20),
                _buildMapSection(run),
                if (run.routePoints != null && run.routePoints!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: RouteEndpointLabels(
                      start: LatLng(run.routePoints!.first.latitude, run.routePoints!.first.longitude),
                      end: LatLng(run.routePoints!.last.latitude, run.routePoints!.last.longitude),
                      startName: run.startPointName,
                      endName: run.endPointName,
                    ),
                  ),
                ],

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
        infoWindow: InfoWindow(title: 'Start', snippet: run.startPointName),
      ),
      Marker(
        markerId: const MarkerId('end'),
        position: points.last,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'Finish', snippet: run.endPointName),
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
            _buildSecondaryStatItem(Icons.speed_rounded, 'Avg Pace', _formatPace(run.averagePace)),
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
    final startTime = run.startTime.toLocal();
    final endTime = run.endTime.toLocal();

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
          _buildDetailRow('Start Time', timeFormat.format(startTime)),
          _buildDetailRow('End Time', timeFormat.format(endTime)),
          _buildDetailRow('Duration', _formatDuration(run.duration)),
          _buildDetailRow('Distance', '${(run.distanceMeters / 1000).toStringAsFixed(2)} km'),
          if (run.averagePace != null && run.averagePace! > 0) _buildDetailRow('Average Pace', _formatPace(run.averagePace)),
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
              onPressed: _isSavingToCalendar ? null : () => _onDone(run),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primaryGray.withOpacity(0.5), width: 2),
                foregroundColor: AppColors.onSurface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSavingToCalendar
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : Text('Done', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.onSurface)),
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

  String _formatPace(double? paceMinPerKm) {
    if (paceMinPerKm == null || paceMinPerKm <= 0) return '--';
    final minutes = paceMinPerKm.floor();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}/km';
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

  Future<void> _onDone(RunModel run) async {
    setState(() => _isSavingToCalendar = true);
    try {
      var logId = run.backendLogId;
      if (logId == null || !WorkoutRepository.isValidMongoId(logId)) {
        if (WorkoutRepository.isValidMongoId(run.id)) {
          logId = run.id;
        } else {
          final response = await _runningLogRepo.saveRunningLog(run: run);
          logId = RunningLogRepository.runningLogIdFrom(response);
        }
      }

      if (logId == null || !WorkoutRepository.isValidMongoId(logId)) {
        throw Exception('Could not save running log');
      }

      await _calendarRepo.attachRunningLogToCalendar(
        date: run.startTime,
        runningLogId: logId,
        calendarEntryId: _calendarEntryIdFromArguments(),
        durationInSeconds: run.duration.inSeconds,
      );

      if (!mounted) return;
      _navigateHomeAfterSave();
    } catch (e) {
      if (!mounted) return;
      Get.snackbar(
        'Could not save run',
        CalendarRepository.errorMessageFrom(e),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.error,
        colorText: AppColors.white,
      );
    } finally {
      if (mounted) setState(() => _isSavingToCalendar = false);
    }
  }

  void _navigateHomeAfterSave() {
    if (Get.isRegistered<HomeNavigationController>()) {
      if (Get.currentRoute != AppRoutes.home) {
        Get.until((route) => route.settings.name == AppRoutes.home);
      }
      Get.find<HomeNavigationController>().changeTab(2, journalTab: 1);
      return;
    }
    Get.offNamed(AppRoutes.home, arguments: {'navigateToTab': 2, 'journalTabIndex': 1});
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
