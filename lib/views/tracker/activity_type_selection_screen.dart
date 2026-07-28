import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/planned_route_model.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Activity Type Selection Screen
/// User selects Walk, Jog, Run, or Bike before starting activity
class ActivityTypeSelectionScreen extends StatefulWidget {
  const ActivityTypeSelectionScreen({super.key});

  @override
  State<ActivityTypeSelectionScreen> createState() => _ActivityTypeSelectionScreenState();
}

class _ActivityTypeSelectionScreenState extends State<ActivityTypeSelectionScreen> {
  String? _selectedActivity;
  PlannedRouteModel? _plannedRoute;

  final List<Map<String, dynamic>> _activities = [
    {'type': 'Walk', 'icon': Icons.directions_walk, 'color': const Color(0xFF4CAF50), 'description': 'Low intensity cardio'},
    {'type': 'Jog', 'icon': Icons.directions_walk_outlined, 'color': const Color(0xFFFF9800), 'description': 'Moderate pace activity'},
    {'type': 'Run', 'icon': Icons.directions_run, 'color': const Color(0xFFF44336), 'description': 'High intensity running'},
    {'type': 'Bike', 'icon': Icons.directions_bike, 'color': const Color(0xFF2196F3), 'description': 'Cycling activity'},
  ];

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null && args['plannedRoute'] != null) {
      _plannedRoute = args['plannedRoute'] as PlannedRouteModel;
    }
  }

  void _startActivity() {
    if (_selectedActivity == null) {
      Get.snackbar('Select Activity', 'Please choose an activity type', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    // Navigate to live run tracking with activity type and planned route
    final Map<String, dynamic> args = {'activityType': _selectedActivity};
    if (_plannedRoute != null) {
      args['plannedRoute'] = _plannedRoute;
    }
    Get.toNamed(AppRoutes.runTracking, arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ).paddingAll(8),
        ),
        title: Text('Select Activity Type', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What are you doing today?',
                    style: AppTextStyles.headlineSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Choose your activity to get accurate tracking', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGrayDark)),
                  if (_plannedRoute != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.route, color: AppColors.accent, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Using saved route',
                                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(_plannedRoute!.name, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                                const SizedBox(height: 4),
                                Text(
                                  '${(_plannedRoute!.estimatedDistance / 1000).toStringAsFixed(2)} km',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGrayDark),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),

                  // Activity Type Cards
                  ...List.generate(_activities.length, (index) {
                    final activity = _activities[index];
                    final isSelected = _selectedActivity == activity['type'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildActivityCard(
                        type: activity['type'] as String,
                        icon: activity['icon'] as IconData,
                        color: activity['color'] as Color,
                        description: activity['description'] as String,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedActivity = activity['type'] as String;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Start Activity Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _selectedActivity != null ? _startActivity : null,
                  icon: const Icon(Icons.play_arrow, size: 28),
                  label: Text('Start Activity', style: AppTextStyles.buttonLarge.copyWith(color: _selectedActivity != null ? Colors.white : Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.accentVariant,
                    disabledForegroundColor: Colors.white,

                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: AppColors.accent.withValues(alpha: 0.5), width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard({
    required String type,
    required IconData icon,
    required Color color,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? color : AppColors.primaryGray.withValues(alpha: 0.3), width: isSelected ? 2 : 1),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: AppColors.secondary.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),

            // Activity Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: AppTextStyles.titleLarge.copyWith(color: isSelected ? color : AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGrayDark)),
                ],
              ),
            ),

            // Selection Indicator
            if (isSelected)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Colors.white, size: 20),
              )
            else
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryGray, width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
