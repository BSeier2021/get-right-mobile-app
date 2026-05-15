import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/views/feed/feed_comments_sheet.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';
import 'package:video_player/video_player.dart';

/// Remaining playback time for the reel timer (e.g. `18s`, `1:05`).
String formatFeedReelRemainingLabel(Duration remaining) {
  final ms = remaining.inMilliseconds;
  if (ms <= 0) return '0s';
  final totalSec = (ms + 999) ~/ 1000;
  if (totalSec < 60) return '${totalSec}s';
  final m = totalSec ~/ 60;
  final s = totalSec % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatFeedInteractionCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return count.toString();
}

String resolveFeedReelThumbnailUrl(Map<String, dynamic> post) {
  final String category = (post['category'] ?? '').toString().toLowerCase();
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
      final raw = (post['thumbnail'] ?? '').toString();
      return ImageUrlSanitizer.asHttpUrlOrFallback(raw, fallback: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200&auto=format&fit=crop&q=80');
  }
}

class FeedReelStyledThumbnail extends StatelessWidget {
  const FeedReelStyledThumbnail({super.key, required this.post, this.isFullScreen = false});

  final Map<String, dynamic> post;
  final bool isFullScreen;

  @override
  Widget build(BuildContext context) {
    final rawUrl = resolveFeedReelThumbnailUrl(post);
    final imageUrl = ImageUrlSanitizer.asHttpUrlOrFallback(
      (rawUrl).toString(),
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
}

/// Backdrop blur layer behind the reel video player.
class FeedReelBackdrop extends StatelessWidget {
  const FeedReelBackdrop({super.key, required this.post});

  final Map<String, dynamic> post;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: FeedReelStyledThumbnail(post: post, isFullScreen: true));
  }
}

/// Like / comment / caption overlay used on reels (tap-through gradient).
class FeedReelChromeOverlay extends StatefulWidget {
  const FeedReelChromeOverlay({super.key, required this.post, this.videoController, this.onLikeStateChanged, this.onSaveStateChanged, this.onCommentCountChanged});

  final Map<String, dynamic> post;
  final VideoPlayerController? videoController;

  /// Syncs like state across duplicate posts (e.g. For You vs Following lists).
  final void Function(String postId, bool isLiked, int likes)? onLikeStateChanged;

  /// Syncs save state across duplicate posts (e.g. For You vs Following lists).
  final void Function(String postId, bool isSaved, int saves)? onSaveStateChanged;

  /// Syncs comment count when comments are fetched (uses `totalDocs` from API).
  final void Function(String postId, int commentCount)? onCommentCountChanged;

  @override
  State<FeedReelChromeOverlay> createState() => _FeedReelChromeOverlayState();
}

class _FeedReelChromeOverlayState extends State<FeedReelChromeOverlay> {
  final _storageService = Get.find<StorageService>();
  final FeedRepository _feedRepo = FeedRepository();
  bool _likeRequestInFlight = false;
  bool _saveRequestInFlight = false;

  Map<String, dynamic> get _post => widget.post;

  @override
  void initState() {
    super.initState();
    _hydrateSaveStateFromStorage();
  }

