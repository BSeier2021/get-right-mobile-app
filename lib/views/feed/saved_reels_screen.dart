import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/trainer_certification_helper.dart';
import 'package:get_right/utils/feed_post_mapper.dart';
import 'package:get_right/views/feed/feed_reel_overlay.dart';
import 'package:get_right/views/home/dashboard_screen.dart';

List<Map<String, dynamic>> _mapSavedFeedsToPosts(List<dynamic> savedFeedsRaw) {
  final out = <Map<String, dynamic>>[];
  for (final item in savedFeedsRaw) {
    if (item is! Map) continue;
    final wrap = Map<String, dynamic>.from(item);
    final feed = wrap['feed'];
    if (feed is! Map) continue;
    final post = mapApiFeedDocumentToUiPost(Map<String, dynamic>.from(feed), savedByMe: true);
    if ((post['id'] ?? '').toString().isEmpty) continue;
    out.add(post);
  }
  return out;
}

/// Saved reels from `GET /user/feed/save` (`data.savedFeeds[]`).
class SavedReelsScreen extends StatefulWidget {
  const SavedReelsScreen({super.key});

  @override
  State<SavedReelsScreen> createState() => _SavedReelsScreenState();
}

class _SavedReelsScreenState extends State<SavedReelsScreen> {
  final FeedRepository _feedRepo = FeedRepository();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _posts = <Map<String, dynamic>>[];

  static const int _perPage = 20;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasNext = true;
  bool _loadMoreQueued = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _coerceBool(dynamic v) {
    if (v == true) return true;
    if (v == false) return false;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    if (v is num) return v != 0;
    return false;
  }

  bool _readHasNextPage(Map<String, dynamic> data) {
    final direct = data['hasNextPage'] ?? data['has_next_page'] ?? data['hasNext'];
    if (direct != null) {
      if (_coerceBool(direct)) return true;
      if (direct == false || (direct is String && ['false', '0', 'no'].contains(direct.toString().trim().toLowerCase()))) {
        return false;
      }
    }
    final cp = data['currentPage'] ?? data['page'];
    final tp = data['totalPages'] ?? data['total_pages'];
    if (cp is num && tp is num) {
      return cp.toInt() < tp.toInt();
    }
    return false;
  }

  void _onScroll() {
    if (!_hasNext || _loading || _loadingMore || _error != null) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels < _scrollController.position.maxScrollExtent - 200) return;
    if (_loadMoreQueued) return;
    _loadMoreQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMoreQueued = false;
      if (!mounted) return;
      if (!_hasNext || _loading || _loadingMore) return;
      _load(reset: false);
    });
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (!_hasNext || _loadingMore)) return;
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
        _hasNext = true;
        _posts.clear();
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final pageToFetch = reset ? 1 : _page;

    try {
      final raw = await _feedRepo.getSavedFeedsRepo(page: pageToFetch, limit: _perPage);
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data'] as Map) : <String, dynamic>{};
      final savedRaw = (data['savedFeeds'] is List) ? List.from(data['savedFeeds'] as List) : const <dynamic>[];
      final mapped = _mapSavedFeedsToPosts(savedRaw);

      if (!mounted) return;
      setState(() {
        _posts.addAll(mapped);
        _hasNext = _readHasNextPage(data);
        _page = pageToFetch + 1;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
        if (_posts.isNotEmpty) _hasNext = false;
      });
    }
  }

  void _openPost(int index) {
    if (index < 0 || index >= _posts.length) return;
    final id = (_posts[index]['id'] ?? '').toString().trim();
    if (id.isEmpty) {
      Get.snackbar('Feed', 'This post could not be opened.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    Get.toNamed(AppRoutes.feedSingleReel, arguments: <String, dynamic>{'feedId': id});
  }

  void _openFeedTab() {
    if (Get.isRegistered<HomeNavigationController>()) {
      Get.find<HomeNavigationController>().changeTab(1);
      Get.back();
      return;
    }
    Get.offNamed(AppRoutes.home, arguments: {'navigateToTab': 1});
  }

  Widget _buildGridItem(Map<String, dynamic> post, int index) {
    final showVerified = showFeedCreatorVerifiedBadge(post);
    final isVideo = post['isVideo'] == true;
    return GestureDetector(
      onTap: () => _openPost(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FeedReelStyledThumbnail(post: post),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)]),
            ),
          ),
          if (isVideo)
            Center(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)],
                ),
                child: Icon(Icons.play_arrow, color: AppColors.accent, size: 24),
              ),
            ),
          if (showVerified)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color.fromARGB(153, 71, 71, 71), shape: BoxShape.circle),
                child: verifiedBadgeIcon(size: 18),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        centerTitle: true,
        title: Text('Saved Reels', style: AppTextStyles.titleLarge.copyWith()),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Could not load saved reels', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _load(reset: true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(Icons.bookmark_border, size: 64, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text(
              'No saved reels',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Reels you save from the feed appear here',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openFeedTab,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Browse feed'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1),
              delegate: SliverChildBuilderDelegate((context, index) => _buildGridItem(_posts[index], index), childCount: _posts.length),
            ),
          ),
          if (_loadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Center(
                  child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
