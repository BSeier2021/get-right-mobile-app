import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get_right/models/run_activity_model.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/services/share_to_chat_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Post-Run Summary Screen
/// Detailed summary after completing a run activity
class RunSummaryDetailScreen extends StatefulWidget {
  const RunSummaryDetailScreen({super.key});

  @override
  State<RunSummaryDetailScreen> createState() => _RunSummaryDetailScreenState();
}

class _RunSummaryDetailScreenState extends State<RunSummaryDetailScreen> {
  RunActivityModel? _activity;
  GoogleMapController? _mapController;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['activity'] != null) {
      _activity = args['activity'] as RunActivityModel;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_activity == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.primary, elevation: 0),
        body: Center(
          child: Text('No activity data', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Map
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.onBackground),
              onPressed: () => Get.back(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: AppColors.accent),
                onPressed: () {
                  final runId = _activity?.id.trim() ?? '';
                  if (!WorkoutRepository.isValidMongoId(runId)) {
                    Get.snackbar('Cannot share', 'Run is not saved yet', backgroundColor: AppColors.error, colorText: AppColors.onError);
                    return;
                  }
                  ShareToChatService.share(context: context, type: SharedContentType.runningLog, contentId: runId);
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(background: _buildRouteMap()),
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Celebration Header
                _buildCelebrationHeader(),

                // Primary Metrics
                _buildPrimaryMetrics(),

                // Splits Section
                if (_activity!.splits.isNotEmpty) _buildSplitsSection(),

                // Notes Section
                _buildNotesSection(),

                // Action Buttons
                _buildActionButtons(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMap() {
    if (_activity!.routePoints.isEmpty) {
      return Container(
        color: AppColors.primaryGrayLight,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 64, color: AppColors.primaryGrayDark),
              const SizedBox(height: 16),
              Text('No route data', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark)),
            ],
          ),
        ),
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _activity!.routePoints.first, zoom: 14),
      onMapCreated: (controller) {
        _mapController = controller;
      },
      polylines: {Polyline(polylineId: const PolylineId('completed_route'), points: _activity!.routePoints, color: AppColors.accent, width: 5)},
      markers: {
        if (_activity!.routePoints.isNotEmpty)
          Marker(markerId: const MarkerId('start'), position: _activity!.routePoints.first, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
        if (_activity!.routePoints.length > 1)
          Marker(markerId: const MarkerId('end'), position: _activity!.routePoints.last, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
      },
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildCelebrationHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.accent.withValues(alpha: 0.15), AppColors.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, size: 48, color: AppColors.accent),
          const SizedBox(height: 16),
          Text(
            '${_activity!.activityType} Complete!',
            style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(_getDateTimeString(), style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
        ],
      ),
    );
  }

  Widget _buildPrimaryMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Row 1: Distance, Time
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(icon: Icons.straighten, value: '${_activity!.distanceKm.toStringAsFixed(2)} km', label: 'Total Distance'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(icon: Icons.timer_outlined, value: _activity!.formattedDuration, label: 'Total Time'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 2: Avg Pace, Max Pace
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(icon: Icons.show_chart, value: '${_activity!.formattedAveragePace}/km', label: 'Average Pace'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(icon: Icons.speed, value: '${_formatPace(_activity!.maxPace)}/km', label: 'Max Pace'),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Row 3: Calories
          _buildMetricCard(icon: Icons.local_fire_department, value: '${_activity!.caloriesBurned ?? 0} cal', label: 'Calories Burned', iconColor: Colors.orange),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetricCard({required IconData icon, required String value, required String label, Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor ?? AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSplitsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Splits',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
              ),
              Text('per km', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark)),
            ],
          ),
          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGrayLight.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Text(
                          'KM',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Time',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Pace',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Splits Data
                ...List.generate(_activity!.splits.length, (index) {
                  final split = _activity!.splits[index];
                  final isLast = index == _activity!.splits.length - 1;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: !isLast ? Border(bottom: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.1), width: 1)) : null,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${split.splitNumber}',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(split.formattedTime, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            split.formattedPace,
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notes',
            style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'How did it feel? Add your notes here...',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark),
                border: InputBorder.none,
              ),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                // Save notes and return to journal
                Get.back();
              },
              icon: const Icon(Icons.check_circle, size: 24),
              label: Text('Save Activity', style: AppTextStyles.buttonLarge),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: () {
                final runId = _activity?.id.trim() ?? '';
                if (!WorkoutRepository.isValidMongoId(runId)) {
                  Get.snackbar('Cannot share', 'Run is not saved yet', backgroundColor: AppColors.error, colorText: AppColors.onError);
                  return;
                }
                ShareToChatService.share(context: context, type: SharedContentType.runningLog, contentId: runId);
              },
              icon: const Icon(Icons.share, size: 24),
              label: Text('Share Activity', style: AppTextStyles.buttonLarge.copyWith(color: AppColors.accent)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accent, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildCelebrationHeader() {
  //   return Container(
  //     margin: const EdgeInsets.all(16),
  //     padding: const EdgeInsets.all(24),
  //     decoration: BoxDecoration(
  //       gradient: LinearGradient(
  //         colors: [AppColors.accent.withOpacity(0.15), AppColors.surface],
  //         begin: Alignment.topLeft,
  //         end: Alignment.bottomRight,
  //       ),
  //       borderRadius: BorderRadius.circular(20),
  //       border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1.5),
  //     ),
  //     child: Column(
  //       children: [
  //         Container(
  //           width: 80,
  //           height: 80,
  //           decoration: BoxDecoration(
  //             color: AppColors.accent.withOpacity(0.2),
  //             shape: BoxShape.circle,
  //             border: Border.all(color: AppColors.accent, width: 3),
  //           ),
  //           child: Icon(_getActivityIcon(), size: 40, color: AppColors.accent),
  //         ),
  //         const SizedBox(height: 16),
  //         Text(
  //           '${_activity!.activityType} Complete!',
  //           style: AppTextStyles.headlineMedium.copyWith(
  //             color: AppColors.onBackground,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         const SizedBox(height: 8),
  //         Text(
  //           _getMotivationalQuote(),
  //           style: AppTextStyles.bodyMedium.copyWith(
  //             color: AppColors.primaryGrayDark,
  //             fontStyle: FontStyle.italic,
  //           ),
  //           textAlign: TextAlign.center,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildPrimaryMetrics() {
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(horizontal: 16),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'Stats',
  //           style: AppTextStyles.titleMedium.copyWith(
  //             color: AppColors.onBackground,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         const SizedBox(height: 16),

  //         Row(
  //           children: [
  //             Expanded(child: _buildStatCard(Icons.straighten, '${_activity!.distanceKm.toStringAsFixed(2)}', 'Distance (km)')),
  //             const SizedBox(width: 12),
  //             Expanded(child: _buildStatCard(Icons.timer_outlined, _activity!.formattedDuration, 'Duration')),
  //           ],
  //         ),
  //         const SizedBox(height: 12),

  //         Row(
  //           children: [
  //             Expanded(child: _buildStatCard(Icons.show_chart, _activity!.formattedAveragePace, 'Avg Pace')),
  //             const SizedBox(width: 12),
  //             Expanded(child: _buildStatCard(Icons.speed, _formatPace(_activity!.maxPace), 'Max Pace')),
  //           ],
  //         ),
  //         const SizedBox(height: 12),

  //         Row(
  //           children: [
  //             Expanded(child: _buildStatCard(Icons.favorite, '${_activity!.averageHeartRate?.toInt() ?? '--'}', 'Avg HR', iconColor: Colors.red)),
  //             const SizedBox(width: 12),
  //             Expanded(child: _buildStatCard(Icons.favorite_border, '${_activity!.maxHeartRate?.toInt() ?? '--'}', 'Max HR', iconColor: Colors.red)),
  //           ],
  //         ),
  //         const SizedBox(height: 12),

  //         _buildStatCard(Icons.local_fire_department, '${_activity!.caloriesBurned ?? 0}', 'Calories', iconColor: Colors.orange),

  //         const SizedBox(height: 24),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildStatCard(IconData icon, String value, String label, {Color? iconColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor ?? AppColors.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatPace(double pace) {
    if (pace == 0) return '--:--';
    final minutes = pace.floor();
    final seconds = ((pace - minutes) * 60).round();
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  String _getDateTimeString() {
    final date = _activity!.completedAt ?? _activity!.date;
    return '${date.day}/${date.month}/${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _getActivityIcon() {
    switch (_activity!.activityType) {
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

  String _getMotivationalQuote() {
    final quotes = [
      "You showed up—and that's what counts!",
      "Every step brings you closer to your goals!",
      "Consistency is key. Great job!",
      "You're building unstoppable momentum!",
    ];
    return quotes[DateTime.now().second % quotes.length];
  }
}
