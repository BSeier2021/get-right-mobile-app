import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/controllers/notification_controller.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/routes/app_route_observer.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/trainer_certification_helper.dart';
import 'package:get_right/utils/feed_media_url.dart';
import 'package:get_right/utils/feed_post_mapper.dart';
import 'package:get_right/views/feed/feed_reel_overlay.dart';
import 'package:get_right/views/feed/feed_vertical_reels.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:video_player/video_player.dart';

/// Community Feed - Social Media Platform for fitness content
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin, RouteAware {
  late TabController _tabController;
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

  /// Edge overscroll on first/last reel so [RefreshIndicator] works (especially Android).
  static const ScrollPhysics _feedPagePhysics = PageScrollPhysics(parent: BouncingScrollPhysics());

  /// Home bottom nav uses IndexedStack — [initState] runs at app start. Defer API calls until Feed tab is selected (index 1).
  Worker? _homeTabWorker;
  bool _feedTabLazyBootstrapped = false;

  /// False when another route is pushed above the host route (e.g. profile, search from feed).
  bool _feedHostRouteVisible = true;

  ModalRoute<dynamic>? _routeSubscription;

  bool _isHomeFeedTabSelected() {
    if (!Get.isRegistered<HomeNavigationController>()) return true;
    return Get.find<HomeNavigationController>().currentIndex == 1;
  }

  void _openHomeDrawer() {
    if (Get.isRegistered<HomeNavigationController>()) {
      Get.find<HomeNavigationController>().openDrawer();
      return;
    }
    final scaffold = Scaffold.maybeOf(context);
    scaffold?.openDrawer();
  }

  /// Reels autoplay only when Feed tab + inner tab selected and this route is not covered.
  bool _reelsActiveForInnerTab(int innerTabIndex) {
    return _feedHostRouteVisible && _isHomeFeedTabSelected() && _tabController.index == innerTabIndex;
  }

  void _disposePageControllerForTab(int tabIndex) {
    final c = _pageControllers.remove(tabIndex);
    c?.dispose();
  }

  /// Keeps like state in sync when the same post appears in For You and Following.
  void _syncPostLikeState(String postId, bool isLiked, int likes) {
    for (final post in [..._feedPosts, ..._followingPosts]) {
      if ((post['id'] ?? '').toString() == postId) {
        post['isLiked'] = isLiked;
        post['likes'] = likes;
      }
    }
  }

  /// Keeps save state in sync when the same post appears in For You and Following.
  void _syncPostSaveState(String postId, bool isSaved, int saves) {
    for (final post in [..._feedPosts, ..._followingPosts]) {
      if ((post['id'] ?? '').toString() == postId) {
        post['isSaved'] = isSaved;
        post['saves'] = saves;
      }
    }
  }

  /// Keeps comment count in sync when the same post appears in For You and Following.
  void _syncPostCommentCount(String postId, int commentCount) {
    for (final post in [..._feedPosts, ..._followingPosts]) {
      if ((post['id'] ?? '').toString() == postId) {
        post['comments'] = commentCount;
      }
    }
  }

  void _removePostFromFeedLists(String postId) {
    if (postId.isEmpty) return;
    setState(() {
      _feedPosts.removeWhere((p) => (p['id'] ?? '').toString() == postId);
      _followingPosts.removeWhere((p) => (p['id'] ?? '').toString() == postId);
      _forYouFeedEpoch++;
      _followingFeedEpoch++;
    });
  }

  Widget _feedReelOverlay(BuildContext ctx, Map<String, dynamic> post, int index, VideoPlayerController? controller) {
    return FeedReelChromeOverlay(
      post: post,
      videoController: controller,
      onLikeStateChanged: _syncPostLikeState,
      onSaveStateChanged: _syncPostSaveState,
      onCommentCountChanged: _syncPostCommentCount,
      onPostDeleted: _removePostFromFeedLists,
    );
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
      if (!mounted) return;
      if (Get.isRegistered<HomeNavigationController>()) {
        final nav = Get.find<HomeNavigationController>();
        _homeTabWorker = ever<int>(nav.currentIndexRx, (idx) {
          if (!mounted) return;
          if (idx != 1) {
            _clearFeedReelCaches(clearFullImageCache: false);
          }
          setState(() {});
          if (idx == 1) _bootstrapFeedWhenTabSelected();
        });
        if (nav.currentIndex == 1) {
          _bootstrapFeedWhenTabSelected();
        }
      } else {
        _bootstrapFeedWhenTabSelected();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null && route != _routeSubscription) {
      if (_routeSubscription != null) {
        appRouteObserver.unsubscribe(this);
      }
      _routeSubscription = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    if (mounted) setState(() => _feedHostRouteVisible = false);
  }

  @override
  void didPopNext() {
    if (mounted) setState(() => _feedHostRouteVisible = true);
  }

  /// First time user opens the Feed bottom tab: load only "For You". "Following" loads when that inner tab is selected.
  void _bootstrapFeedWhenTabSelected() {
    if (_feedTabLazyBootstrapped) return;
    _feedTabLazyBootstrapped = true;
    if (!mounted) return;
    if (_tabController.index == 0 && _feedPosts.isEmpty && !_loadingForYou) {
      _loadForYou(reset: true);
    } else if (_tabController.index == 1 && _followingPosts.isEmpty && !_loadingFollowing) {
      _loadFollowing(reset: true);
    }
  }

  @override
  void dispose() {
    _clearFeedReelCaches(clearFullImageCache: true);
    appRouteObserver.unsubscribe(this);
    _homeTabWorker?.dispose();
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

  Set<String> _savedFeedPostIds() {
    if (!Get.isRegistered<StorageService>()) return <String>{};
    return Get.find<StorageService>().getSavedFeedPostIds();
  }

  Set<String> _likedFeedPostIds() {
    if (!Get.isRegistered<StorageService>()) return <String>{};
    return Get.find<StorageService>().getLikedFeedPostIds();
  }

  List<Map<String, dynamic>> _mapFeedDocuments(List<dynamic> feedsRaw) {
    final mapped = feedsRaw.map((e) => mapApiFeedDocumentToUiPost(e)).where((p) => (p['id'] ?? '').toString().isNotEmpty).toList();
    mergePersistedSaveStateOnFeedPosts(mapped, _savedFeedPostIds());
    mergePersistedLikeStateOnFeedPosts(mapped, _likedFeedPostIds());
    return mapped;
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

  /// Drops decoded bitmaps for reel thumbnails. [clearFullImageCache] runs [ImageCache.clear] plus [clearLiveImages]; when false only [ImageCache.clearLiveImages] runs (e.g. leaving this tab while [IndexedStack] keeps the widget alive).
  void _clearFeedReelCaches({required bool clearFullImageCache}) {
    final cache = PaintingBinding.instance.imageCache;
    cache.clearLiveImages();
    if (clearFullImageCache) {
      cache.clear();
    }
  }

  Future<void> _loadForYou({required bool reset}) async {
    if (_loadingForYou) return;
    if (!reset && !_hasNextForYou) return;

    if (reset) {
      _clearFeedReelCaches(clearFullImageCache: true);
    }

    if (!mounted) return;
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
      if (!mounted) return;
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data']) : <String, dynamic>{};
      final feedsRaw = (data['feeds'] is List) ? List.from(data['feeds']) : const [];
      final mapped = _mapFeedDocuments(feedsRaw);

      if (!mounted) return;
      setState(() {
        _feedPosts.addAll(mapped);
        _hasNextForYou = _readHasNextPage(data);
        _pageForYou = _pageForYou + 1;
      });
    } catch (e) {
      if (!mounted) return;
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

    if (reset) {
      _clearFeedReelCaches(clearFullImageCache: true);
    }

    if (!mounted) return;
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
      if (!mounted) return;
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data']) : <String, dynamic>{};
      final feedsRaw = (data['feeds'] is List) ? List.from(data['feeds']) : const [];
      final mapped = _mapFeedDocuments(feedsRaw);

      if (!mounted) return;
      setState(() {
        _followingPosts.addAll(mapped);
        _hasNextFollowing = _readHasNextPage(data);
        _pageFollowing = _pageFollowing + 1;
      });
    } catch (e) {
      debugPrint('[FeedScreen] Error loading following: $e');
      if (!mounted) return;
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

  /// Reloads the visible tab (`GET /user/feed`) — not `/user/feed/mine` (that is “my posts” on profile).
  Future<void> _refreshActiveFeedTab() async {
    if (_tabController.index == 0) {
      await _loadForYou(reset: true);
    } else {
      await _loadFollowing(reset: true);
    }
  }

  /// Lets pull-to-refresh listen to vertical reel [PageView] even when [ScrollNotification.depth] &gt; 0 (nested scrollables).
  bool _feedVerticalRefreshNotificationPredicate(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    return defaultScrollNotificationPredicate(notification) || notification.depth <= 2;
  }

  Widget _wrapFeedRefreshIndicator({required Future<void> Function() onRefresh, required Widget child}) {
    return RefreshIndicator.adaptive(
      color: AppColors.accentVariant,
      backgroundColor: Colors.black,
      displacement: 48,
      strokeWidth: 3,
      triggerMode: RefreshIndicatorTriggerMode.anywhere,
      notificationPredicate: _feedVerticalRefreshNotificationPredicate,
      onRefresh: onRefresh,
      child: child,
    );
  }

  /// [RefreshIndicator] needs a scrollable that can overscroll when content is short (errors, empty, loading).
  Widget _refreshScrollableBody({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
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
            if (!Get.isRegistered<NotificationController>()) {
              return IconButton(
                icon: Image.asset('assets/images/humburger.png', width: 25.w),
                onPressed: _openHomeDrawer,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ).paddingOnly(left: 10);
            }
            final notificationController = Get.find<NotificationController>();
            final unreadCount = notificationController.unreadCount;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Image.asset('assets/images/humburger.png', width: 25.w),
                  onPressed: _openHomeDrawer,
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
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                final onForYou = _tabController.index == 0;
                final busy = onForYou ? _loadingForYou : _loadingFollowing;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Refresh feed',
                      icon: busy
                          ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentVariant))
                          : Icon(Icons.refresh_rounded, color: AppColors.onSurface, size: 22),
                      onPressed: busy ? null : () => _refreshActiveFeedTab(),
                    ),
                    IconButton(
                      icon: Image.asset('assets/images/search-normal000.png', width: 20.w),
                      onPressed: () {
                        _showSearchScreen();
                      },
                    ).paddingOnly(right: 5),
                  ],
                );
              },
            ),
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
      return _wrapFeedRefreshIndicator(
        onRefresh: _refreshActiveFeedTab,
        child: _refreshScrollableBody(
          child: _buildFeedError(message: _errorForYou!, onRetry: () => _loadForYou(reset: true)),
        ),
      );
    }
    if (_loadingForYou && _feedPosts.isEmpty) {
      return _wrapFeedRefreshIndicator(
        onRefresh: _refreshActiveFeedTab,
        child: _refreshScrollableBody(child: const Center(child: CircularProgressIndicator())),
      );
    }
    return _wrapFeedRefreshIndicator(
      onRefresh: _refreshActiveFeedTab,
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          return FeedVerticalReels(
            key: ValueKey<Object>('fy_$_forYouFeedEpoch'),
            posts: _feedPosts,
            pageController: _getPageController(0),
            active: _reelsActiveForInnerTab(0),
            onPageChangedIndex: (_) {},
            onNearEndIndex: _queueLoadMoreForYouIfNeeded,
            resolvePlaybackUrl: playbackUrlForFeedPost,
            backdropForPost: (ctx, post) => FeedReelBackdrop(post: post),
            overlay: _feedReelOverlay,
            scrollPhysics: _feedPagePhysics,
          );
        },
      ),
    );
  }

  Widget _buildFollowingFeed() {
    if (_errorFollowing != null && _followingPosts.isEmpty) {
      return _wrapFeedRefreshIndicator(
        onRefresh: _refreshActiveFeedTab,
        child: _refreshScrollableBody(
          child: _buildFeedError(message: _errorFollowing!, onRetry: () => _loadFollowing(reset: true)),
        ),
      );
    }
    if (_loadingFollowing && _followingPosts.isEmpty) {
      return _wrapFeedRefreshIndicator(
        onRefresh: _refreshActiveFeedTab,
        child: _refreshScrollableBody(child: const Center(child: CircularProgressIndicator())),
      );
    }

    if (_followingPosts.isEmpty) {
      return _wrapFeedRefreshIndicator(
        onRefresh: _refreshActiveFeedTab,
        child: _refreshScrollableBody(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: AppColors.primaryGray.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text('No posts from followed creators', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                const SizedBox(height: 8),
                TextButton(onPressed: () => _tabController.animateTo(0), child: const Text('Browse For You')),
              ],
            ),
          ),
        ),
      );
    }

    return _wrapFeedRefreshIndicator(
      onRefresh: _refreshActiveFeedTab,
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          return FeedVerticalReels(
            key: ValueKey<Object>('fl_$_followingFeedEpoch'),
            posts: _followingPosts,
            pageController: _getPageController(1),
            active: _reelsActiveForInnerTab(1),
            onPageChangedIndex: (_) {},
            onNearEndIndex: _queueLoadMoreFollowingIfNeeded,
            resolvePlaybackUrl: playbackUrlForFeedPost,
            backdropForPost: (ctx, post) => FeedReelBackdrop(post: post),
            overlay: _feedReelOverlay,
            scrollPhysics: _feedPagePhysics,
          );
        },
      ),
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
        builder: (context) => _SearchScreen(allPosts: _feedPosts, mapFeedDocuments: _mapFeedDocuments, onPostTap: _openFeedReel, buildExploreGridItem: _buildExploreGridItem),
      ),
    );
  }

  Widget _buildExploreGridItem(Map<String, dynamic> post) {
    final showVerified = showFeedCreatorVerifiedBadge(post);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Thumbnail image
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: FeedReelStyledThumbnail(post: post),
        ),

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
    );
  }

  void _openFeedReel(Map<String, dynamic> post) {
    final id = (post['id'] ?? post['_id'] ?? '').toString().trim();
    if (id.isEmpty) {
      Get.snackbar('Feed', 'This post could not be opened.', snackPosition: SnackPosition.BOTTOM);
      return;
    }
    Get.toNamed(AppRoutes.feedSingleReel, arguments: <String, dynamic>{'feedId': id});
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
}

