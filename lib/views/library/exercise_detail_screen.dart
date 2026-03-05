import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/favorites_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Exercise detail screen - shows comprehensive information about an exercise
class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  late Map<String, dynamic> exercise;
  final FavoritesController _favoritesController = Get.put(FavoritesController());
  late String exerciseId;

  @override
  void initState() {
    super.initState();
    exercise = Get.arguments as Map<String, dynamic>;
    exerciseId = exercise['id']?.toString() ?? exercise['name']?.toString() ?? '';
  }

  bool get isFavorite => _favoritesController.isFavorite(exerciseId);

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return AppColors.completed;
      case 'intermediate':
        return AppColors.upcoming;
      case 'advanced':
        return AppColors.error;
      default:
        return AppColors.primaryGray;
    }
  }

  double _getDifficultyValue(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return 0.33;
      case 'intermediate':
        return 0.66;
      case 'advanced':
        return 1.0;
      default:
        return 0.5;
    }
  }

  Map<String, dynamic> _getExerciseDetails(String exerciseName) {
    // Mock detailed information - in real app, this would come from database
    return {
      'why':
          'This exercise targets the ${exercise['muscleGroup']} muscles effectively. It helps build strength, improve muscle definition, and enhance overall functional fitness. Perfect for both beginners and advanced athletes looking to develop this muscle group.',
      'recommendedSets': '3-4 sets',
      'recommendedReps': '8-12 reps',
      'restTime': '60-90 seconds',
      'cues': [
        'Keep your core engaged throughout the movement',
        'Control the eccentric (lowering) phase',
        'Breathe out during exertion, in during relaxation',
        'Maintain proper form over heavy weight',
        'Focus on mind-muscle connection',
        'Keep your shoulders back and down',
      ],
      'primaryMuscles': [exercise['muscleGroup']],
      'secondaryMuscles': ['Core', 'Stabilizers'],
      'tips': [
        'Start with lighter weights to master form',
        'Gradually increase weight as you progress',
        'Consider working with a spotter for safety',
        'Warm up properly before attempting heavy sets',
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final details = _getExerciseDetails(exercise['name']);
    final difficultyColor = _getDifficultyColor(exercise['difficulty']);
    final difficultyValue = _getDifficultyValue(exercise['difficulty']);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(exercise['name'], style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent)),
        centerTitle: true,
        actions: [
          Obx(() {
            final favoriteStatus = _favoritesController.isFavorite(exerciseId);
            return IconButton(
              icon: Icon(favoriteStatus ? Icons.favorite : Icons.favorite_border, color: favoriteStatus ? AppColors.error : AppColors.onPrimary),
              onPressed: () {
                _favoritesController.toggleFavorite(exerciseId, {...exercise, 'type': 'exercise', 'id': exerciseId});
                Get.snackbar(
                  favoriteStatus ? 'Removed from Favorites' : 'Added to Favorites',
                  exercise['name'],
                  backgroundColor: favoriteStatus ? AppColors.primaryGray : AppColors.completed,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              },
            );
          }),
          IconButton(
            icon: const Icon(Icons.share, color: AppColors.onPrimary),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video Player Placeholder
            Container(
              width: double.infinity,
              height: 250,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Placeholder for video
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF9333EA), const Color(0xFFFBBF24)]),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline, size: 80, color: Colors.white.withOpacity(0.9)),
                          const SizedBox(height: 12),
                          Text('Video Demonstration', style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('Tap to play', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                  // Play button overlay
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          // TODO: Implement video playback
                          Get.snackbar(
                            'Video Player',
                            'Video playback feature coming soon!',
                            backgroundColor: AppColors.accent,
                            colorText: AppColors.onAccent,
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exercise Info Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildInfoTag(Icons.fitness_center, exercise['equipment'], AppColors.accent),
                      _buildInfoTag(Icons.category, exercise['muscleGroup'], AppColors.completed),
                      _buildInfoTag(Icons.signal_cellular_alt, exercise['difficulty'], difficultyColor),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Difficulty Meter
                  _buildSection(
                    'Difficulty Level',
                    Icons.speed,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              exercise['difficulty'],
                              style: AppTextStyles.titleSmall.copyWith(color: difficultyColor, fontWeight: FontWeight.bold),
                            ),
                            Text('${(difficultyValue * 100).toInt()}%', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: difficultyValue,
                            minHeight: 12,
                            backgroundColor: AppColors.primaryGray.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(difficultyColor),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Beginner', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                            Text('Advanced', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Why Section
                  _buildSection(
                    'Why?',
                    Icons.help_outline,
                    child: Text(details['why'], style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, height: 1.6)),
                  ),

                  const SizedBox(height: 24),

                  // Recommended Sets & Reps
                  _buildSection(
                    'Recommended Programming',
                    Icons.repeat,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildStatCard('Sets', details['recommendedSets'], Icons.format_list_numbered)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildStatCard('Reps', details['recommendedReps'], Icons.repeat_one)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStatCard('Rest Time', details['restTime'], Icons.timer, fullWidth: true),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Form Cues
                  _buildSection('Key Form Cues', Icons.checklist, child: Column(children: (details['cues'] as List).cast<String>().map((cue) => _buildCueItem(cue)).toList())),

                  const SizedBox(height: 24),

                  // Targeted Muscles
                  _buildSection(
                    'Targeted Muscles',
                    Icons.accessibility_new,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Primary:', style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: (details['primaryMuscles'] as List).cast<String>().map((muscle) => _buildMuscleChip(muscle, true)).toList()),
                        const SizedBox(height: 16),
                        Text('Secondary:', style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryGray)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 8, children: (details['secondaryMuscles'] as List).cast<String>().map((muscle) => _buildMuscleChip(muscle, false)).toList()),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Pro Tips
                  _buildSection('Pro Tips', Icons.lightbulb_outline, child: Column(children: (details['tips'] as List).cast<String>().map((tip) => _buildTipItem(tip)).toList())),

                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Add to workout
                        Get.snackbar(
                          'Added to Workout',
                          '${exercise['name']} has been added to your workout',
                          backgroundColor: AppColors.completed,
                          colorText: AppColors.onError,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.onAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 24),
                      label: Text('Add to Workout', style: AppTextStyles.buttonLarge),
                    ),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 24),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildInfoTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, {bool fullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: fullWidth ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              Text(
                value,
                style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCueItem(String cue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(cue, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String tip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.upcoming.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.upcoming.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates, color: AppColors.upcoming, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tip, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleChip(String muscle, bool isPrimary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: isPrimary ? AppColors.accent.withOpacity(0.2) : AppColors.primaryGray.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
      child: Text(
        muscle,
        style: AppTextStyles.labelMedium.copyWith(color: isPrimary ? AppColors.accent : AppColors.primaryGray, fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }
}
