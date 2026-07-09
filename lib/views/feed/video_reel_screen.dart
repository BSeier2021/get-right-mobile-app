import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get_right/models/hls_video_quality.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/services/share_to_chat_service.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/trainer_certification_helper.dart';
import 'package:get_right/utils/hls_master_playlist_parser.dart';
import 'package:get_right/views/feed/feed_comments_sheet.dart';
import 'package:video_player/video_player.dart';

/// Video Reel Screen - Full-screen video player similar to Instagram Reels
class VideoReelScreen extends StatefulWidget {
  const VideoReelScreen({super.key});

  @override
  State<VideoReelScreen> createState() => _VideoReelScreenState();
}

class _VideoReelScreenState extends State<VideoReelScreen> {
  late PageController _pageController;
  late Map<int, VideoPlayerController> _videoControllers;
  late Map<int, bool> _isPlaying;
  late List<Map<String, dynamic>> _posts;
  final Set<int> _pendingVideoInit = {};
  final Map<int, String?> _videoLoadErrors = {};
  int _currentIndex = 0;
  final _storageService = Get.find<StorageService>();

  /// HLS master playlists often fail on some Android [video_player] builds; pick a concrete variant when possible.
  Future<Uri> _resolveReelPlaybackUri(String rawUrl) async {
    final trimmed = rawUrl.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme) {
      throw FormatException('Invalid video URL');
    }
    final path = parsed.path.toLowerCase();
    if (!path.endsWith('.m3u8')) {
      return parsed;
    }
    try {
      final variants = await HlsMasterPlaylistParser.fetchVariantQualities(parsed);
      if (variants.isEmpty) {
        return parsed;
      }
      variants.sort((a, b) => (a.heightPx ?? 0).compareTo(b.heightPx ?? 0));
      HlsVideoQuality? choice;
      for (final q in variants) {
        final h = q.heightPx ?? 0;
        if (h >= 480 && h <= 720) {
          choice = q;
          break;
        }
      }
      choice ??= variants.length >= 2 ? variants[variants.length ~/ 2] : variants.first;
      return choice.playbackUri;
    } catch (e) {
      debugPrint('Reel: HLS variant resolve failed, using master: $e');
      return parsed;
    }
  }

  @override
  void initState() {
    super.initState();

    // Get arguments from GetX navigation
    final arguments = Get.arguments as Map<String, dynamic>?;
    final rawPosts = arguments?['posts'];
    if (rawPosts is List) {
      _posts = rawPosts.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else {
      _posts = [];
    }
    _currentIndex = arguments?['initialIndex'] as int? ?? 0;

    _pageController = PageController(initialPage: _currentIndex);
    _videoControllers = {};
    _isPlaying = {};

    // Initialize video controllers for nearby posts
    _initializeVideos();
  }

  void _initializeVideos() {
    // Initialize current and adjacent videos
    for (int i = (_currentIndex - 1).clamp(0, _posts.length - 1); i <= (_currentIndex + 1).clamp(0, _posts.length - 1); i++) {
      if (!_videoControllers.containsKey(i)) {
        _initializeVideo(i);
      }
    }
  }

  void _initializeVideo(int index) {
    if (index < 0 || index >= _posts.length) return;
    if (_videoControllers.containsKey(index) || _pendingVideoInit.contains(index)) return;

    final post = _posts[index];
    final videoUrl = post['videoUrl'] as String?;

    if (videoUrl == null || videoUrl.isEmpty) {
      setState(() => _videoLoadErrors[index] = 'No video URL');
      return;
    }

    _pendingVideoInit.add(index);
    () async {
      Uri playbackUri;
      try {
        playbackUri = await _resolveReelPlaybackUri(videoUrl);
      } catch (_) {
        playbackUri = Uri.parse(videoUrl.trim());
      }

      if (!mounted) {
        _pendingVideoInit.remove(index);
        return;
      }

      Future<bool> tryPlay(Uri uri) async {
        VideoPlayerController? controller;
        try {
          controller = VideoPlayerController.networkUrl(uri);
          await controller.initialize().timeout(const Duration(seconds: 45));
        } catch (e) {
          debugPrint('Reel: init failed for $uri → $e');
          if (controller != null) {
            await controller.dispose();
          }
          return false;
        }

        if (!mounted) {
          await controller.dispose();
          return false;
        }

        _videoControllers[index] = controller;
        _isPlaying[index] = false;
        await controller.setLooping(true);
        if (index == _currentIndex) {
          await controller.play();
          _isPlaying[index] = true;
        }
        _videoLoadErrors.remove(index);
        return true;
      }

      var ok = await tryPlay(playbackUri);

      // If variant URL failed, retry once with the original master / URL from API.
      if (!ok && playbackUri.toString() != videoUrl.trim()) {
        ok = await tryPlay(Uri.parse(videoUrl.trim()));
      }

      _pendingVideoInit.remove(index);

      if (!ok && mounted) {
        setState(() => _videoLoadErrors[index] = 'Could not load video');
      } else if (mounted) {
        setState(() {});
      }
    }();
  }

  void _retryVideo(int index) {
    _videoLoadErrors.remove(index);
    final c = _videoControllers.remove(index);
    _isPlaying.remove(index);
    c?.dispose();
    _initializeVideo(index);
  }

  Widget _buildCoverVideo(VideoPlayerController controller) {
    final v = controller.value;
    final w = v.size.width;
    final h = v.size.height;
    if (w > 0 && h > 0) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(width: w, height: h, child: VideoPlayer(controller)),
      );
    }
    final ar = v.aspectRatio;
    if (ar > 0 && !ar.isNaN) {
      return AspectRatio(aspectRatio: ar, child: VideoPlayer(controller));
    }
    return VideoPlayer(controller);
  }

  Widget _backdropForPost(Map<String, dynamic> post) {
    final thumb = (post['thumbnail'] ?? '').toString().trim();
    final avatar = (post['creatorAvatarUrl'] ?? '').toString().trim();
    final url = thumb.isNotEmpty ? thumb : avatar;
    if (url.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9333EA), Color(0xFFFBBF24)],
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF9333EA), Color(0xFFFBBF24)],
          ),
        ),
      ),
    );
  }

  void _onPageChanged(int index) {
    // Pause previous video
    if (_videoControllers.containsKey(_currentIndex)) {
      _videoControllers[_currentIndex]?.pause();
      _isPlaying[_currentIndex] = false;
    }

    _currentIndex = index;

    // Play current video
    if (_videoControllers.containsKey(_currentIndex)) {
      _videoControllers[_currentIndex]?.setLooping(true);
      _videoControllers[_currentIndex]?.play();
      _isPlaying[_currentIndex] = true;
    } else {
      _initializeVideo(_currentIndex);
    }

    // Preload adjacent videos
    _initializeVideos();

    setState(() {});
  }

  void _togglePlayPause() {
    if (!_videoControllers.containsKey(_currentIndex)) {
      _initializeVideo(_currentIndex);
      return;
    }

    final controller = _videoControllers[_currentIndex]!;
    if (controller.value.isPlaying) {
      controller.pause();
      _isPlaying[_currentIndex] = false;
    } else {
      controller.play();
      _isPlaying[_currentIndex] = true;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _videoControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          onPageChanged: _onPageChanged,
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            return _buildVideoReel(_posts[index], index);
          },
        ),
      ),
    );
  }

  Widget _buildVideoReel(Map<String, dynamic> post, int index) {
    final hasVideo = _videoControllers.containsKey(index) && _videoControllers[index]!.value.isInitialized;
    final loadError = _videoLoadErrors[index];

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player or thumbnail
        if (hasVideo)
          GestureDetector(
            onTap: _togglePlayPause,
            child: SizedBox.expand(
              child: ClipRect(
                child: _buildCoverVideo(_videoControllers[index]!),
              ),
            ),
          )
        else if (loadError != null)
          GestureDetector(
            onTap: () => _retryVideo(index),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _backdropForPost(post),
                Container(color: Colors.black.withOpacity(0.45)),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          loadError,
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: () => _retryVideo(index),
                          style: TextButton.styleFrom(foregroundColor: AppColors.accentVariant),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: () {
              if (!_pendingVideoInit.contains(index)) {
                _initializeVideo(index);
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                _backdropForPost(post),
                Center(child: CircularProgressIndicator(color: AppColors.accent)),
              ],
            ),
          ),

        // Gradient overlay for better text visibility
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.6)],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        ),

        // Top bar with back button and more options
        SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 0.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                    child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20.sp),
                  ),
                  onPressed: () => Get.back(),
                ),
                IconButton(
                  icon: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                    child: Icon(Icons.more_vert, color: Colors.white, size: 24.sp),
                  ),
                  onPressed: () => _showPostOptions(post),
                ),
              ],
            ),
          ),
        ),

        // Right side interaction buttons
        Positioned(
          right: 16,
          bottom: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Avatar
              GestureDetector(
                onTap: () => _navigateToCreatorProfile(post),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.white,
                    child: Text(
                      post['creatorImage'] ?? 'U',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

              // Like button (heart turns red on tap)
              _buildLikeButton(post),
              const SizedBox(height: 20),

              // Comment button
              _buildCommentButton(post),
              const SizedBox(height: 20),

              // Save/Bookmark button
              _buildSaveButton(post),
              const SizedBox(height: 20),

              // Share button
              _buildVerticalInteractionSvgButton(assetPath: 'assets/icons/share.svg', count: post['shares'] ?? 0, onTap: () => _showShareOptions(post)),
              const SizedBox(height: 20),

              // Premium star icon
              GestureDetector(
                onTap: () {
                  // TODO: Handle premium/favorite action
                },
                child: Image.asset('assets/images/Frame 1000001604.png', width: 44.w, height: 44.h),
              ),
            ],
          ),
        ),

        // Bottom left text content
        Positioned(
          left: 16.w,
          bottom: 50.h,
          right: 100.w,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Username
              GestureDetector(
                onTap: () => _navigateToCreatorProfile(post),
                child: Row(
                  children: [
                    Text(
                      '@${(post['creator'] ?? 'user').toString().toLowerCase().replaceAll(' ', '')}',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                        shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                    ),
                    if (showFeedCreatorVerifiedBadge(post))
                      Padding(
                        padding: EdgeInsets.only(left: 6.w),
                        child: verifiedBadgeIcon(size: 18.sp),
                      ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),

              // Caption
              Text(
                post['description'] ?? '',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontSize: 14.sp,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                ),
              ),
              SizedBox(height: 8.h),

              // Hashtags
              Wrap(
                spacing: 8.w,
                runSpacing: 4.h,
                children:
                    (post['tags'] as List<String>?)
                        ?.map(
                          (tag) => Text(
                            tag,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
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

        // Play/Pause overlay (shown when video is paused)
        if ((_isPlaying[index] ?? false) == false && hasVideo)
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 80.w,
                height: 80.h,
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                child: Icon(Icons.play_arrow, color: Colors.white, size: 50.sp),
              ),
            ),
          ),
      ],
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

  void _openCommentsSheet(Map<String, dynamic> post) {
    final feedId = (post['id'] ?? post['_id'] ?? post['feedId'] ?? '').toString().trim();
    if (feedId.isEmpty) return;

    final initialCount = (post['comments'] is num) ? (post['comments'] as num).toInt() : 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return FeedCommentsSheet(
          feedId: feedId,
          feedOwnerId: (post['creatorId'] ?? '').toString().trim(),
          initialCommentCount: initialCount,
          onCommentCountChanged: (count) {
            post['comments'] = count;
            if (mounted) setState(() {});
          },
        );
      },
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

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _navigateToCreatorProfile(Map<String, dynamic> post) {
    final String creatorName = (post['creator'] ?? 'Creator').toString();
    final String initials = (post['creatorImage'] ?? 'UT').toString();
    final bool isTrainer = post['isTrainer'] == true;
    final bool certificationsVerified = isCertifiedFromUiMap(post);
    final String category = (post['category'] ?? 'Fitness').toString();

    final creatorId = (post['creatorId'] ?? '').toString().trim();

    final trainerData = <String, dynamic>{
      'returnToFeedOnBlock': true,
      if (creatorId.isNotEmpty) ...{'_id': creatorId, 'id': creatorId},
      'name': creatorName,
      'initials': initials,
      'bio': isTrainer
          ? 'Certified trainer sharing ${category.toLowerCase()} tips and routines to help you reach your goals.'
          : 'Fitness enthusiast sharing ${category.toLowerCase()} content with the community.',
      'specialties': <String>[category, 'Training', if (isTrainer) 'Coaching'],
      'yearsOfExperience': isTrainer ? 6 : 2,
      'isCertificationsVerified': certificationsVerified,
      'certified': certificationsVerified,
      'certifications': certificationsVerified ? ['Certified Personal Trainer'] : null,
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

  void _showShareOptions(Map<String, dynamic> post) {
    final hostContext = context;
    final feedId = (post['id'] ?? post['_id'] ?? post['feedId'] ?? '').toString().trim();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share Post', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildShareIcon(Icons.message, 'Message', () {
                  Navigator.pop(sheetContext);
                  if (!WorkoutRepository.isValidMongoId(feedId)) return;
                  ShareToChatService.share(context: hostContext, type: SharedContentType.feed, contentId: feedId);
                }),
                _buildShareIcon(Icons.link, 'Copy Link', () => Navigator.pop(sheetContext)),
                _buildShareIcon(Icons.share, 'More', () => Navigator.pop(sheetContext)),
              ],
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

  void _showPostOptions(Map<String, dynamic> post) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.primaryGray.withOpacity(0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            _buildOptionItem(Icons.share_outlined, 'Share Post', () {
              Navigator.pop(context);
              _showShareOptions(post);
            }),
            _buildOptionItem(Icons.link, 'Copy Link', () {
              Navigator.pop(context);
              Get.snackbar('Link Copied', 'Post link copied to clipboard', backgroundColor: AppColors.completed, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: AppColors.onBackground, size: 26),
            const SizedBox(width: 16),
            Text(title, style: AppTextStyles.bodyLarge.copyWith(color: AppColors.onBackground)),
          ],
        ),
      ),
    );
  }
}
