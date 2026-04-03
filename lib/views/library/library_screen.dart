import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Library screen - exercise library organized by muscle groups
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ─── Muscle‑group data with PNG asset paths ─────────────────────────────
  final List<Map<String, dynamic>> _muscleGroups = [
    {'id': 'chest', 'name': 'Chest', 'exerciseCount': 25, 'image': 'assets/images/1. Chest 2.png'},
    {'id': 'back', 'name': 'Back', 'exerciseCount': 25, 'image': 'assets/images/2. Back 1.png'},
    {'id': 'shoulders', 'name': 'Shoulders', 'exerciseCount': 25, 'image': 'assets/images/3. Shoulders 1.png'},
    {'id': 'quads', 'name': 'Quads', 'exerciseCount': 24, 'image': 'assets/images/4. Quads 1.png'},
    {'id': 'hamstrings', 'name': 'Hamstrings', 'exerciseCount': 20, 'image': 'assets/images/5. Hamstring 1.png'},
    {'id': 'triceps', 'name': 'Triceps', 'exerciseCount': 25, 'image': 'assets/images/6. Triceps 1.png'},
    {'id': 'biceps', 'name': 'Biceps', 'exerciseCount': 24, 'image': 'assets/images/7. Biceps 1.png'},
    {'id': 'core', 'name': 'Core', 'exerciseCount': 30, 'image': 'assets/images/8. core.png'},
    {'id': 'glutes', 'name': 'Glutes', 'exerciseCount': 18, 'image': 'assets/images/9. Glutes 1.png'},
    {'id': 'calves', 'name': 'Calves', 'exerciseCount': 12, 'image': 'assets/images/10. Calves 1.png'},
    {'id': 'forearms', 'name': 'Forearms', 'exerciseCount': 15, 'image': 'assets/images/11. Forearms 1.png'},
  ];

  List<Map<String, dynamic>> get _filteredMuscleGroups {
    if (_searchQuery.isEmpty) return _muscleGroups;
    return _muscleGroups.where((g) => g['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _filteredMuscleGroups;

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
          'Library',
          style: AppTextStyles.titleLarge.copyWith(color: AppColors.accent, fontWeight: FontWeight.w900),
        ),
      ),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────────────
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

          // ── Grid ──────────────────────────────────────────────────────
          Expanded(
            child: groups.isEmpty
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
                : GridView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 16.h, crossAxisSpacing: 8.w, childAspectRatio: 0.72),
                    itemCount: groups.length,
                    itemBuilder: (context, i) => _buildMuscleGroupTile(groups[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Single grid tile ─────────────────────────────────────────────────
  Widget _buildMuscleGroupTile(Map<String, dynamic> group) {
    final imagePath = group['image'] as String;

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.exerciseList, arguments: group),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Circular image container
          Container(
            width: 68.w,
            height: 68.w,
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE8EFE6)),
            child: ClipOval(
              child: Padding(
                padding: EdgeInsets.all(8.w),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Icon(Icons.fitness_center, color: AppColors.accent, size: 28.w),
                ),
              ),
            ),
          ),
          SizedBox(height: 8.h),
          // Label
          Text(
            group['name'],
            style: AppTextStyles.bodySmall.copyWith(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 11.5.sp),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
