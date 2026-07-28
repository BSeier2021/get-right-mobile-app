import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/repo/trainer_profile_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/bundle_card_mapper.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// All bundles — `GET /customer/bundle` (browse) or trainer `GET /user/profiles/:id/bundles`.
class AllBundlesScreen extends StatefulWidget {
  const AllBundlesScreen({super.key});

  @override
  State<AllBundlesScreen> createState() => _AllBundlesScreenState();
}

class _AllBundlesScreenState extends State<AllBundlesScreen> {
  final MarketplaceRepository _marketplaceRepo = MarketplaceRepository();
  final TrainerProfileRepository _trainerRepo = TrainerProfileRepository();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _bundles = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _programCatalog = <Map<String, dynamic>>[];

  String? _trainerId;
  String _trainerName = '';
  int _profileBundleCount = 0;

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasNext = true;
  int _page = 1;
  String? _error;

  static const int _perPage = 20;

  @override
  void initState() {
    super.initState();
    _readArguments();
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _readArguments() {
    final args = Get.arguments;
    if (args is Map) {
      _trainerId = (args['trainerId'] ?? args['userId'] ?? args['id'])?.toString().trim();
      _trainerName = (args['trainerName'] ?? args['name'] ?? '').toString().trim();
      if (args['programCatalog'] is List) {
        _programCatalog = (args['programCatalog'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      final seed = args['bundles'];
      if (seed is List && seed.isNotEmpty) {
        _bundles.addAll(seed.whereType<Map>().map((e) => normalizeBundleForCard(Map<String, dynamic>.from(e), defaultTrainer: _trainerName.isNotEmpty ? _trainerName : 'Trainer')));
        _loading = false;
      }
    } else if (args is List && args.isNotEmpty) {
      _bundles.addAll(args.whereType<Map>().map((e) => normalizeBundleForCard(Map<String, dynamic>.from(e))));
      _loading = false;
      _hasNext = false;
    }
  }

  Future<void> _bootstrap() async {
    if (_trainerId != null && _trainerId!.isNotEmpty) {
      await _loadTrainerProfileHeader();
    }
    if (_bundles.isEmpty) {
      await _loadBundles(reset: true);
    } else if (_trainerId != null) {
      _page = 2;
    }
  }

  Future<void> _loadTrainerProfileHeader() async {
    final id = _trainerId;
    if (id == null || id.isEmpty) return;
    try {
      final raw = await _trainerRepo.getProfileDetailsRepo(id);
      final header = parseProfileDetailsHeader(raw);
      if (!mounted || header == null) return;
      setState(() {
        if (_trainerName.isEmpty) _trainerName = (header['name'] ?? '').toString();
        _profileBundleCount = header['bundleCount'] is int ? header['bundleCount'] as int : 0;
      });
    } catch (_) {
      /* optional header */
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore || !_hasNext) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 240) {
      _loadBundles(reset: false);
    }
  }

  Future<void> _loadBundles({required bool reset}) async {
    if (reset) {
      if (_loadingMore) return;
    } else {
      if (_loadingMore || !_hasNext || _loading) return;
    }

    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
        _page = 1;
        _hasNext = true;
        if (_trainerId == null) _bundles.clear();
      } else {
        _loadingMore = true;
      }
    });

    final pageToFetch = reset ? 1 : _page;

    try {
      if (_trainerId != null && _trainerId!.isNotEmpty) {
        await _loadTrainerBundlesPage(pageToFetch, reset: reset);
      } else {
        await _loadMarketplaceBundlesPage(pageToFetch, reset: reset);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (reset) _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadTrainerBundlesPage(int pageToFetch, {required bool reset}) async {
    final raw = await _trainerRepo.getProfileBundlesRepo(_trainerId!, page: pageToFetch, limit: _perPage);
    if (!mounted) return;

    final data = raw is Map && raw['data'] is Map ? Map<String, dynamic>.from(raw['data'] as Map) : <String, dynamic>{};
    final batch = parseProfileBundlesList(raw, trainerName: _trainerName.isNotEmpty ? _trainerName : 'Trainer');
    final total = readPaginatedTotalDocs(data, fallback: _profileBundleCount > 0 ? _profileBundleCount : batch.length);
    final hasNext = readPaginatedHasNext(data);

    setState(() {
      if (reset) _bundles.clear();
      _bundles.addAll(batch);
      if (_profileBundleCount == 0 && total > 0) _profileBundleCount = total;
      _hasNext = hasNext;
      _page = pageToFetch + 1;
      _error = null;
    });
  }

  Future<void> _loadMarketplaceBundlesPage(int pageToFetch, {required bool reset}) async {
    if (_programCatalog.isEmpty && pageToFetch == 1) {
      final programsPage = await _marketplaceRepo.fetchBrowsePrograms(page: 1, perPage: 50);
      _programCatalog = programsPage.programs;
    }

    final page = await _marketplaceRepo.fetchBrowseBundles(page: pageToFetch, perPage: _perPage, programCatalog: _programCatalog);
    if (!mounted) return;

    setState(() {
      if (reset) _bundles.clear();
      _bundles.addAll(page.bundles);
      _hasNext = page.hasMore;
      _page = page.page + 1;
      _error = null;
    });
  }

  String get _countLabel {
    final n = _profileBundleCount > 0 ? _profileBundleCount : _bundles.length;
    return '$n ${n == 1 ? 'Bundle' : 'Bundles'} Available';
  }

  @override
  Widget build(BuildContext context) {
    final title = _trainerName.isNotEmpty ? '$_trainerName Bundles' : 'All Bundles';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
        title: Text(title, style: AppTextStyles.titleLarge.copyWith(), maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _bundles.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (_error != null && _bundles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _error!,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => _loadBundles(reset: true), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_bundles.isEmpty) {
      return Center(
        child: Text('No bundles available', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _loadBundles(reset: true),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(_countLabel, style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.87, crossAxisSpacing: 12, mainAxisSpacing: 12),
              delegate: SliverChildBuilderDelegate((context, index) => _buildBundleCard(context, _bundles[index]), childCount: _bundles.length),
            ),
          ),
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildBundleCard(BuildContext context, Map<String, dynamic> bundle) {
    final programs = (bundle['programs'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? <Map<String, dynamic>>[];
    final totalValue = (bundle['totalValue'] as num?)?.toDouble() ?? 0.0;
    final bundlePrice = (bundle['bundlePrice'] as num?)?.toDouble() ?? 0.0;

    final primaryTrainer = (bundle['trainer'] ?? (programs.isNotEmpty ? programs[0]['trainer'] : null) ?? 'Trainer').toString();

    final bundleIndex = _bundles.indexOf(bundle);
    const thumbnailUrls = [
      'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=400&h=300&fit=crop',
      'https://images.unsplash.com/photo-1517960413843-0aee8e2d471c?w=400&h=300&fit=crop',
    ];

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.bundleDetail, arguments: bundle),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                  child: Image.network(
                    ImageUrlSanitizer.asHttpUrlOrFallback(bundle['imageUrl']?.toString(), fallback: thumbnailUrls[bundleIndex % thumbnailUrls.length]),
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: bundleIndex % 2 == 0 ? [const Color(0xFF9333EA), const Color(0xFFFBBF24)] : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
                        ),
                      ),
                      child: const Center(child: Icon(Icons.fitness_center, size: 40, color: Colors.white)),
                    ),
                  ),
                ),
                if (bundle['isHot'] == true || bundleIndex < 2)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFF3D060), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        'Bestseller',
                        style: AppTextStyles.labelSmall.copyWith(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            (bundle['title'] ?? '').toString(),
                            style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            primaryTrainer,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '\$${bundlePrice.toStringAsFixed(2)}',
                          style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        if (totalValue > bundlePrice) ...[
                          const SizedBox(width: 6),
                          Text(
                            '\$${totalValue.toStringAsFixed(2)}',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray, decoration: TextDecoration.lineThrough, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
