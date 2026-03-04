import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/favorites_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Favorites Screen - Shows all favorite programs and exercises
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FavoritesController _favoritesController = Get.put(FavoritesController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToDetails(Map<String, dynamic> item) {
    final type = item['type'] ?? 'program';
    if (type == 'program') {
      Get.toNamed(AppRoutes.programDetail, arguments: item);
    } else if (type == 'exercise') {
      Get.toNamed(AppRoutes.exerciseDetail, arguments: item);
    }
  }

  void _removeFavorite(String id) {
    _favoritesController.removeFavorite(id);
    Get.snackbar(
      'Removed',
      'Removed from favorites',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppColors.primaryGray,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withOpacity(0.1), width: 1),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Get.back();
            } else {
              Get.offAllNamed(AppRoutes.home);
            }
          },
        ),
        title: Text('Favorites', style: AppTextStyles.titleLarge.copyWith()),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.onPrimary,
          unselectedLabelColor: AppColors.onPrimary.withOpacity(0.6),
          labelStyle: AppTextStyles.titleSmall,
          tabs: const [
            Tab(text: 'Programs'),
            Tab(text: 'Exercises'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Programs Tab
          Obx(() => _buildFavoritesList(_favoritesController.getFavoritesByType('program'), 'program')),

          // Exercises Tab
          Obx(() => _buildFavoritesList(_favoritesController.getFavoritesByType('exercise'), 'exercise')),
        ],
      ),
    );
  }

  Widget _buildFavoritesList(List<Map<String, dynamic>> items, String type) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.1),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
                ),
                child: Icon(Icons.favorite_border, size: 60, color: AppColors.accent.withOpacity(0.6)),
              ),
              const SizedBox(height: 24),
              Text(
                'No Favorites Yet',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                type == 'program' ? 'Mark programs as favorites to see them here' : 'Mark exercises as favorites to see them here',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to home and switch to appropriate tab
                  Get.offAllNamed(
                    AppRoutes.home,
                    arguments: {
                      'navigateToTab': type == 'program' ? 0 : 3, // 0 = Marketplace, 3 = Library
                    },
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                icon: Icon(type == 'program' ? Icons.explore : Icons.library_books, color: AppColors.onAccent),
                label: Text(
                  type == 'program' ? 'Browse Programs' : 'Browse Exercises',
                  style: AppTextStyles.buttonMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildFavoriteCard(item);
      },
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> item) {
    final type = item['type'] ?? 'program';
    final id = item['id']?.toString() ?? item['title']?.toString() ?? '';

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      onDismissed: (_) => _removeFavorite(id),
      child: GestureDetector(
        onTap: () => _navigateToDetails(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
            boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.9), AppColors.accentVariant], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Icon(type == 'program' ? Icons.school : Icons.sports_gymnastics, color: AppColors.onAccent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] ?? '',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (item['trainer'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'by ${item['trainer']}',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeFavorite(id),
                    icon: const Icon(Icons.favorite, color: Colors.red, size: 24),
                    tooltip: 'Remove from favorites',
                  ),
                ],
              ),
              if (item['description'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  item['description'],
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (item['category'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: Text(
                        item['category'],
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  if (item['category'] != null && item['duration'] != null) const SizedBox(width: 8),
                  if (item['duration'] != null) ...[
                    Icon(Icons.schedule, size: 16, color: AppColors.primaryGray),
                    const SizedBox(width: 4),
                    Text(item['duration'], style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                  ],
                  const Spacer(),
                  if (item['price'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '\$${item['price']}',
                        style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
