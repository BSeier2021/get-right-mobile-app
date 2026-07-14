import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/favorites_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/trainer_certification_helper.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/widgets/safe_circle_network_avatar.dart';

/// Favorites screen — Programs / Bundles tabs backed by `GET /customer/favourites`.
const Color _kFavoritesMintBg = Color(0xFFF7FBF2);
const Color _kFavoritesForestGreen = Color(0xFF234D32);
const Color _kStatsText = Color(0xFF404040);
const Color _kBackButtonFill = Color(0xFFE2F0E5);
const Color _kHotOrange = Color(0xFFEA580C);
const Color _kCertifiedGreen = Color(0xFF16A34A);
const Color _kPriceText = Color(0xFF1A1A1A);

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
    _tabController.addListener(_onTabChanged);
    _favoritesController.loadFavourites(type: 'program', refresh: true);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
    if (_tabController.index == 1 && _favoritesController.bundleFavourites.isEmpty && !_favoritesController.bundlesLoading.value) {
      _favoritesController.loadFavourites(type: 'bundle', refresh: true);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToDetails(Map<String, dynamic> item) {
    final type = item['type']?.toString() ?? 'program';
    if (type == 'bundle') {
      Get.toNamed(AppRoutes.bundleDetail, arguments: item);
      return;
    }
    Get.toNamed(AppRoutes.programDetail, arguments: item);
  }

  Future<void> _removeFavorite(Map<String, dynamic> item) async {
    final id = (item['id'] ?? '').toString();
    final type = item['type']?.toString() ?? 'program';
    if (id.isEmpty) return;
    try {
      await _favoritesController.removeFavorite(id, type: type);
      Get.snackbar(
        'Removed',
        'Removed from favorites',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _kFavoritesForestGreen,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Favorites',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    }
  }

  static String _formatEnrolled(dynamic v) {
    if (v == null) return '0';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toInt().toString();
  }

  static String _formatPrice(dynamic v) {
    if (v == null) return '0.00';
    if (v is num) return v.toStringAsFixed(2);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kFavoritesMintBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            _buildSegmentedControl(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildProgramsBody(), _buildBundlesBody()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Get.back();
                } else {
                  Get.offAllNamed(AppRoutes.home);
                }
              },
              icon: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _kBackButtonFill, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.chevron_left, size: 22, color: _kFavoritesForestGreen),
              ),
            ),
          ),
          Text(
            'Favorites',
            style: AppTextStyles.titleLarge.copyWith(color: _kFavoritesForestGreen, fontWeight: FontWeight.w800, fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kFavoritesForestGreen.withValues(alpha: 0.12)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: _kFavoritesForestGreen,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: _kFavoritesForestGreen.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: _kFavoritesForestGreen,
          labelStyle: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600, fontSize: 14, color: _kFavoritesForestGreen),
          tabs: const [
            Tab(text: 'Programs'),
            Tab(text: 'Bundles'),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramsBody() {
    return Obx(() {
      if (_favoritesController.programsLoading.value && _favoritesController.programFavourites.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: _kFavoritesForestGreen));
      }
      if (_favoritesController.programsError.value != null && _favoritesController.programFavourites.isEmpty) {
        return _buildErrorState(
          _favoritesController.programsError.value!,
          onRetry: () => _favoritesController.loadFavourites(type: 'program', refresh: true),
        );
      }
      if (_favoritesController.programFavourites.isEmpty) {
        return _buildEmptyState(
          icon: Icons.favorite_border,
          title: 'No favorite programs',
          subtitle: 'Programs you favourite will appear here',
        );
      }

      return RefreshIndicator(
        color: _kFavoritesForestGreen,
        onRefresh: () => _favoritesController.loadFavourites(type: 'program', refresh: true),
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 12, childAspectRatio: 0.52),
          itemCount: _favoritesController.programFavourites.length + (_favoritesController.programsLoadingMore.value ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _favoritesController.programFavourites.length) {
              return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)));
            }
            return _buildProgramCard(_favoritesController.programFavourites[index]);
          },
        ),
      );
    });
  }

  Widget _buildBundlesBody() {
    return Obx(() {
      if (_favoritesController.bundlesLoading.value && _favoritesController.bundleFavourites.isEmpty) {
        return const Center(child: CircularProgressIndicator(color: _kFavoritesForestGreen));
      }
      if (_favoritesController.bundlesError.value != null && _favoritesController.bundleFavourites.isEmpty) {
        return _buildErrorState(
          _favoritesController.bundlesError.value!,
          onRetry: () => _favoritesController.loadFavourites(type: 'bundle', refresh: true),
        );
      }
      if (_favoritesController.bundleFavourites.isEmpty) {
        return _buildEmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No favorite bundles',
          subtitle: 'Bundles you favourite will appear here',
        );
      }

      return RefreshIndicator(
        color: _kFavoritesForestGreen,
        onRefresh: () => _favoritesController.loadFavourites(type: 'bundle', refresh: true),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _favoritesController.bundleFavourites.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) => _buildBundleCard(_favoritesController.bundleFavourites[index]),
        ),
      );
    });
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: _kFavoritesForestGreen.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.titleMedium.copyWith(color: _kFavoritesForestGreen, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: _kStatsText)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, {required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium.copyWith(color: _kStatsText)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildBundleCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? 'Bundle';
    final trainer = item['trainer']?.toString() ?? 'Trainer';
    final imageUrl = ImageUrlSanitizer.asHttpUrlOrFallback(item['imageUrl']?.toString());
    final price = _formatPrice(item['bundlePrice'] ?? item['price']);
    final programs = item['programs'];
    final programCount = programs is List ? programs.length : 0;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: _kFavoritesForestGreen.withValues(alpha: 0.12),
                      alignment: Alignment.center,
                      child: Icon(Icons.inventory_2_outlined, size: 40, color: _kFavoritesForestGreen.withValues(alpha: 0.35)),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _removeFavorite(item),
                        child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.favorite, color: Color(0xFFE11D48), size: 18)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTextStyles.titleSmall.copyWith(color: _kFavoritesForestGreen, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(trainer, style: AppTextStyles.labelSmall.copyWith(color: _kFavoritesForestGreen.withValues(alpha: 0.85))),
                  const SizedBox(height: 4),
                  Text('$programCount ${programCount == 1 ? 'program' : 'programs'}', style: AppTextStyles.labelSmall.copyWith(color: _kStatsText)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: () => _navigateToDetails(item),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kFavoritesForestGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              textStyle: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                height: 1.0,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('View Bundle'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('\$$price', style: AppTextStyles.titleSmall.copyWith(color: _kPriceText, fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? item['name']?.toString() ?? 'Program';
    final trainer = item['trainer']?.toString() ?? 'Trainer';
    final trainerImg = item['trainerImageUrl'] ?? item['trainerImage'];
    final imageUrl = ImageUrlSanitizer.asHttpUrlOrFallback(
      item['imageUrl']?.toString() ?? item['image']?.toString(),
      fallback: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400',
    );
    final rating = item['rating'] is num ? (item['rating'] as num).toDouble() : double.tryParse('${item['rating'] ?? '0'}') ?? 0.0;
    final enrolled = _formatEnrolled(item['students'] ?? item['totalEnrollments']);
    final price = _formatPrice(item['netPrice'] ?? item['price']);
    final showHot = item['hot'] == true || item['isHot'] == true;
    final showCertified = isCertifiedFromUiMap(Map<String, dynamic>.from(item));

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _kFavoritesForestGreen.withValues(alpha: 0.12),
                        alignment: Alignment.center,
                        child: Icon(Icons.fitness_center, size: 40, color: _kFavoritesForestGreen.withValues(alpha: 0.35)),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (showHot) _imageBadge(icon: Icons.local_fire_department_rounded, label: 'Hot', fg: _kHotOrange),
                        if (showCertified) _imageBadge(icon: Icons.verified_rounded, label: 'Certified', fg: _kCertifiedGreen),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _removeFavorite(item),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.favorite, color: Color(0xFFE11D48), size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleSmall.copyWith(color: _kFavoritesForestGreen, fontWeight: FontWeight.w800, fontSize: 13, height: 1.25),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _trainerAvatar(trainerImg, trainer),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          trainer,
                          style: AppTextStyles.labelSmall.copyWith(color: _kFavoritesForestGreen.withValues(alpha: 0.85), fontWeight: FontWeight.w500, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: AppColors.accent),
                      Text(
                        rating.toStringAsFixed(1),
                        style: AppTextStyles.labelSmall.copyWith(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.people_alt_rounded, size: 14, color: Colors.black),
                      Text(
                        enrolled,
                        style: AppTextStyles.labelSmall.copyWith(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: () => _navigateToDetails(item),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kFavoritesForestGreen,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Learn More', style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('\$$price', style: AppTextStyles.titleSmall.copyWith(color: _kPriceText, fontWeight: FontWeight.w800, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageBadge({required IconData icon, required String label, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _trainerAvatar(dynamic trainerImg, String trainer) {
    final s = trainerImg?.toString() ?? '';
    final isUrl = s.startsWith('http://') || s.startsWith('https://');
    if (isUrl) {
      return SafeCircleNetworkAvatar(
        radius: 14,
        imageUrl: s,
        backgroundColor: _kFavoritesForestGreen.withValues(alpha: 0.1),
        fallback: Icon(Icons.person_rounded, size: 16, color: _kFavoritesForestGreen.withValues(alpha: 0.6)),
      );
    }
    final initials = s.length <= 3
        ? (s.isNotEmpty
              ? s
              : trainer.isNotEmpty
              ? trainer[0]
              : '?')
        : s.substring(0, 1);
    return CircleAvatar(
      radius: 14,
      backgroundColor: _kFavoritesForestGreen.withValues(alpha: 0.15),
      child: Text(
        initials.toUpperCase(),
        style: AppTextStyles.labelSmall.copyWith(color: _kFavoritesForestGreen, fontWeight: FontWeight.w800, fontSize: 11),
      ),
    );
  }
}
