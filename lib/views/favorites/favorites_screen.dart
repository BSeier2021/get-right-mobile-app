import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/favorites_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/text_styles.dart';

/// Favorites screen — pale mint background, Programs / Exercises tabs.
const Color _kFavoritesMintBg = Color(0xFFF7FBF2);
const Color _kFavoritesForestGreen = Color(0xFF234D32);
const Color _kExerciseCardMint = Color(0xFFF2F9E8);
const Color _kColumnHeaderPill = Color(0xFFF5EDE8);
const Color _kStatsText = Color(0xFF404040);
const Color _kBackButtonFill = Color(0xFFE2F0E5);
const Color _kHotOrange = Color(0xFFEA580C);
const Color _kCertifiedGreen = Color(0xFF16A34A);
const Color _kPriceText = Color(0xFF1A1A1A);

/// Two placeholder favorites (shown when the user has no saved program favorites).
final List<Map<String, dynamic>> _kDefaultFavoritePrograms = [
  {
    'id': 'demo_favorite_1',
    'type': 'program',
    '_isDemo': true,
    'title': 'The Ultimate Strength Builder',
    'trainer': 'Sarah Maxwell',
    'trainerImage': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80&h=80&fit=crop',
    'imageUrl': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400',
    'rating': 4.9,
    'students': 1300,
    'price': 49.99,
    'hot': true,
    'certified': true,
  },
  {
    'id': 'demo_favorite_2',
    'type': 'program',
    '_isDemo': true,
    'title': 'The Ultimate Strength Builder',
    'trainer': 'Sarah Maxwell',
    'trainerImage': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=80&h=80&fit=crop',
    'imageUrl': 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=400',
    'rating': 4.9,
    'students': 1300,
    'price': 49.99,
    'hot': true,
    'certified': true,
  },
];

