import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/feed_media_url.dart';
import 'package:get_right/utils/feed_post_mapper.dart';
import 'package:get_right/views/feed/feed_reel_overlay.dart';
import 'package:get_right/views/feed/feed_vertical_reels.dart';

/// Full-screen vertical reel for a single feed item (`GET /user/feed/:id`).
///
/// Navigate with `Get.toNamed(AppRoutes.feedSingleReel, arguments: {'feedId': id});`
class SingleFeedReelScreen extends StatefulWidget {
  const SingleFeedReelScreen({super.key});

  @override
  State<SingleFeedReelScreen> createState() => _SingleFeedReelScreenState();
}

class _SingleFeedReelScreenState extends State<SingleFeedReelScreen> {
  final FeedRepository _feedRepo = FeedRepository();
  final PageController _pageController = PageController();

  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? _readFeedIdFromArguments() {
    final raw = Get.arguments;
    if (raw is Map) {
      final id = raw['feedId'] ?? raw['id'];
      final s = id?.toString().trim();
      return (s != null && s.isNotEmpty) ? s : null;
    }
    return null;
  }

  Future<void> _load() async {
    final feedId = _readFeedIdFromArguments();
    if (feedId == null) {
      setState(() {
        _loading = false;
        _error = 'Missing feed id';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final raw = await _feedRepo.getFeedByIdRepo(feedId);
      final data = (raw is Map && raw['data'] is Map) ? Map<String, dynamic>.from(raw['data'] as Map) : <String, dynamic>{};
      final feedRaw = data['feed'];
      if (feedRaw == null || feedRaw is! Map) {
        throw StateError('Invalid response: missing data.feed');
      }
      final likedByMe = data['likedByMe'] == true;
      final savedByMe = data['savedByMe'] == true;
      final post = mapApiFeedDocumentToUiPost(Map<String, dynamic>.from(feedRaw), likedByMe: likedByMe, savedByMe: savedByMe);
      final idStr = (post['id'] ?? '').toString();
      if (idStr.isEmpty) {
        throw StateError('Feed has no id');
      }

      if (!mounted) return;
      setState(() {
        _posts = [post];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
        _posts = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => Get.back(),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Could not load reel', style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                    const SizedBox(height: 16),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                FeedVerticalReels(
                  posts: _posts,
                  pageController: _pageController,
                  active: true,
                  onPageChangedIndex: (_) {},
                  onNearEndIndex: (_) {},
                  resolvePlaybackUrl: playbackUrlForFeedPost,
                  backdropForPost: (ctx, post) => FeedReelBackdrop(post: post),
                  overlay: (ctx, post, index) => FeedReelChromeOverlay(post: post),
                ),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                      padding: const EdgeInsets.only(left: 12, top: 4),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
