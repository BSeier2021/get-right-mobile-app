import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Library screen - exercise library organized by muscle groups
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  bool _isSearchBarVisible = true;
  double _lastScrollOffset = 0.0;

  // Icon colors for each muscle group (multiple colors across the library)
  static const Color _chestColor = Color(0xFF29603C); // green (accent)
  static const Color _backColor = Color(0xFF1565C0); // blue
  static const Color _shouldersColor = Color(0xFF7B1FA2); // purple
  static const Color _quadsColor = Color(0xFFE65100); // deep orange
  static const Color _hamstringsColor = Color(0xFF00897B); // teal
  static const Color _tricepsColor = Color(0xFFC62828); // red
  static const Color _bicepsColor = Color(0xFFF9A825); // amber
  static const Color _coreColor = Color(0xFF2E7D32); // dark green
  static const Color _glutesColor = Color(0xFF6A1B9A); // deep purple
  static const Color _calvesColor = Color(0xFF0277BD); // light blue
  static const Color _forearmsColor = Color(0xFFD84315); // orange

  // Mock muscle groups data
  final List<Map<String, dynamic>> _muscleGroups = [
    {'id': 'chest', 'name': 'Chest', 'exerciseCount': 25, 'icon': Icons.fitness_center, 'color': _chestColor},
    {'id': 'back', 'name': 'Back', 'exerciseCount': 25, 'icon': Icons.accessibility_new, 'color': _backColor},
    {'id': 'shoulders', 'name': 'Shoulders', 'exerciseCount': 25, 'icon': Icons.fitness_center, 'color': _shouldersColor},
    {'id': 'quads', 'name': 'Quads', 'exerciseCount': 24, 'icon': Icons.directions_walk, 'color': _quadsColor},
    {'id': 'hamstrings', 'name': 'Hamstrings', 'exerciseCount': 20, 'icon': Icons.directions_run, 'color': _hamstringsColor},
    {'id': 'triceps', 'name': 'Triceps', 'exerciseCount': 25, 'icon': Icons.fitness_center, 'color': _tricepsColor},
    {'id': 'biceps', 'name': 'Biceps', 'exerciseCount': 24, 'icon': Icons.fitness_center, 'color': _bicepsColor},
    {'id': 'core', 'name': 'Core', 'exerciseCount': 30, 'icon': Icons.self_improvement, 'color': _coreColor},
    {'id': 'glutes', 'name': 'Glutes', 'exerciseCount': 18, 'icon': Icons.fitness_center, 'color': _glutesColor},
    {'id': 'calves', 'name': 'Calves', 'exerciseCount': 12, 'icon': Icons.directions_walk, 'color': _calvesColor},
    {'id': 'forearms', 'name': 'Forearms', 'exerciseCount': 15, 'icon': Icons.fitness_center, 'color': _forearmsColor},
  ];

  List<Map<String, dynamic>> get _filteredMuscleGroups {
    if (_searchQuery.isEmpty) {
      return _muscleGroups;
    }
    return _muscleGroups.where((group) {
      return group['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentScrollOffset = _scrollController.offset;
    final scrollDelta = currentScrollOffset - _lastScrollOffset;

    // Only toggle if scrolled more than 10 pixels to avoid jitter
    if (scrollDelta.abs() > 10) {
      if (scrollDelta > 0 && _isSearchBarVisible && currentScrollOffset > 50) {
        // Scrolling down - hide search bar
        setState(() {
          _isSearchBarVisible = false;
        });
      } else if (scrollDelta < 0 && !_isSearchBarVisible) {
        // Scrolling up - show search bar
        setState(() {
          _isSearchBarVisible = true;
        });
      }
      _lastScrollOffset = currentScrollOffset;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredGroups = _filteredMuscleGroups;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.backgroundColor, AppColors.backgroundColor, AppColors.backgroundColor],
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundColor,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
            ).paddingAll(8),
          ),
          title: Text(
            'Library',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          // actions: [
          //   IconButton(
          //     icon: const Icon(Icons.more_vert, color: Color(0xFF000000)),
          //     onPressed: () {
          //       // TODO: Show options menu
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
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _isSearchBarVisible ? 1.0 : 0.0,
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
                      filled: true,
                      fillColor: AppColors.white,
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

                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
            ),

            // Muscle Groups List
            Expanded(
              child: filteredGroups.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
                          const SizedBox(height: 16),
                          Text('No muscle groups found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      itemCount: filteredGroups.length,
                      itemBuilder: (context, index) {
                        return _buildMuscleGroupCard(filteredGroups[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleGroupCard(Map<String, dynamic> muscleGroup) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: muscleGroup['color'].withOpacity(0.15),
            borderRadius: BorderRadius.circular(18), // squircle-like corner radius
          ),
          child: Icon(muscleGroup['icon'], color: muscleGroup['color'], size: 28),
        ),
        title: Text(
          muscleGroup['name'],
          style: AppTextStyles.titleMedium.copyWith(color: const Color(0xFF000000), fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${muscleGroup['exerciseCount']} exercises', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF404040))),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF404040)),
        onTap: () {
          Get.toNamed(AppRoutes.exerciseList, arguments: muscleGroup);
        },
      ),
    );
  }
}
