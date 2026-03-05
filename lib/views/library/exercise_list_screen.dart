import 'package:flutter/material.dart';
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
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  late Map<String, dynamic> muscleGroup;
  bool _isSearchBarVisible = true;
  double _lastScrollOffset = 0;

  // Mock exercises data based on muscle group
  List<Map<String, dynamic>> _exercises = [];

  @override
  void initState() {
    super.initState();
    muscleGroup = Get.arguments as Map<String, dynamic>;
    _loadExercises();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final currentScrollOffset = _scrollController.offset;

    // Only hide/show if scrolled enough (threshold to avoid jittery behavior)
    if ((currentScrollOffset - _lastScrollOffset).abs() > 10) {
      if (currentScrollOffset > _lastScrollOffset && currentScrollOffset > 50) {
        // Scrolling down
        if (_isSearchBarVisible) {
          setState(() {
            _isSearchBarVisible = false;
          });
        }
      } else if (currentScrollOffset < _lastScrollOffset) {
        // Scrolling up
        if (!_isSearchBarVisible) {
          setState(() {
            _isSearchBarVisible = true;
          });
        }
      }
      _lastScrollOffset = currentScrollOffset;
    }
  }

  void _loadExercises() {
    // Generate mock exercises based on muscle group
    final groupId = muscleGroup['id'];
    final exerciseCount = muscleGroup['exerciseCount'];

    _exercises = _getExercisesForMuscleGroup(groupId, exerciseCount);
  }

  List<Map<String, dynamic>> _getExercisesForMuscleGroup(String groupId, int count) {
    // Mock data - in real app, this would come from a database or API
    final Map<String, List<Map<String, String>>> exercisesByGroup = {
      'chest': [
        {'name': 'Barbell Bench Press', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Incline Dumbbell Press', 'equipment': 'Dumbbells', 'difficulty': 'Intermediate'},
        {'name': 'Push-Ups', 'equipment': 'Bodyweight', 'difficulty': 'Beginner'},
        {'name': 'Cable Flyes', 'equipment': 'Cable', 'difficulty': 'Beginner'},
        {'name': 'Dips', 'equipment': 'Bodyweight', 'difficulty': 'Intermediate'},
        {'name': 'Decline Bench Press', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Chest Press Machine', 'equipment': 'Machine', 'difficulty': 'Beginner'},
        {'name': 'Dumbbell Flyes', 'equipment': 'Dumbbells', 'difficulty': 'Beginner'},
      ],
      'back': [
        {'name': 'Pull-Ups', 'equipment': 'Bodyweight', 'difficulty': 'Intermediate'},
        {'name': 'Barbell Rows', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Lat Pulldowns', 'equipment': 'Cable', 'difficulty': 'Beginner'},
        {'name': 'Deadlifts', 'equipment': 'Barbell', 'difficulty': 'Advanced'},
        {'name': 'Seated Cable Rows', 'equipment': 'Cable', 'difficulty': 'Beginner'},
        {'name': 'T-Bar Rows', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Face Pulls', 'equipment': 'Cable', 'difficulty': 'Beginner'},
        {'name': 'Dumbbell Rows', 'equipment': 'Dumbbells', 'difficulty': 'Beginner'},
      ],
      'shoulders': [
        {'name': 'Overhead Press', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Lateral Raises', 'equipment': 'Dumbbells', 'difficulty': 'Beginner'},
        {'name': 'Front Raises', 'equipment': 'Dumbbells', 'difficulty': 'Beginner'},
        {'name': 'Arnold Press', 'equipment': 'Dumbbells', 'difficulty': 'Intermediate'},
        {'name': 'Face Pulls', 'equipment': 'Cable', 'difficulty': 'Beginner'},
        {'name': 'Upright Rows', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Reverse Flyes', 'equipment': 'Dumbbells', 'difficulty': 'Beginner'},
        {'name': 'Cable Lateral Raises', 'equipment': 'Cable', 'difficulty': 'Beginner'},
      ],
      'quads': [
        {'name': 'Barbell Squats', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Leg Press', 'equipment': 'Machine', 'difficulty': 'Beginner'},
        {'name': 'Lunges', 'equipment': 'Dumbbells', 'difficulty': 'Beginner'},
        {'name': 'Leg Extensions', 'equipment': 'Machine', 'difficulty': 'Beginner'},
        {'name': 'Bulgarian Split Squats', 'equipment': 'Dumbbells', 'difficulty': 'Intermediate'},
        {'name': 'Front Squats', 'equipment': 'Barbell', 'difficulty': 'Advanced'},
        {'name': 'Goblet Squats', 'equipment': 'Dumbbell', 'difficulty': 'Beginner'},
        {'name': 'Hack Squats', 'equipment': 'Machine', 'difficulty': 'Intermediate'},
      ],
      'hamstrings': [
        {'name': 'Romanian Deadlifts', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Leg Curls', 'equipment': 'Machine', 'difficulty': 'Beginner'},
        {'name': 'Nordic Curls', 'equipment': 'Bodyweight', 'difficulty': 'Advanced'},
        {'name': 'Good Mornings', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Single-Leg Deadlifts', 'equipment': 'Dumbbells', 'difficulty': 'Intermediate'},
        {'name': 'Glute Ham Raises', 'equipment': 'Machine', 'difficulty': 'Advanced'},
        {'name': 'Swiss Ball Curls', 'equipment': 'Stability Ball', 'difficulty': 'Beginner'},
      ],
      'triceps': [
        {'name': 'Close-Grip Bench Press', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Tricep Pushdowns', 'equipment': 'Cable', 'difficulty': 'Beginner'},
        {'name': 'Overhead Extensions', 'equipment': 'Dumbbell', 'difficulty': 'Beginner'},
        {'name': 'Dips', 'equipment': 'Bodyweight', 'difficulty': 'Intermediate'},
        {'name': 'Skull Crushers', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
        {'name': 'Kickbacks', 'equipment': 'Dumbbells', 'difficulty': 'Beginner'},
        {'name': 'Diamond Push-Ups', 'equipment': 'Bodyweight', 'difficulty': 'Intermediate'},
      ],
      'biceps': [
        {'name': 'Barbell Curls', 'equipment': 'Barbell', 'difficulty': 'Beginner'},
        {'name': 'Hammer Curls', 'equipment': 'Dumbbells', 'difficulty': 'Beginner'},
        {'name': 'Preacher Curls', 'equipment': 'Barbell', 'difficulty': 'Beginner'},
        {'name': 'Cable Curls', 'equipment': 'Cable', 'difficulty': 'Beginner'},
        {'name': 'Concentration Curls', 'equipment': 'Dumbbell', 'difficulty': 'Beginner'},
        {'name': 'Incline Curls', 'equipment': 'Dumbbells', 'difficulty': 'Beginner'},
        {'name': 'Spider Curls', 'equipment': 'Barbell', 'difficulty': 'Intermediate'},
      ],
      'core': [
        {'name': 'Planks', 'equipment': 'Bodyweight', 'difficulty': 'Beginner'},
        {'name': 'Crunches', 'equipment': 'Bodyweight', 'difficulty': 'Beginner'},
        {'name': 'Russian Twists', 'equipment': 'Medicine Ball', 'difficulty': 'Beginner'},
        {'name': 'Hanging Leg Raises', 'equipment': 'Pull-up Bar', 'difficulty': 'Advanced'},
        {'name': 'Cable Crunches', 'equipment': 'Cable', 'difficulty': 'Intermediate'},
        {'name': 'Ab Wheel Rollouts', 'equipment': 'Ab Wheel', 'difficulty': 'Advanced'},
        {'name': 'Dead Bugs', 'equipment': 'Bodyweight', 'difficulty': 'Beginner'},
        {'name': 'Bicycle Crunches', 'equipment': 'Bodyweight', 'difficulty': 'Beginner'},
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
          'muscleGroup': muscleGroup['name'],
          'isFavorite': false,
        };
      } else {
        return {
          'id': '${groupId}_$index',
          'name': 'Exercise ${index + 1}',
          'equipment': 'Various',
          'difficulty': 'Beginner',
          'muscleGroup': muscleGroup['name'],
          'isFavorite': false,
        };
      }
    });
  }

  List<Map<String, dynamic>> get _filteredExercises {
    if (_searchQuery.isEmpty) {
      return _exercises;
    }
    return _exercises.where((exercise) {
      return exercise['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredExercises = _filteredExercises;

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
        title: Text(muscleGroup['name'], style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent)),
        centerTitle: true,
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.filter_list, color: AppColors.onPrimary),
        //     onPressed: () {
        //       // TODO: Show filter options
        //     },
        //   ),
        // ],
      ),
      body: Column(
        children: [
          // Search Bar with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: _isSearchBarVisible ? 80 : 0,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.transparent,
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF000000)),
                  decoration: InputDecoration(
                    hintText: 'Search exercises',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF404040)),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF404040)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF404040)),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),
          ),

          // Exercise count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              children: [Text('${filteredExercises.length} exercises', style: AppTextStyles.bodyMedium.copyWith(color: const Color.fromARGB(255, 59, 61, 65)))],
            ),
          ),

          // Exercises List
          Expanded(
            child: filteredExercises.isEmpty
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
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filteredExercises.length,
                    itemBuilder: (context, index) {
                      return _buildExerciseCard(filteredExercises[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    final difficultyColor = _getDifficultyColor(exercise['difficulty']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: muscleGroup['color'].withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.play_circle_outline, color: muscleGroup['color'], size: 28),
        ),
        title: Text(
          exercise['name'],
          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Text(exercise['equipment'], style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface, fontSize: 11)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: difficultyColor.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Text(
                  exercise['difficulty'],
                  style: AppTextStyles.labelSmall.copyWith(color: difficultyColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.primaryGray),
        onTap: () {
          Get.toNamed(AppRoutes.exerciseDetail, arguments: exercise);
        },
      ),
    );
  }
}
