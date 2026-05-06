import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_right/app_url.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:get_right/views/feed/feed_vertical_reels.dart';

/// Community Feed - Social Media Platform for fitness content
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storageService = Get.find<StorageService>();
  final FeedRepository _feedRepo = FeedRepository();
  final Map<int, PageController> _pageControllers = {};
  final List<Map<String, dynamic>> _followingPosts = <Map<String, dynamic>>[];

  bool _loadingForYou = false;
  bool _loadingFollowing = false;
  String? _errorForYou;
  String? _errorFollowing;

  int _pageForYou = 1;
  int _pageFollowing = 1;
  bool _hasNextForYou = true;
  bool _hasNextFollowing = true;
  static const int _perPage = 10;

  final List<Map<String, dynamic>> _feedPosts = <Map<String, dynamic>>[];

  /// Avoid calling [setState]/loaders from [PageView.builder] during build (causes request storms).
  bool _forYouLoadMoreQueued = false;
  bool _followingLoadMoreQueued = false;

  int _forYouFeedEpoch = 0;
  int _followingFeedEpoch = 0;

  void _disposePageControllerForTab(int tabIndex) {
    final c = _pageControllers.remove(tabIndex);
    c?.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      debugPrint('[FeedScreen] Tab changed to index=${_tabController.index}');
      if (_tabController.index == 0 && _feedPosts.isEmpty && !_loadingForYou) {
        _loadForYou(reset: true);
      } else if (_tabController.index == 1 && _followingPosts.isEmpty && !_loadingFollowing) {
        _loadFollowing(reset: true);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadForYou(reset: true);
      _loadFollowing(reset: true);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _pageControllers.values) {
      controller.dispose();
    }
    _pageControllers.clear();
    super.dispose();
  }

  PageController _getPageController(int tabIndex) {
    if (!_pageControllers.containsKey(tabIndex)) {
      _pageControllers[tabIndex] = PageController();
    }
    return _pageControllers[tabIndex]!;
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

  String? _firstNonEmptyUrlString(dynamic v) {
    final s = v?.toString().trim();
    return (s != null && s.isNotEmpty) ? s : null;
  }

  /// Resolves playback URL from various backend shapes (HLS or progressive).
  String? _extractFeedVideoUrl(Map<String, dynamic> m, Map<String, dynamic> video) {
    const videoKeys = ['playbackUrl', 'hlsUrl', 'manifestUrl', 'streamUrl', 'm3u8Url', 'url', 'src', 'fileUrl', 'videoUrl', 'link'];
    for (final k in videoKeys) {
      final fromVideo = _firstNonEmptyUrlString(video[k]);
      if (fromVideo != null) return fromVideo;
    }
    if (video['hls'] is Map) {
      final hls = Map<String, dynamic>.from(video['hls'] as Map);
      for (final k in videoKeys) {
        final s = _firstNonEmptyUrlString(hls[k]);
        if (s != null) return s;
      }
    }
    for (final k in ['videoUrl', 'playbackUrl', 'hlsUrl', 'streamUrl']) {
      final s = _firstNonEmptyUrlString(m[k]);
      if (s != null) return s;
    }
    return null;
  }

  void _queueLoadMoreForYouIfNeeded(int index) {
    if (_feedPosts.isEmpty) return;
    final lastTrigger = _feedPosts.length >= 3 ? _feedPosts.length - 2 : _feedPosts.length - 1;
    if (index < lastTrigger) return;
    if (!_hasNextForYou || _loadingForYou || _errorForYou != null) return;
    if (_forYouLoadMoreQueued) return;
    _forYouLoadMoreQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _forYouLoadMoreQueued = false;
      if (!mounted) return;
      if (!_hasNextForYou || _loadingForYou) return;
      _loadForYou(reset: false);
    });
  }

  void _queueLoadMoreFollowingIfNeeded(int index) {
    if (_followingPosts.isEmpty) return;
    final lastTrigger = _followingPosts.length >= 3 ? _followingPosts.length - 2 : _followingPosts.length - 1;
    if (index < lastTrigger) return;
    if (!_hasNextFollowing || _loadingFollowing || _errorFollowing != null) return;
    if (_followingLoadMoreQueued) return;
    _followingLoadMoreQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _followingLoadMoreQueued = false;
      if (!mounted) return;
      if (!_hasNextFollowing || _loadingFollowing) return;
      _loadFollowing(reset: false);
    });
  }

  Map<String, dynamic> _metadataMapFromFeed(Map<String, dynamic> m, Map<String, dynamic> video) {
    if (video['metadata'] is Map) {
      return Map<String, dynamic>.from(video['metadata'] as Map);
    }
    if (m['metadata'] is Map) {
      return Map<String, dynamic>.from(m['metadata'] as Map);
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _mapApiFeedToPost(dynamic raw) {
    final m = (raw is Map) ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final creator = (m['creator'] is Map) ? Map<String, dynamic>.from(m['creator']) : <String, dynamic>{};
    final profile = (creator['profile'] is Map) ? Map<String, dynamic>.from(creator['profile']) : <String, dynamic>{};
    final profilePicture = (profile['profilePicture'] is Map) ? Map<String, dynamic>.from(profile['profilePicture']) : <String, dynamic>{};
    final category = (m['category'] is Map) ? Map<String, dynamic>.from(m['category']) : <String, dynamic>{};
    final video = (m['video'] is Map) ? Map<String, dynamic>.from(m['video']) : <String, dynamic>{};

    final tagsRaw = (m['tags'] is List) ? List.from(m['tags']) : const [];
    final tags = tagsRaw.map((e) => e.toString()).where((t) => t.trim().isNotEmpty).map((t) => t.startsWith('#') ? t : '#$t').toList();

    final fullName = (profile['fullName'] ?? '').toString().trim();
    final initials = fullName.isEmpty ? 'U' : fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();

    final meta = _metadataMapFromFeed(m, video);
    double? metaW;
    double? metaH;
    double? videoAspectRatio;
    final rawMetaW = meta['width'];
    final rawMetaH = meta['height'];
    if (rawMetaW is num && rawMetaH is num) {
      metaW = rawMetaW.toDouble();
      metaH = rawMetaH.toDouble();
      if (metaW > 0 && metaH > 0) {
        videoAspectRatio = metaW / metaH;
      }
    }

    double? durationSeconds =
        (m['duration'] is num) ? (m['duration'] as num).toDouble() : (meta['duration'] is num ? (meta['duration'] as num).toDouble() : null);
    final durationLabel = durationSeconds == null
        ? null
        : durationSeconds >= 60
        ? '${(durationSeconds ~/ 60)}:${((durationSeconds % 60).round()).toString().padLeft(2, '0')}'
        : durationSeconds >= 10
        ? '${durationSeconds.toStringAsFixed(0)}s'
        : '${durationSeconds.toStringAsFixed(1)}s';

    final resolvedVideoUrl = _extractFeedVideoUrl(m, video) ?? '';
    final thumb = _firstNonEmptyUrlString(video['thumbnail']) ?? _firstNonEmptyUrlString(video['poster']) ?? _firstNonEmptyUrlString(m['thumbnail']) ?? '';

    return <String, dynamic>{
      'id': (m['_id'] ?? '').toString(),
      'creator': fullName.isEmpty ? (creator['email'] ?? 'user').toString() : fullName,
      'creatorImage': initials,
      'creatorAvatarUrl': (profilePicture['url'] ?? '').toString(),
      'title': (m['title'] ?? '').toString(),
      'description': (m['description'] ?? '').toString(),
      'category': (category['name'] ?? '').toString(),
      'tags': tags,
      'videoUrl': resolvedVideoUrl,
      'thumbnail': thumb,
      'likes': (m['likesCount'] is num) ? (m['likesCount'] as num).toInt() : 0,
      'comments': (m['commentsCount'] is num) ? (m['commentsCount'] as num).toInt() : 0,
      'shares': (m['sharesCount'] is num) ? (m['sharesCount'] as num).toInt() : 0,
      'saves': (m['savesCount'] is num) ? (m['savesCount'] as num).toInt() : 0,
      'isLiked': false,
      'isSaved': false,
      'duration': durationLabel,
      // From video.metadata — used to size reels without distorted crop.
      if (videoAspectRatio != null) 'videoAspectRatio': videoAspectRatio,
      if (metaW != null) 'videoPixelWidth': metaW,
      if (metaH != null) 'videoPixelHeight': metaH,
      if (meta['format'] != null) 'videoFormat': meta['format'].toString(),
      if (meta['qualities'] is List)
        'videoQualities': (meta['qualities'] as List).map((e) => e.toString()).toList(),
    };
  }

  Future<void> _loadForYou({required bool reset}) async {
    if (_loadingForYou) return;
    if (!reset && !_hasNextForYou) return;

    setState(() {
      _loadingForYou = true;
      _errorForYou = null;
      if (reset) {
        _pageForYou = 1;
        _hasNextForYou = true;
        _feedPosts.clear();
        _forYouFeedEpoch++;
        _disposePageControllerForTab(0);
      }
    });

    try {
      final raw = await _feedRepo.getFeedsRepo(page: _pageForYou, limit: _perPage);
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data']) : <String, dynamic>{};
      final feedsRaw = (data['feeds'] is List) ? List.from(data['feeds']) : const [];
      final mapped = feedsRaw.map(_mapApiFeedToPost).where((p) => (p['id'] ?? '').toString().isNotEmpty).toList();

      setState(() {
        _feedPosts.addAll(mapped);
        _hasNextForYou = _readHasNextPage(data);
        _pageForYou = _pageForYou + 1;
      });
    } catch (e) {
      setState(() {
        _errorForYou = e.toString();
        if (_feedPosts.isNotEmpty) {
          _hasNextForYou = false;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingForYou = false;
        });
      }
    }
  }

  Future<void> _loadFollowing({required bool reset}) async {
    if (_loadingFollowing) return;
    if (!reset && !_hasNextFollowing) return;

    setState(() {
      _loadingFollowing = true;
      _errorFollowing = null;
      if (reset) {
        _pageFollowing = 1;
        _hasNextFollowing = true;
        _followingPosts.clear();
        _followingFeedEpoch++;
        _disposePageControllerForTab(1);
      }
    });

    try {
      final raw = await _feedRepo.getFeedsRepo(page: _pageFollowing, limit: _perPage, type: 'following');
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data']) : <String, dynamic>{};
      final feedsRaw = (data['feeds'] is List) ? List.from(data['feeds']) : const [];
      final mapped = feedsRaw.map(_mapApiFeedToPost).where((p) => (p['id'] ?? '').toString().isNotEmpty).toList();

      setState(() {
        _followingPosts.addAll(mapped);
        _hasNextFollowing = _readHasNextPage(data);
        _pageFollowing = _pageFollowing + 1;
      });
    } catch (e) {
      debugPrint('[FeedScreen] Error loading following: $e');
      setState(() {
        _errorFollowing = e.toString();
        if (_followingPosts.isNotEmpty) {
          _hasNextFollowing = false;
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingFollowing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.backgroundColor, AppColors.backgroundColor, AppColors.backgroundColor]),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Obx(() {
            final notificationController = Get.find<NotificationController>();
            final unreadCount = notificationController.unreadCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Image.asset('assets/images/humburger.png', width: 25.w),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ).paddingOnly(left: 10),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1.0),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          }),
          title: AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              final isForYou = _tabController.index == 0;
              final isFollowing = _tabController.index == 1;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _tabController.animateTo(0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'For You',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Container(width: 48, height: 2, color: isForYou ? AppColors.accent : Colors.transparent),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  GestureDetector(
                    onTap: () => _tabController.animateTo(1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Following',
                          style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface.withOpacity(0.8), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Container(width: 62, height: 2, color: isFollowing ? AppColors.accent : Colors.transparent),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Image.asset('assets/images/search-normal000.png', width: 20.w),

              onPressed: () {
                _showSearchScreen();
              },
            ).paddingOnly(right: 5),
          ],
          bottom: PreferredSize(preferredSize: const Size.fromHeight(0), child: Container()),
        ),
        body: ColoredBox(
          color: Colors.black,
          child: TabBarView(controller: _tabController, children: [_buildForYouFeed(), _buildFollowingFeed()]),
        ),
      ),
    );
  }

  Widget _buildForYouFeed() {
    if (_errorForYou != null && _feedPosts.isEmpty) {
      return _buildFeedError(message: _errorForYou!, onRetry: () => _loadForYou(reset: true));
    }
    if (_loadingForYou && _feedPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return FeedVerticalReels(
          key: ValueKey<Object>('fy_$_forYouFeedEpoch'),
          posts: _feedPosts,
          pageController: _getPageController(0),
          active: _tabController.index == 0,
          onPageChangedIndex: (_) {},
          onNearEndIndex: _queueLoadMoreForYouIfNeeded,
          resolvePlaybackUrl: _playbackUrlForPost,
          backdropForPost: (ctx, post) => _buildReelBackdrop(post),
          overlay: (ctx, post, index) => _buildReelChrome(post),
        );
      },
    );
  }

  Widget _buildFollowingFeed() {
    if (_errorFollowing != null && _followingPosts.isEmpty) {
      return _buildFeedError(message: _errorFollowing!, onRetry: () => _loadFollowing(reset: true));
    }
    if (_loadingFollowing && _followingPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_followingPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('No posts from followed creators', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Browse For You'),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        return FeedVerticalReels(
          key: ValueKey<Object>('fl_$_followingFeedEpoch'),
          posts: _followingPosts,
          pageController: _getPageController(1),
          active: _tabController.index == 1,
          onPageChangedIndex: (_) {},
          onNearEndIndex: _queueLoadMoreFollowingIfNeeded,
          resolvePlaybackUrl: _playbackUrlForPost,
          backdropForPost: (ctx, post) => _buildReelBackdrop(post),
          overlay: (ctx, post, index) => _buildReelChrome(post),
        );
      },
    );
  }

  Widget _buildFeedError({required String message, required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 72, color: AppColors.primaryGray.withOpacity(0.55)),
            const SizedBox(height: 12),
            Text(
              'Could not load feed',
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray.withOpacity(0.9)),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _SearchScreen(allPosts: _feedPosts, onPostTap: (post) => _showPostDetail(post), buildExploreGridItem: (post) => _buildExploreGridItem(post)),
      ),
    );
  }

  Widget _buildExploreGridItem(Map<String, dynamic> post) {
    final isTrainer = post['isTrainer'] ?? false;
    final isCertified = isTrainer; // Show verified/certified icon if trainer

    return GestureDetector(
      onTap: () => _openVideoReel(post),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail image
          ClipRRect(borderRadius: BorderRadius.circular(12), child: _buildEnhancedThumbnail(_resolveAttractiveThumbnail(post))),

          // Gradient overlay for better visibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.2)]),
            ),
          ),

          // White circular play button in center
          Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, spreadRadius: 1)],
              ),
              child: Icon(Icons.play_arrow, color: AppColors.accent, size: 24),
            ),
          ),

          // Verified/Certified icon in top-right corner (only shown if trainer/certified)
          if (isCertified)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: const Color.fromARGB(153, 71, 71, 71), shape: BoxShape.circle),
                child: Icon(
                  Icons.verified,
                  color: AppColors.completed, // Blue/Green color for verified
                  size: 18,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReelBackdrop(Map<String, dynamic> post) {
    return SizedBox.expand(child: _buildEnhancedThumbnail(_resolveAttractiveThumbnail(post), isFullScreen: true));
  }

  /// Like / comment / caption; gradient ignored for hit-testing so center taps toggle play on the video layer.
  Widget _buildReelChrome(Map<String, dynamic> post) {
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: true,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.35), Colors.black.withOpacity(0.65)],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: 18,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentVariant,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/play.png', width: 15),
                SizedBox(width: 4),
                Text(
                  post['duration'] ?? '30s',
                  style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 30,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {},
                child: Image.asset('assets/images/verify.png', width: 35.w),
              ),
              const SizedBox(height: 20),
              _buildLikeButton(post),
              const SizedBox(height: 20),
              _buildCommentButton(post),
              const SizedBox(height: 20),
              _buildSaveButton(post),
              const SizedBox(height: 20),
              _buildVerticalInteractionSvgButton(assetPath: 'assets/icons/share.svg', count: post['shares'] ?? 0, onTap: () => _showShareOptions(post)),
            ],
          ),
        ),
        Positioned(
          left: 16,
          bottom: 30,
          right: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _navigateToCreatorProfile(post),
                child: Text(
                  '@${(post['creator'] ?? 'user').toString().toLowerCase().replaceAll(' ', '')}',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                post['description'] ?? '',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontSize: 14,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children:
                    (post['tags'] as List<String>?)
                        ?.map(
                          (tag) => Text(
                            tag,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                            ),
                          ),
                        )
                        .toList() ??
                    [],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildVerticalInteractionButton({required IconData icon, required int count, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 6),
          Text(
            _formatCount(count),
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 4, offset: const Offset(0, 1))],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalInteractionSvgButton({required String assetPath, required int count, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(assetPath, width: 28, height: 28, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          const SizedBox(height: 6),
          Text(
            _formatCount(count),
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 4, offset: const Offset(0, 1))],
            ),
          ),
        ],
      ),
    );
  }

  // Like button using SVG and red color when liked
  Widget _buildLikeButton(Map<String, dynamic> post) {
    final bool isLiked = post['isLiked'] ?? false;
    final int count = post['likes'] ?? 0;
    return GestureDetector(
      onTap: () {
        setState(() {
          post['isLiked'] = !isLiked;
          post['likes'] = (post['likes'] ?? 0) + (post['isLiked'] ? 1 : -1);
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/heart.svg', width: 28, height: 28, colorFilter: ColorFilter.mode(isLiked ? Colors.red : Colors.white, BlendMode.srcIn)),
          const SizedBox(height: 6),
          Text(
            _formatCount(count),
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 4, offset: const Offset(0, 1))],
            ),
          ),
        ],
      ),
    );
  }

  // Comment button - opens bottom sheet
  Widget _buildCommentButton(Map<String, dynamic> post) {
    final int count = post['comments'] ?? 0;
    return GestureDetector(
      onTap: () => _openCommentsSheet(post),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/messagee.svg', width: 28, height: 28, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          const SizedBox(height: 6),
          Text(
            _formatCount(count),
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 4, offset: const Offset(0, 1))],
            ),
          ),
        ],
      ),
    );
  }

  // Save button - fills white background when saved
  Widget _buildSaveButton(Map<String, dynamic> post) {
    final bool isSaved = post['isSaved'] ?? false;
    final int count = post['saves'] ?? 0;
    return GestureDetector(
      onTap: () async {
        final wasSaved = isSaved;
        setState(() {
          post['isSaved'] = !wasSaved;
          post['saves'] = (post['saves'] ?? 0) + (!wasSaved ? 1 : -1);
        });
        if (!wasSaved) {
          await _storageService.addSavedPost(post);
        } else {
          await _storageService.removeSavedPost(post['id']);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isSaved ? Colors.white : Colors.transparent,
              shape: BoxShape.circle,
              border: isSaved ? Border.all(color: Colors.white, width: 0) : null,
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset('assets/icons/save.svg', width: 24, height: 24, colorFilter: ColorFilter.mode(isSaved ? AppColors.accent : Colors.white, BlendMode.srcIn)),
          ),
          const SizedBox(height: 6),
          Text(
            _formatCount(count),
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 4, offset: const Offset(0, 1))],
            ),
          ),
        ],
      ),
    );
  }

  String _resolveAttractiveThumbnail(Map<String, dynamic> post) {
    final String category = (post['category'] ?? '').toString().toLowerCase();
    // High-quality Unsplash images mapped by category
    switch (category) {
      case 'workout':
      case 'strength':
      case 'calisthenics':
        return 'https://images.unsplash.com/photo-1517649763962-0c623066013b?w=1200&auto=format&fit=crop&q=80';
      case 'nutrition':
        return 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1200&auto=format&fit=crop&q=80';
      case 'running':
        return 'https://images.unsplash.com/photo-1546484959-f01bc3e3bdc1?w=1200&auto=format&fit=crop&q=80';
      case 'sports':
      case 'basketball':
        return 'https://images.unsplash.com/photo-1517647285522-5f0f4f36b52e?w=1200&auto=format&fit=crop&q=80';
      case 'mobility':
      case 'yoga':
      case 'pilates':
        return 'https://images.unsplash.com/photo-1552196563-55cd4e45efb3?w=1200&auto=format&fit=crop&q=80';
      case 'cardio':
      case 'hiit':
        return 'https://images.unsplash.com/photo-1518611012118-696072aa579a?w=1200&auto=format&fit=crop&q=80';
      case 'swimming':
        return 'https://images.unsplash.com/photo-1508609349937-5ec4ae374ebf?w=1200&auto=format&fit=crop&q=80';
      case 'boxing':
        return 'https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?w=1200&auto=format&fit=crop&q=80';
      case 'cycling':
        return 'https://images.unsplash.com/photo-1518655048521-f130df041f66?w=1200&auto=format&fit=crop&q=80';
      case 'rock climbing':
        return 'https://images.unsplash.com/photo-1502217625004-8e3f18f3fd57?w=1200&auto=format&fit=crop&q=80';
      case 'hiking':
        return 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?w=1200&auto=format&fit=crop&q=80';
      case 'functional training':
        return 'https://images.unsplash.com/photo-1517832606299-7ae9b720a34e?w=1200&auto=format&fit=crop&q=80';
      case 'stretching':
        return 'https://images.unsplash.com/photo-1599050751794-2a1b94e3f3a7?w=1200&auto=format&fit=crop&q=80';
      case 'mental health':
        return 'https://images.unsplash.com/photo-1511295742362-92c96b1a3d52?w=1200&auto=format&fit=crop&q=80';
      default:
        // Fallback to provided URL if category is unknown
        final raw = (post['thumbnail'] ?? '').toString();
        return ImageUrlSanitizer.asHttpUrlOrFallback(raw, fallback: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200&auto=format&fit=crop&q=80');
    }
  }

  Widget _buildEnhancedThumbnail(dynamic rawUrl, {bool isFullScreen = false}) {
    final imageUrl = ImageUrlSanitizer.asHttpUrlOrFallback(
      (rawUrl ?? '').toString(),
      fallback: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200&auto=format&fit=crop&q=80',
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 280), curve: Curves.easeOut, child: child);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2B2E3A), Color(0xFF444B66)]),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9333EA), Color(0xFFFBBF24)]),
            ),
          ),
        ),

        // Soft top highlight gives thumbnails a richer "card" feel.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(isFullScreen ? 0.04 : 0.08), Colors.transparent, Colors.black.withOpacity(isFullScreen ? 0.18 : 0.10)],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openCommentsSheet(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.4), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Comments',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(_formatCount(post['comments'] ?? 0), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.separated(
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.accent.withOpacity(0.2),
                      child: Text('U', style: AppTextStyles.labelMedium),
                    ),
                    title: Text('Great tip! Thanks.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.onSurface)),
                    subtitle: Text('2h ago', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                  ),
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemCount: 6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppColors.primaryGray.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: AppColors.accent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 0, width: 8),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.send, color: AppColors.accent),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToCreatorProfile(Map<String, dynamic> post) {
    final String creatorName = (post['creator'] ?? 'Creator').toString();
    final String initials = (post['creatorImage'] ?? 'UT').toString();
    final bool isTrainer = post['isTrainer'] == true;
    final String category = (post['category'] ?? 'Fitness').toString();

    final trainerData = <String, dynamic>{
      'id': creatorName.toLowerCase().replaceAll(' ', '_'),
      'name': creatorName,
      'initials': initials,
      'bio': isTrainer
          ? 'Certified trainer sharing ${category.toLowerCase()} tips and routines to help you reach your goals.'
          : 'Fitness enthusiast sharing ${category.toLowerCase()} content with the community.',
      'specialties': <String>[category, 'Training', if (isTrainer) 'Coaching'],
      'yearsOfExperience': isTrainer ? 6 : 2,
      'certified': isTrainer,
      'certifications': isTrainer ? ['Certified Personal Trainer'] : null,
      'hourlyRate': 75.0,
      'rating': 4.8,
      'totalReviews': 127,
      'students': 1250,
      'activePrograms': 5,
      'completedPrograms': 12,
      'totalPrograms': 17,
    };

    Get.toNamed(AppRoutes.trainerProfile, arguments: trainerData);
  }

  // ignore: unused_element
  Widget _buildInteractionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelMedium.copyWith(color: color)),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  // removed legacy create options

  // ignore: unused_element
  Widget _buildCreateOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.accent),
      ),
      title: Text(title, style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface)),
      subtitle: Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.primaryGray),
      onTap: onTap,
    );
  }

  void _showPostDetail(Map<String, dynamic> post) {
    Get.snackbar('Post Detail', 'Opening ${post['title']}', backgroundColor: AppColors.accent, colorText: AppColors.onAccent, snackPosition: SnackPosition.BOTTOM);
  }

  /// Normalize feed video URLs (absolute http(s) or join with API base path).
  String? _resolveFeedMediaUrl(String? raw) {
    final input = raw?.trim();
    if (input == null || input.isEmpty) return null;
    final absolute = ImageUrlSanitizer.asHttpUrlOrNull(input);
    if (absolute != null) return absolute;
    if (input.startsWith('/')) {
      final base = Uri.parse(AppUrl.baseUrl);
      return '${base.scheme}://${base.authority}$input';
    }
    return null;
  }

  String? _playbackUrlForPost(Map<String, dynamic> post) {
    final raw =
        _firstNonEmptyUrlString(post['videoUrl']) ??
        _firstNonEmptyUrlString(post['playbackUrl']) ??
        _firstNonEmptyUrlString(post['hlsUrl']) ??
        _firstNonEmptyUrlString(post['streamUrl']);
    return _resolveFeedMediaUrl(raw);
  }

  void _openVideoReel(Map<String, dynamic> post) {
    final resolved = _playbackUrlForPost(post);
    if (resolved == null) {
      Get.snackbar('Video', 'Video URL is unavailable for this post.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final copy = Map<String, dynamic>.from(post);
    copy['videoUrl'] = resolved;
    Get.toNamed(AppRoutes.videoReel, arguments: {'posts': <Map<String, dynamic>>[copy], 'initialIndex': 0});
  }

  void _showShareOptions(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share Post', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [_buildShareIcon(Icons.message, 'Message', () {}), _buildShareIcon(Icons.link, 'Copy Link', () {}), _buildShareIcon(Icons.share, 'More', () {})],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildShareIcon(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.accent, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }

  // ignore: unused_element
  void _handlePostAction(String action, Map<String, dynamic> post) async {
    switch (action) {
      case 'save':
        final isSaved = post['isSaved'] ?? false;
        setState(() {
          post['isSaved'] = !isSaved;
        });
        if (!isSaved) {
          await _storageService.addSavedPost(post);
        } else {
          await _storageService.removeSavedPost(post['id']);
        }
        Get.snackbar(
          !isSaved ? 'Saved' : 'Unsaved',
          !isSaved ? 'Post saved to your collection' : 'Post removed from collection',
          backgroundColor: AppColors.accent,
          colorText: AppColors.onAccent,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        break;
      case 'follow':
        setState(() {
          post['isFollowing'] = true;
        });
        Get.snackbar(
          'Following',
          'You are now following ${post['creator']}',
          backgroundColor: AppColors.completed,
          colorText: AppColors.onError,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        break;
      case 'report':
        _showReportDialog(post);
        break;
      case 'share':
        _showShareOptions(post);
        break;
    }
  }

  void _showReportDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Report Post', style: AppTextStyles.titleLarge.copyWith()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildReportOption('Inappropriate content'), _buildReportOption('Misleading advice'), _buildReportOption('Spam'), _buildReportOption('Harassment')],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.primaryGray)),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(String reason) {
    return ListTile(
      title: Text(reason, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
      onTap: () {
        Navigator.pop(context);
        Get.snackbar(
          'Report Submitted',
          'Thank you for keeping our community safe',
          backgroundColor: AppColors.completed,
          colorText: AppColors.onError,
          snackPosition: SnackPosition.BOTTOM,
        );
      },
    );
  }
}

/// Search Screen - Shows search bar with explore content
class _SearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allPosts;
  final ValueChanged<Map<String, dynamic>> onPostTap;
  final Widget Function(Map<String, dynamic>) buildExploreGridItem;

  const _SearchScreen({required this.allPosts, required this.onPostTap, required this.buildExploreGridItem});

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<Map<String, dynamic>> get _filteredPosts {
    if (_searchQuery.isEmpty) {
      return widget.allPosts;
    }
    final query = _searchQuery.toLowerCase();
    return widget.allPosts.where((post) {
      final title = (post['title'] ?? '').toString().toLowerCase();
      final description = (post['description'] ?? '').toString().toLowerCase();
      final category = (post['category'] ?? '').toString().toLowerCase();
      final creator = (post['creator'] ?? '').toString().toLowerCase();
      final tags = (post['tags'] as List<String>?)?.map((t) => t.toLowerCase()).join(' ') ?? '';

      return title.contains(query) || description.contains(query) || category.contains(query) || creator.contains(query) || tags.contains(query);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Search', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF000000)),
                decoration: InputDecoration(
                  hintText: 'Search videos, creators, categories...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF404040)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF404040)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF404040)),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // Show message if no results found
          if (_searchQuery.isNotEmpty && _filteredPosts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    Text('No videos found', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                    const SizedBox(height: 8),
                    Text('Try different keywords', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                  ],
                ),
              ),
            )
          else
            // Main grid of all posts
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  childAspectRatio: 1.0, // Square grid items
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  return GestureDetector(onTap: () => widget.onPostTap(_filteredPosts[index]), child: widget.buildExploreGridItem(_filteredPosts[index]));
                }, childCount: _filteredPosts.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
