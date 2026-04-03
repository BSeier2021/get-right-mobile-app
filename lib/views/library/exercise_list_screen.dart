import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Exercise list screen - shows exercises for a specific muscle group
class ExerciseListScreen extends StatefulWidget {
  const ExerciseListScreen({super.key});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Map<String, dynamic> muscleGroup;

  List<Map<String, dynamic>> _exercises = [];

  @override
  void initState() {
    super.initState();
    muscleGroup = Get.arguments as Map<String, dynamic>;
    _loadExercises();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Load mock exercises ──────────────────────────────────────────────
  void _loadExercises() {
    final groupId = muscleGroup['id'] as String;
    final count = muscleGroup['exerciseCount'] as int? ?? 8;
    _exercises = _getExercisesForMuscleGroup(groupId, count);
  }

  List<Map<String, dynamic>> _getExercisesForMuscleGroup(String groupId, int count) {
    final Map<String, List<Map<String, String>>> exercisesByGroup = {
      'chest': [
        {'name': 'Incline Dumbbell Press', 'equipment': 'Dumbbells', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400'},
        {'name': 'Cable Flyes', 'equipment': 'Cable', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'},
        {'name': 'Dips', 'equipment': 'Bodyweight', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1597452485669-2c7bb5fef90d?w=400'},
        {'name': 'Decline Bench Press', 'equipment': 'Bodyweight', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400'},
        {'name': 'Chest Press Machine', 'equipment': 'Machine', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400'},
        {'name': 'Dumbbell Flyes', 'equipment': 'Dumbbells', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400'},
      ],
      'back': [
        {'name': 'Pull-Ups', 'equipment': 'Bodyweight', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1598971457999-ca4ef48a9a71?w=400'},
        {'name': 'Barbell Rows', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1603287681836-b174ce5074c2?w=400'},
        {'name': 'Lat Pulldowns', 'equipment': 'Cable', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'},
        {'name': 'Deadlifts', 'equipment': 'Barbell', 'difficulty': 'Advanced', 'image': 'https://images.unsplash.com/photo-1517963879433-6ad2b056d712?w=400'},
        {'name': 'Seated Cable Rows', 'equipment': 'Cable', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400'},
        {'name': 'T-Bar Rows', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400'},
        {'name': 'Face Pulls', 'equipment': 'Cable', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400'},
        {'name': 'Dumbbell Rows', 'equipment': 'Dumbbells', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400'},
      ],
      'shoulders': [
        {'name': 'Overhead Press', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1532029837206-abbe2b7620e3?w=400'},
        {'name': 'Lateral Raises', 'equipment': 'Dumbbells', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400'},
        {'name': 'Front Raises', 'equipment': 'Dumbbells', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400'},
        {'name': 'Arnold Press', 'equipment': 'Dumbbells', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'},
        {'name': 'Face Pulls', 'equipment': 'Cable', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400'},
        {'name': 'Upright Rows', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1517963879433-6ad2b056d712?w=400'},
        {'name': 'Reverse Flyes', 'equipment': 'Dumbbells', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400'},
        {'name': 'Cable Lateral Raises', 'equipment': 'Cable', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1597452485669-2c7bb5fef90d?w=400'},
      ],
      'quads': [
        {'name': 'Barbell Squats', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400'},
        {'name': 'Leg Press', 'equipment': 'Machine', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'},
        {'name': 'Lunges', 'equipment': 'Dumbbells', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1434608519344-49d77a699e1d?w=400'},
        {'name': 'Leg Extensions', 'equipment': 'Machine', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400'},
        {'name': 'Bulgarian Split Squats', 'equipment': 'Dumbbells', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400'},
        {'name': 'Front Squats', 'equipment': 'Barbell', 'difficulty': 'Advanced', 'image': 'https://images.unsplash.com/photo-1517963879433-6ad2b056d712?w=400'},
        {'name': 'Goblet Squats', 'equipment': 'Dumbbell', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400'},
        {'name': 'Hack Squats', 'equipment': 'Machine', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400'},
      ],
      'hamstrings': [
        {'name': 'Romanian Deadlifts', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1517963879433-6ad2b056d712?w=400'},
        {'name': 'Leg Curls', 'equipment': 'Machine', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'},
        {'name': 'Nordic Curls', 'equipment': 'Bodyweight', 'difficulty': 'Advanced', 'image': 'https://images.unsplash.com/photo-1598971639058-a6a0e094e680?w=400'},
        {'name': 'Good Mornings', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400'},
        {'name': 'Single-Leg Deadlifts', 'equipment': 'Dumbbells', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400'},
        {'name': 'Glute Ham Raises', 'equipment': 'Machine', 'difficulty': 'Advanced', 'image': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400'},
        {'name': 'Swiss Ball Curls', 'equipment': 'Stability Ball', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400'},
      ],
      'triceps': [
        {'name': 'Close-Grip Bench Press', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1534368786749-b63e05c92717?w=400'},
        {'name': 'Tricep Pushdowns', 'equipment': 'Cable', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'},
        {'name': 'Overhead Extensions', 'equipment': 'Dumbbell', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1532029837206-abbe2b7620e3?w=400'},
        {'name': 'Dips', 'equipment': 'Bodyweight', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1597452485669-2c7bb5fef90d?w=400'},
        {'name': 'Skull Crushers', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400'},
        {'name': 'Kickbacks', 'equipment': 'Dumbbells', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400'},
        {'name': 'Diamond Push-Ups', 'equipment': 'Bodyweight', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1598971639058-a6a0e094e680?w=400'},
      ],
      'biceps': [
        {'name': 'Barbell Curls', 'equipment': 'Barbell', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400'},
        {'name': 'Hammer Curls', 'equipment': 'Dumbbells', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400'},
        {'name': 'Preacher Curls', 'equipment': 'Barbell', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'},
        {'name': 'Cable Curls', 'equipment': 'Cable', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400'},
        {'name': 'Concentration Curls', 'equipment': 'Dumbbell', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400'},
        {'name': 'Incline Curls', 'equipment': 'Dumbbells', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1517963879433-6ad2b056d712?w=400'},
        {'name': 'Spider Curls', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1597452485669-2c7bb5fef90d?w=400'},
      ],
      'core': [
        {'name': 'Planks', 'equipment': 'Bodyweight', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1566241142559-40e1dab266c6?w=400'},
        {'name': 'Crunches', 'equipment': 'Bodyweight', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1598971639058-a6a0e094e680?w=400'},
        {'name': 'Russian Twists', 'equipment': 'Medicine Ball', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400'},
        {'name': 'Hanging Leg Raises', 'equipment': 'Pull-up Bar', 'difficulty': 'Advanced', 'image': 'https://images.unsplash.com/photo-1598971457999-ca4ef48a9a71?w=400'},
        {'name': 'Cable Crunches', 'equipment': 'Cable', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'},
        {'name': 'Ab Wheel Rollouts', 'equipment': 'Ab Wheel', 'difficulty': 'Advanced', 'image': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400'},
        {'name': 'Dead Bugs', 'equipment': 'Bodyweight', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400'},
        {'name': 'Bicycle Crunches', 'equipment': 'Bodyweight', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400'},
      ],
      'glutes': [
        {'name': 'Hip Thrusts', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=400'},
        {'name': 'Glute Bridges', 'equipment': 'Bodyweight', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1598971639058-a6a0e094e680?w=400'},
        {'name': 'Cable Kickbacks', 'equipment': 'Cable', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'},
        {'name': 'Sumo Deadlifts', 'equipment': 'Barbell', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1517963879433-6ad2b056d712?w=400'},
        {'name': 'Step-Ups', 'equipment': 'Dumbbells', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1434608519344-49d77a699e1d?w=400'},
      ],
      'calves': [
        {'name': 'Standing Calf Raises', 'equipment': 'Machine', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400'},
        {'name': 'Seated Calf Raises', 'equipment': 'Machine', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?w=400'},
        {'name': 'Donkey Calf Raises', 'equipment': 'Machine', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400'},
        {'name': 'Jump Rope', 'equipment': 'Bodyweight', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1434608519344-49d77a699e1d?w=400'},
      ],
      'forearms': [
        {'name': 'Wrist Curls', 'equipment': 'Barbell', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1581009146145-b5ef050c2e1e?w=400'},
        {'name': 'Reverse Wrist Curls', 'equipment': 'Barbell', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?w=400'},
        {'name': 'Farmer Walks', 'equipment': 'Dumbbells', 'difficulty': 'Intermediate', 'image': 'https://images.unsplash.com/photo-1434608519344-49d77a699e1d?w=400'},
        {'name': 'Plate Pinches', 'equipment': 'Plates', 'difficulty': 'Beginner', 'image': 'https://images.unsplash.com/photo-1517963879433-6ad2b056d712?w=400'},
      ],
    };

    final exercises = exercisesByGroup[groupId] ?? [];
    return List.generate(count, (index) {
      if (index < exercises.length) {
        return {
          'id': '${groupId}_$index',
          'name': exercises[index]['name']!,
          'equipment': exercises[index]['equipment']!,
          'difficulty': exercises[index]['difficulty']!,
          'image': exercises[index]['image']!,
          'muscleGroup': muscleGroup['name'],
          'isFavorite': false,
        };
      } else {
        return {
          'id': '${groupId}_$index',
          'name': 'Exercise ${index + 1}',
          'equipment': 'Various',
          'difficulty': 'Beginner',
          'image': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400',
          'muscleGroup': muscleGroup['name'],
          'isFavorite': false,
        };
      }
    });
  }

  List<Map<String, dynamic>> get _filteredExercises {
    if (_searchQuery.isEmpty) return _exercises;
    return _exercises.where((e) => e['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  // ─── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final exercises = _filteredExercises;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ).paddingAll(8),
        ),
        title: Text(
          muscleGroup['name'] ?? 'Exercises',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.black),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.white,
                hintText: 'Search exercise',
                hintStyle: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF9E9E9E)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(0xFF9E9E9E)),
                        onPressed: () => setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        }),
                      )
                    : const Icon(Icons.search, color: Color(0xFF9E9E9E)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(50),
                  borderSide: const BorderSide(color: AppColors.accent, width: 1),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
              ),
            ),
          ),

          // ── Grid ────────────────────────────────────────────────────
          Expanded(
            child: exercises.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
                        const SizedBox(height: 16),
                        Text('No exercises found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14.h, crossAxisSpacing: 12.w, childAspectRatio: 0.78),
                    itemCount: exercises.length,
                    itemBuilder: (context, i) => _buildExerciseCard(exercises[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Exercise card ────────────────────────────────────────────────────
  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    final imageUrl = exercise['image'] as String? ?? '';

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.exerciseDetail, arguments: exercise),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8), width: 0.8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image with play overlay ────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.accent.withOpacity(0.06),
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                      );
                    },
                    errorBuilder: (c, e, s) => Container(
                      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1)),
                      child: const Center(child: Icon(Icons.fitness_center, color: AppColors.accent, size: 32)),
                    ),
                  ),
                ),
                // Centered play button
                Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
                  child: Icon(Icons.play_arrow_rounded, color: AppColors.accent, size: 22.w),
                ),
              ],
            ),

            // ── Info section ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(10.w, 10.h, 10.w, 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    exercise['name'] ?? '',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: Colors.black87, fontSize: 13.sp),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  // Equipment pill
                  _tagPill(exercise['equipment'] ?? '', const Color(0xFFF0F0F0), Colors.black54),
                  SizedBox(height: 5.h),
                  // Difficulty pill
                  _tagPill(exercise['difficulty'] ?? '', const Color(0xFFE8F5E3), AppColors.accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Small tag pill ───────────────────────────────────────────────────
  Widget _tagPill(String text, Color bg, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(50)),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(color: textColor, fontSize: 10.5.sp, fontWeight: FontWeight.w500),
      ),
    );
  }
}
