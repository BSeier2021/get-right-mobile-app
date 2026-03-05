import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:get/get.dart';
import 'package:get_right/controllers/favorites_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Bundle Detail Screen - Shows bundle information and included programs
class BundleDetailScreen extends StatefulWidget {
  const BundleDetailScreen({super.key});

  @override
  State<BundleDetailScreen> createState() => _BundleDetailScreenState();
}

class _BundleDetailScreenState extends State<BundleDetailScreen> {
  final FavoritesController _favoritesController = Get.put(FavoritesController());

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> bundle = Get.arguments ?? _getMockBundleData();
    final bundleId = (bundle['id']?.toString() ?? bundle['title']?.toString() ?? 'unknown_bundle').replaceAll(' ', '_');
    final programs = bundle['programs'] as List<Map<String, dynamic>>? ?? [];
    final totalValue = bundle['totalValue'] as double? ?? 0.0;
    final bundlePrice = bundle['bundlePrice'] as double? ?? 0.0;
    final discount = bundle['discount'] as int? ?? 0;

    // Ensure required fields have defaults
    final safeBundle = {
      'id': bundleId,
      'title': bundle['title'] ?? 'Bundle',
      'description': bundle['description'] ?? 'No description available',
      'discount': discount,
      'totalValue': totalValue,
      'bundlePrice': bundlePrice,
      'programs': programs,
      ...bundle, // Keep any additional fields
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,

      child: SafeArea(
        bottom: false,
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              // App Bar with Bundle Header
              SliverAppBar(
                backgroundColor: AppColors.backgroundColor,
                expandedHeight: 250,
                pinned: true,
                automaticallyImplyLeading: false,
                actions: [
                  // Favorite Icon
                  Obx(() {
                    final isFavorite = _favoritesController.isFavorite(bundleId);
                    return IconButton(
                      onPressed: () {
                        _favoritesController.toggleFavorite(bundleId, {...safeBundle, 'type': 'bundle'});
                        Get.snackbar(
                          isFavorite ? 'Removed' : 'Added',
                          isFavorite ? 'Removed from favorites' : 'Added to favorites',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: isFavorite ? AppColors.primaryGray : AppColors.completed,
                          colorText: Colors.white,
                          duration: const Duration(seconds: 2),
                        );
                      },
                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : AppColors.completed),
                    );
                  }),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Bundle Thumbnail Image
                      Image.network(
                        bundle['imageUrl'] ?? 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=800&h=400&fit=crop',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.8), AppColors.accentVariant], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inventory_2, size: 80, color: AppColors.onAccent.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(color: AppColors.onAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                    '$discount% OFF',
                                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.onAccent, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Dark overlay for better text visibility
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.3)]),
                        ),
                      ),
                      // Discount badge overlay
                      Positioned(
                        top: 10,
                        right: 40,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3D060),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Text(
                            '$discount% OFF',
                            style: AppTextStyles.titleSmall.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        child: SafeArea(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.arrow_back, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, AppColors.background]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Bundle Title
                      Text(
                        safeBundle['title'] ?? 'Bundle',
                        style: AppTextStyles.headlineMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(safeBundle['description'] ?? 'No description available', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, height: 1.6)),
                      const SizedBox(height: 24),

                      // Pricing Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [AppColors.accent.withOpacity(0.1), AppColors.accentVariant.withOpacity(0.05)]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accent, width: 2),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Total Value', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
                                    Text(
                                      '\$${totalValue.toStringAsFixed(2)}',
                                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray, decoration: TextDecoration.lineThrough),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Bundle Price', style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent)),
                                    Text(
                                      '\$${bundlePrice.toStringAsFixed(2)}',
                                      style: AppTextStyles.headlineMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.completed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.savings, color: AppColors.completed, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Save \$${(totalValue - bundlePrice).toStringAsFixed(2)} (${discount}% OFF)',
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.completed, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Included Programs Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Included Programs',
                            style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              '${programs.length} Programs',
                              style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...programs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final program = entry.value;
                        return _buildProgramCard(program, index + 1);
                      }),
                      const SizedBox(height: 24),

                      // What's Included
                      Text(
                        'What\'s Included',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureItem(Icons.fitness_center, 'Access to all ${programs.length} programs'),
                      _buildFeatureItem(Icons.video_library, 'Video demonstrations for all exercises'),
                      _buildFeatureItem(Icons.track_changes, 'Progress tracking and analytics'),
                      _buildFeatureItem(Icons.chat, 'Direct messaging with all trainers'),
                      _buildFeatureItem(Icons.library_books, 'Comprehensive nutrition guides'),
                      _buildFeatureItem(Icons.calendar_today, 'Lifetime access to all programs'),
                      _buildFeatureItem(Icons.savings, 'Special bundle discount (${discount}% OFF)'),
                      const SizedBox(height: 20), // Space for bottom bar
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bottom Purchase Bar
          bottomNavigationBar: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bundle Price', style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGray)),
                      Row(
                        children: [
                          Text(
                            '\$${totalValue.toStringAsFixed(2)}',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, decoration: TextDecoration.lineThrough),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '\$${bundlePrice.toStringAsFixed(2)}',
                            style: AppTextStyles.headlineMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Get.toNamed(AppRoutes.purchaseDetails, arguments: {'isBundle': true});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.shopping_cart, size: 20),
                      label: Text('Enroll Bundle', style: AppTextStyles.labelLarge.copyWith(color: AppColors.onAccent)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> program, int programNumber) {
    return GestureDetector(
      onTap: () {
        Get.toNamed(AppRoutes.programDetail, arguments: program);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGray.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
              child: Center(
                child: Text(
                  '$programNumber',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.accent,
              child: Text(program['trainerImage'] ?? 'UT', style: AppTextStyles.titleSmall.copyWith(color: AppColors.onAccent)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    program['title'] ?? 'Program',
                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: AppColors.primaryGray),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          program['trainer'] ?? 'Trainer',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: AppColors.upcoming, size: 14),
                      const SizedBox(width: 4),
                      Text('${program['rating'] ?? 0.0}', style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
                      const SizedBox(width: 12),
                      Icon(Icons.schedule, size: 14, color: AppColors.primaryGray),
                      const SizedBox(width: 4),
                      Text(program['duration'] ?? '', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${program['price'] ?? 0.0}',
                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
                Icon(Icons.chevron_right, color: AppColors.primaryGray),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getMockBundleData() {
    return {
      'id': 'bundle_1',
      'title': 'Complete Fitness Bundle',
      'description': 'Full body transformation program',
      'discount': 25,
      'totalValue': 159.97,
      'bundlePrice': 119.99,
      'programs': [
        {
          'id': 'program_1',
          'title': 'Complete Strength Program',
          'trainer': 'Sarah Johnson',
          'trainerImage': 'SJ',
          'price': 49.99,
          'duration': '12 weeks',
          'category': 'Strength',
          'goal': 'Muscle Building',
          'certified': true,
          'rating': 4.8,
          'students': 1250,
        },
      ],
    };
  }
}
