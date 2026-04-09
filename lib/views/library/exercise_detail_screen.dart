import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
        return AppColors.accentVariant;
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
    return {
      'why':
          'This exercise targets the ${exercise['muscleGroup']} muscles effectively. It helps build strength, improve muscle definition, and enhance overall functional fitness. Perfect for both beginners and advanced athletes looking to develop this muscle group.',
      'recommendedSets': '3–4',
      'recommendedReps': '8–12',
      'restTime': '60–90 sec',
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
    final imageUrl = exercise['image'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(
          exercise['name'] ?? '',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          Obx(() {
            final fav = _favoritesController.isFavorite(exerciseId);
            return IconButton(
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? AppColors.error : AppColors.onPrimary),
              onPressed: () {
                _favoritesController.toggleFavorite(exerciseId, {...exercise, 'type': 'exercise', 'id': exerciseId});
                Get.snackbar(
                  fav ? 'Removed from Favorites' : 'Added to Favorites',
                  exercise['name'],
                  backgroundColor: fav ? AppColors.primaryGray : AppColors.completed,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              },
            );
          }),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.onPrimary),
            onPressed: () {},
          ),
        ],
      ),

      // ── Bottom CTA ──────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
          child: SizedBox(
            height: 52.h,
            child: ElevatedButton.icon(
              onPressed: () {
                Get.snackbar(
                  'Added to Workout',
                  '${exercise['name']} has been added to your workout',
                  backgroundColor: AppColors.completed,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentVariant,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 22),
              label: Text(
                'Add O Workout',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 8.h),

            // ── Hero image card ───────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: double.infinity, height: 200.h, fit: BoxFit.cover, errorBuilder: (c, e, s) => _imagePlaceholder())
                      : _imagePlaceholder(),
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                    child: Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 30.w),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            // ── Info stat cards (mint tiles: icon + label) ────────────────
            Row(
              children: [
                Expanded(
                  child: _buildInfoStatCard(image: 'assets/images/Vector.png', label: '12 Weeks'),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _buildInfoStatCard(image: 'assets/images/1. bench press.png', label: '${exercise['muscleGroup'] ?? 'Muscle'}'),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _buildInfoStatCard(image: 'assets/images/intermidiate.png', label: '${exercise['difficulty'] ?? 'Level'}', accentIcon: true),
                ),
              ],
            ),

            SizedBox(height: 24.h),

            // ── Difficulty Level ──────────────────────────────────────────
            Text('Difficulty Level', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(exercise['difficulty'], style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                Text('${(difficultyValue * 100).toInt()}%', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
              ],
            ),
            SizedBox(height: 8.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: difficultyValue,
                minHeight: 8,
                backgroundColor: AppColors.primaryGray.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(difficultyColor),
              ),
            ),
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Beginner', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                Text('Advanced', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
              ],
            ),

            SizedBox(height: 28.h),

            // ── Why? ─────────────────────────────────────────────────────
            Text('Why?', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: 10.h),
            Text(details['why'], style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, height: 1.6)),

            SizedBox(height: 28.h),

            // ── Recommended Programming ───────────────────────────────────
            Text('Recommended Programming', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: 14.h),
            Row(
              children: [
                Expanded(child: _buildStatCard('assets/images/sets111.png', 'Sets', details['recommendedSets'], const Color(0xFFF5E6C8))),
                SizedBox(width: 10.w),
                Expanded(child: _buildStatCard('assets/images/infinity.png', 'Reps', details['recommendedReps'], const Color(0xFFCCDFF3))),
                SizedBox(width: 10.w),
                Expanded(child: _buildStatCard('assets/images/clock333.png', 'Rest Time', details['restTime'], const Color(0xFFD6E8D0))),
              ],
            ),

            SizedBox(height: 28.h),

            // ── Key Form Cues ────────────────────────────────────────────
            Text('Key Form Cues', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: 10.h),
            ...(details['cues'] as List).cast<String>().map((cue) => _buildCueItem(cue)),

            SizedBox(height: 24.h),

            // ── Targeted Muscles ─────────────────────────────────────────
            Text('Targeted Muscles', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primary
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Primary:',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 6.h),
                      Wrap(spacing: 6, runSpacing: 6, children: (details['primaryMuscles'] as List).cast<String>().map((m) => _buildMuscleChip(m, true)).toList()),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                // Secondary
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Secondary:',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.black, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 6.h),
                      Wrap(spacing: 6, runSpacing: 6, children: (details['secondaryMuscles'] as List).cast<String>().map((m) => _buildMuscleChip(m, false)).toList()),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 28.h),

            // ── Pro Tips ─────────────────────────────────────────────────
            Text('Pro Tips', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: 10.h),
            ...(details['tips'] as List).cast<String>().asMap().entries.map((e) => _buildTipItem(e.key + 1, e.value)),

            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  Widget _imagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 200.h,
      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
      child: const Center(child: Icon(Icons.fitness_center, color: AppColors.accent, size: 40)),
    );
  }

  static const Color _kInfoCardText = Color(0xFF3D3D3D);

  /// Rounded mint card: centered icon + bold label (matches library detail mock).
  Widget _buildInfoStatCard({required String image, required String label, bool accentIcon = false}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 6.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(image, fit: BoxFit.contain, width: 30.w, height: 30.h),
          SizedBox(height: 10.h),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w800, fontSize: 12.sp, color: _kInfoCardText, height: 1.2),
          ),
        ],
      ),
    );
  }

  /// Recommended programming rounded card
  Widget _buildStatCard(String image, String label, String value, Color iconBg) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E0), width: 0.8),
      ),
      child: Column(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Padding(
              padding: EdgeInsets.all(10.w),
              child: Image.asset(image, fit: BoxFit.contain),
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.onBackground, fontSize: 12.sp),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, fontSize: 14.sp),
          ),
        ],
      ),
    );
  }

  /// Bullet cue item
  Widget _buildCueItem(String cue) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6.h),
            width: 6.w,
            height: 6.w,
            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(cue, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, height: 1.5)),
          ),
        ],
      ),
    );
  }

  /// Numbered pro-tip card
  Widget _buildTipItem(int index, String tip) {
    final numberStr = index.toString().padLeft(2, '0');
    final Color numberColor = _tipNumberColor(index);
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFE9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6F0DA), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                numberStr,
                style: AppTextStyles.titleMedium.copyWith(color: numberColor, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(tip, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, height: 1.5)),
          ),
        ],
      ),
    );
  }

  Color _tipNumberColor(int index) {
    // 01 orange, 02 blue, 03 green, 04 purple (repeat afterwards)
    const List<Color> palette = [Color(0xFFF39C12), Color(0xFF2E86DE), Color(0xFF27AE60), Color(0xFF8E44AD)];
    final idx = (index - 1) % palette.length;
    return palette[idx];
  }

  /// Muscle group chip
  Widget _buildMuscleChip(String muscle, bool isPrimary) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(color: const Color(0xFFE5F2CF), borderRadius: BorderRadius.circular(50)),
      child: Text(
        muscle,
        style: AppTextStyles.bodySmall.copyWith(color: isPrimary ? AppColors.accent : AppColors.black, fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500),
      ),
    );
  }
}