/// Exercise favorites mock (Sets / Reps / Weight grid) when list is empty.
final List<Map<String, dynamic>> _kDefaultFavoriteExercises = [
  {
    'id': 'demo_exercise_squat',
    'type': 'exercise',
    '_isDemo': true,
    'name': 'Squat',
    'setsColumn': ['01', '02', '03'],
    'repsColumn': ['01', '02', '03'],
    'weightColumn': ['01', '02', '03'],
  },
  {
    'id': 'demo_exercise_bench',
    'type': 'exercise',
    '_isDemo': true,
    'name': 'Bench Press',
    'setsColumn': ['01', '02', '03'],
    'repsColumn': ['01', '02', '03'],
    'weightColumn': ['01', '02', '03'],
  },
];

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
    _tabController.addListener(() => setState(() {}));
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
      backgroundColor: _kFavoritesForestGreen,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  static String _formatEnrolled(dynamic v) {
    if (v == null) return '1.3k';
    final n = v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 1300;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toInt().toString();
  }

  static String _formatPrice(dynamic v) {
    if (v == null) return '49.99';
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
              child: TabBarView(controller: _tabController, children: [_buildProgramsBody(), _buildExercisesBody()]),
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
            Tab(text: 'Exercises'),
          ],
        ),
      ),
    );
  }

  Widget _buildProgramsBody() {
    return Obx(() {
      final favs = _favoritesController.getFavoritesByType('program');
      final items = favs.isEmpty ? _kDefaultFavoritePrograms : favs;
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 12, childAspectRatio: 0.52),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildProgramCard(items[index]),
      );
    });
  }

  Widget _buildExercisesBody() {
    return Obx(() {
      final favs = _favoritesController.getFavoritesByType('exercise');
      final items = favs.isEmpty ? _kDefaultFavoriteExercises : favs;
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _buildExerciseFavoriteCard(items[index]),
      );
    });
  }

  List<String> _exerciseColumnValues(Map<String, dynamic> item, String key, List<String> fallback) {
    final v = item[key];
    if (v is List) {
      return v.map((e) => e.toString()).take(3).toList();
    }
    return List<String>.from(fallback);
  }

  IconData _exerciseLeadIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('squat') || n.contains('leg')) return Icons.directions_run_rounded;
    if (n.contains('bench') || n.contains('chest') || n.contains('press')) return Icons.fitness_center_rounded;
    if (n.contains('dead')) return Icons.sports_mma_rounded;
    return Icons.sports_gymnastics_rounded;
  }

  Widget _buildExerciseFavoriteCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? item['name']?.toString() ?? '';
    final name = item['name']?.toString() ?? item['title']?.toString() ?? 'Exercise';
    final isDemo = item['_isDemo'] == true;
    final sets = _exerciseColumnValues(item, 'setsColumn', const ['01', '02', '03']);
    final reps = _exerciseColumnValues(item, 'repsColumn', const ['01', '02', '03']);
    final weights = _exerciseColumnValues(item, 'weightColumn', const ['01', '02', '03']);

    return Container(
      decoration: BoxDecoration(
        color: _kExerciseCardMint,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Icon(_exerciseLeadIcon(name), color: _kFavoritesForestGreen, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyles.titleMedium.copyWith(color: _kFavoritesForestGreen, fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, color: _kFavoritesForestGreen.withValues(alpha: 0.85)),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'remove' && !isDemo) _removeFavorite(id);
                  if (value == 'open') _navigateToDetails(item);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'open', child: Text('View details')),
                  if (!isDemo) const PopupMenuItem(value: 'remove', child: Text('Remove from favorites')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _exerciseStatColumn(icon: Icons.settings_rounded, label: 'Sets', values: sets),
                ),
                Expanded(
                  child: _exerciseStatColumn(icon: Icons.sports_gymnastics_rounded, label: 'Reps', values: reps),
                ),
                Expanded(
                  child: _exerciseStatColumn(icon: Icons.monitor_weight_rounded, label: 'Weight', values: weights),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseStatColumn({required IconData icon, required String label, required List<String> values}) {
    final rows = values.length >= 3 ? values.sublist(0, 3) : [...values, ...List.filled(3 - values.length, '—')];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: _kColumnHeaderPill, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: _kCertifiedGreen),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.labelSmall.copyWith(color: _kFavoritesForestGreen, fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Text(
              e.value,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelLarge.copyWith(color: _kStatsText, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProgramCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? item['title']?.toString() ?? item['name']?.toString() ?? '';
    final title = item['title']?.toString() ?? item['name']?.toString() ?? 'Program';
    final trainer = item['trainer']?.toString() ?? 'Sarah Maxwell';
    final trainerImg = item['trainerImage'];
    final imageUrl = item['imageUrl']?.toString() ?? item['image']?.toString() ?? 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400';
    final rating = item['rating'] is num ? (item['rating'] as num).toDouble() : double.tryParse('${item['rating'] ?? '4.9'}') ?? 4.9;
    final enrolled = _formatEnrolled(item['students']);
    final price = _formatPrice(item['price']);
    final showHot = item['hot'] == true || item['isHot'] == true || (item['hot'] == null && item['isHot'] == null);
    final showCertified = item['certified'] == true || item['isCertified'] == true || (item['certified'] == null && item['isCertified'] == null);
    final isDemo = item['_isDemo'] == true;

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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
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
                  if (!isDemo)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _removeFavorite(id),
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
                      Icon(Icons.star_rounded, size: 14, color: _kCertifiedGreen),
                      Text(
                        rating.toStringAsFixed(1),
                        style: AppTextStyles.labelSmall.copyWith(color: _kFavoritesForestGreen, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.people_alt_rounded, size: 14, color: _kCertifiedGreen),
                      Text(
                        enrolled,
                        style: AppTextStyles.labelSmall.copyWith(color: _kFavoritesForestGreen, fontWeight: FontWeight.w600, fontSize: 11),
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
                            child: Text(
                              'Learn More',
                              style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$$price',
                        style: AppTextStyles.titleSmall.copyWith(color: _kPriceText, fontWeight: FontWeight.w800, fontSize: 14),
                      ),
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
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(color: fg, fontWeight: FontWeight.w700, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _trainerAvatar(dynamic trainerImg, String trainer) {
    final s = trainerImg?.toString() ?? '';
    final isUrl = s.startsWith('http://') || s.startsWith('https://');
    if (isUrl) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: _kFavoritesForestGreen.withValues(alpha: 0.1),
        backgroundImage: NetworkImage(s),
        onBackgroundImageError: (_, __) {},
        child: null,
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