/// Search Screen - `GET /user/feed?search=` with explore grid fallback when query is empty.
class _SearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allPosts;
  final List<Map<String, dynamic>> Function(List<dynamic> feedsRaw) mapFeedDocuments;
  final ValueChanged<Map<String, dynamic>> onPostTap;
  final Widget Function(Map<String, dynamic>) buildExploreGridItem;

  const _SearchScreen({required this.allPosts, required this.mapFeedDocuments, required this.onPostTap, required this.buildExploreGridItem});

  @override
  State<_SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<_SearchScreen> {
  static const int _searchPerPage = 10;

  final FeedRepository _feedRepo = FeedRepository();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchResults = <Map<String, dynamic>>[];
  bool _loading = false;
  String? _error;

  List<Map<String, dynamic>> get _displayPosts {
    if (_searchQuery.trim().isEmpty) return widget.allPosts;
    return _searchResults;
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();

    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = <Map<String, dynamic>>[];
        _loading = false;
        _error = null;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 400), () => _loadSearch(query));
  }

  Future<void> _loadSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final raw = await _feedRepo.getFeedsRepo(page: 1, limit: _searchPerPage, search: query);
      if (!mounted || _searchController.text.trim() != query) return;

      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data'] as Map) : <String, dynamic>{};
      final feedsRaw = (data['feeds'] is List) ? List.from(data['feeds'] as List) : const <dynamic>[];

      setState(() {
        _searchResults = widget.mapFeedDocuments(feedsRaw);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || _searchController.text.trim() != query) return;
      setState(() {
        _searchResults = <Map<String, dynamic>>[];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
                onChanged: _onSearchChanged,
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
                            _onSearchChanged('');
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

          if (_searchQuery.trim().isNotEmpty && _loading)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else if (_searchQuery.trim().isNotEmpty && _error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Could not search', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryGray)),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(onPressed: () => _loadSearch(_searchQuery.trim()), child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            )
          else if (_searchQuery.trim().isNotEmpty && _displayPosts.isEmpty)
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
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1.0),
                delegate: SliverChildBuilderDelegate((context, index) {
                  return GestureDetector(onTap: () => widget.onPostTap(_displayPosts[index]), child: widget.buildExploreGridItem(_displayPosts[index]));
                }, childCount: _displayPosts.length),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