  @override
  void didUpdateWidget(FeedReelChromeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.post['id'] ?? '').toString() != (_post['id'] ?? '').toString()) {
      _hydrateSaveStateFromStorage();
    }
  }

  void _hydrateSaveStateFromStorage() {
    if (_post['isSaved'] == true) return;
    final id = (_post['id'] ?? '').toString().trim();
    if (id.isEmpty || !_storageService.isPostSaved(id)) return;
    _post['isSaved'] = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _navigateToCreatorProfile() {
    final String creatorName = (_post['creator'] ?? 'Creator').toString();
    final String initials = (_post['creatorImage'] ?? 'UT').toString();
    final bool isTrainer = _post['isTrainer'] == true;
    final String category = (_post['category'] ?? 'Fitness').toString();

    final String creatorId = (_post['creatorId'] ?? '').toString().trim();

    final trainerData = <String, dynamic>{
      if (creatorId.isNotEmpty) '_id': creatorId,
      if (creatorId.isNotEmpty) 'id': creatorId,
      if (creatorId.isEmpty) 'id': creatorName.toLowerCase().replaceAll(' ', '_'),
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

  void _openCommentsSheet(BuildContext dialogContext) {
    final feedId = (_post['id'] ?? '').toString().trim();
    if (feedId.isEmpty) return;

    final initialCount = (_post['comments'] is num) ? (_post['comments'] as num).toInt() : 0;

    showModalBottomSheet(
      context: dialogContext,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return FeedCommentsSheet(
          feedId: feedId,
          initialCommentCount: initialCount,
          onCommentCountChanged: (count) {
            _post['comments'] = count;
            widget.onCommentCountChanged?.call(feedId, count);
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  void _showShareOptions(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
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

  Widget _playbackDurationBadge() {
    final fallback = (_post['duration'] ?? '30s').toString();
    return _FeedReelPlaybackTimer(controller: widget.videoController, fallbackText: fallback);
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
            formatFeedInteractionCount(count),
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

  @override
  Widget build(BuildContext context) {
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
          top: 55,
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
                SizedBox(width: 4.w),
                _playbackDurationBadge(),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {},
                child: Image.asset('assets/images/verify.png', width: 35.w),
              ),
              const SizedBox(height: 20),
              _likeButton(context),
              const SizedBox(height: 20),
              _commentButton(context),
              const SizedBox(height: 20),
              _saveButton(context),
              const SizedBox(height: 20),
              _buildVerticalInteractionSvgButton(assetPath: 'assets/icons/share.svg', count: _post['shares'] ?? 0, onTap: () => _showShareOptions(context)),
            ],
          ),
        ),
        Positioned(
          left: 16,
          bottom: 64,
          right: 100,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _navigateToCreatorProfile,
                child: Text(
                  '@${(_post['creator'] ?? 'user').toString().toLowerCase().replaceAll(' ', '')}',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                ),
              ),
              if (((_post['title'] ?? '').toString().trim()).isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  (_post['title'] ?? '').toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _post['description'] ?? '',
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
                    (_post['tags'] as List<String>?)
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
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _FeedReelVideoProgressBar(controller: widget.videoController),
            ),
          ),
        ),
      ],
    );
  }

  void _applyLikeState(bool isLiked, int likes) {
    _post['isLiked'] = isLiked;
    _post['likes'] = likes;
    final postId = (_post['id'] ?? '').toString();
    if (postId.isNotEmpty) {
      widget.onLikeStateChanged?.call(postId, isLiked, likes);
    }
  }

  bool _isAlreadyLikedError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('already liked');
  }

  Future<void> _toggleLike() async {
    if (_likeRequestInFlight) return;
    final feedId = (_post['id'] ?? '').toString().trim();
    if (feedId.isEmpty) return;

    final wasLiked = _post['isLiked'] == true;
    final prevCount = (_post['likes'] is num) ? (_post['likes'] as num).toInt() : 0;
    final nextLiked = !wasLiked;
    final nextCount = (prevCount + (nextLiked ? 1 : -1)).clamp(0, 1 << 30);

    setState(() => _applyLikeState(nextLiked, nextCount));

    _likeRequestInFlight = true;
    try {
      if (wasLiked) {
        await _feedRepo.unlikeFeedRepo(feedId);
      } else {
        await _feedRepo.likeFeedRepo(feedId);
      }
    } catch (e) {
      if (!wasLiked && _isAlreadyLikedError(e)) {
        return;
      }
      if (mounted) {
        setState(() => _applyLikeState(wasLiked, prevCount));
        final message = e is BadRequestException ? e.toString() : 'Could not update like. Please try again.';
        Get.snackbar('Like', message, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
      }
    } finally {
      _likeRequestInFlight = false;
    }
  }

  Widget _likeButton(BuildContext context) {
    final bool isLiked = _post['isLiked'] ?? false;
    final int count = (_post['likes'] is num) ? (_post['likes'] as num).toInt() : 0;
    return GestureDetector(
      onTap: _toggleLike,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 28, color: isLiked ? Colors.red : Colors.white),
          const SizedBox(height: 6),
          Text(
            formatFeedInteractionCount(count),
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

  Widget _commentButton(BuildContext context) {
    final int count = _post['comments'] ?? 0;
    return GestureDetector(
      onTap: () => _openCommentsSheet(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/messagee.svg', width: 28, height: 28, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          const SizedBox(height: 6),
          Text(
            formatFeedInteractionCount(count),
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

  void _applySaveState(bool isSaved, int saves) {
    _post['isSaved'] = isSaved;
    _post['saves'] = saves;
    final postId = (_post['id'] ?? '').toString();
    if (postId.isNotEmpty) {
      widget.onSaveStateChanged?.call(postId, isSaved, saves);
    }
  }

  bool _isAlreadySavedError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('already saved');
  }

  Future<void> _toggleSave() async {
    if (_saveRequestInFlight) return;
    final feedId = (_post['id'] ?? '').toString().trim();
    if (feedId.isEmpty) return;

    final wasSaved = _post['isSaved'] == true;
    final prevCount = (_post['saves'] is num) ? (_post['saves'] as num).toInt() : 0;
    final nextSaved = !wasSaved;
    final nextCount = (prevCount + (nextSaved ? 1 : -1)).clamp(0, 1 << 30);

    setState(() => _applySaveState(nextSaved, nextCount));

    _saveRequestInFlight = true;
    try {
      if (wasSaved) {
        await _feedRepo.unsaveFeedRepo(feedId);
        await _storageService.removeSavedPost(feedId);
      } else {
        await _feedRepo.saveFeedRepo(feedId);
        await _storageService.addSavedPost(_post);
      }
    } catch (e) {
      if (!wasSaved && _isAlreadySavedError(e)) {
        await _storageService.addSavedPost(_post);
        if (mounted) setState(() => _applySaveState(true, prevCount + 1));
        return;
      }
      if (mounted) {
        setState(() => _applySaveState(wasSaved, prevCount));
        final message = e is BadRequestException ? e.toString() : 'Could not update save. Please try again.';
        Get.snackbar('Save', message, snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 2));
      }
    } finally {
      _saveRequestInFlight = false;
    }
  }

  Widget _saveButton(BuildContext context) {
    final bool isSaved = _post['isSaved'] ?? false;
    final int count = (_post['saves'] is num) ? (_post['saves'] as num).toInt() : 0;
    return GestureDetector(
      onTap: _toggleSave,
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
            formatFeedInteractionCount(count),
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
}

class _FeedReelPlaybackTimer extends StatefulWidget {
  const _FeedReelPlaybackTimer({required this.controller, required this.fallbackText});

  final VideoPlayerController? controller;
  final String fallbackText;

  @override
  State<_FeedReelPlaybackTimer> createState() => _FeedReelPlaybackTimerState();
}

class _FeedReelPlaybackTimerState extends State<_FeedReelPlaybackTimer> {
  void _onVideoTick() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onVideoTick);
  }

  @override
  void didUpdateWidget(_FeedReelPlaybackTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onVideoTick);
      widget.controller?.addListener(_onVideoTick);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onVideoTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    String label = widget.fallbackText;
    if (c != null && c.value.isInitialized) {
      final d = c.value.duration;
      if (d > Duration.zero) {
        var rem = d - c.value.position;
        if (rem.isNegative) rem = Duration.zero;
        label = formatFeedReelRemainingLabel(rem);
      }
    }
    return Text(
      label,
      style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.w600),
    );
  }
}

/// Thin seekable progress for feed reels (full width above safe area).
class _FeedReelVideoProgressBar extends StatefulWidget {
  const _FeedReelVideoProgressBar({required this.controller});

  final VideoPlayerController? controller;

  @override
  State<_FeedReelVideoProgressBar> createState() => _FeedReelVideoProgressBarState();
}

class _FeedReelVideoProgressBarState extends State<_FeedReelVideoProgressBar> {
  bool _scrubbing = false;
  double? _scrubFrac;

  void _onVideoTick() {
    if (_scrubbing || !mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onVideoTick);
  }

  @override
  void didUpdateWidget(_FeedReelVideoProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onVideoTick);
      widget.controller?.addListener(_onVideoTick);
      _scrubbing = false;
      _scrubFrac = null;
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onVideoTick);
    super.dispose();
  }

  double _sliderValue(VideoPlayerController c) {
    final d = c.value.duration;
    if (d == Duration.zero) return 0;
    if (_scrubbing && _scrubFrac != null) return _scrubFrac!.clamp(0.0, 1.0);
    final p = c.value.position;
    return (p.inMicroseconds / d.inMicroseconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c == null || !c.value.isInitialized) {
      return const SizedBox.shrink();
    }
    final d = c.value.duration;
    if (d == Duration.zero) {
      return const SizedBox.shrink();
    }

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.28),
        thumbColor: Colors.white,
        overlayColor: Colors.white.withValues(alpha: 0.18),
      ),
      child: Slider(
        value: _sliderValue(c),
        min: 0,
        max: 1,
        onChangeStart: (_) {
          setState(() {
            _scrubbing = true;
          });
        },
        onChanged: (v) {
          setState(() {
            _scrubFrac = v;
          });
        },
        onChangeEnd: (v) async {
          final controller = widget.controller;
          if (controller != null && controller.value.isInitialized) {
            final total = controller.value.duration;
            final targetMs = (v * total.inMilliseconds).round().clamp(0, total.inMilliseconds);
            await controller.seekTo(Duration(milliseconds: targetMs));
          }
          if (mounted) {
            setState(() {
              _scrubbing = false;
              _scrubFrac = null;
            });
          }
        },
      ),
    );
  }
}
