import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_right/models/report_block_model.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/services/share_to_chat_service.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/views/feed/feed_comments_sheet.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/trainer_certification_helper.dart';
import 'package:get_right/utils/feed_media_url.dart';
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
  final fromApi = feedPostDisplayImageUrl(post);
  if (fromApi != null) return fromApi;

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
      return 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200&auto=format&fit=crop&q=80';
  }
}

class FeedReelStyledThumbnail extends StatelessWidget {
  const FeedReelStyledThumbnail({super.key, required this.post, this.isFullScreen = false, this.imageUrlOverride});

  final Map<String, dynamic> post;
  final bool isFullScreen;

  /// When set, shows this URL instead of [resolveFeedReelThumbnailUrl] (multi-image carousel pages).
  final String? imageUrlOverride;

  @override
  Widget build(BuildContext context) {
    final rawUrl = imageUrlOverride ?? resolveFeedReelThumbnailUrl(post);
    final imageUrl = ImageUrlSanitizer.asHttpUrlOrFallback(
      (rawUrl).toString(),
      fallback: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=1200&auto=format&fit=crop&q=80',
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: isFullScreen ? BoxFit.contain : BoxFit.cover,
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

/// Full-screen photo layer — horizontal swipe when a post has multiple `images[]`.
class FeedReelPhotoCarousel extends StatefulWidget {
  const FeedReelPhotoCarousel({super.key, required this.post});

  final Map<String, dynamic> post;

  @override
  State<FeedReelPhotoCarousel> createState() => _FeedReelPhotoCarouselState();
}

class _FeedReelPhotoCarouselState extends State<FeedReelPhotoCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;

  List<String> get _urls => feedPostImageUrls(widget.post);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _urls;
    if (urls.isEmpty) {
      return FeedReelStyledThumbnail(post: widget.post, isFullScreen: true);
    }
    if (urls.length == 1) {
      return FeedReelStyledThumbnail(post: widget.post, isFullScreen: true, imageUrlOverride: urls.first);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: urls.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            return FeedReelStyledThumbnail(post: widget.post, isFullScreen: true, imageUrlOverride: urls[index]);
          },
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 52,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(urls.length, (index) {
              final active = index == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 8 : 6,
                height: active ? 8 : 6,
                decoration: BoxDecoration(color: active ? Colors.white : Colors.white.withOpacity(0.45), shape: BoxShape.circle),
              );
            }),
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 48,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(14)),
            child: Text(
              '${_currentIndex + 1}/${urls.length}',
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
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
    return SizedBox.expand(child: FeedReelPhotoCarousel(post: post));
  }
}

/// Like / comment / caption overlay used on reels (tap-through gradient).
class FeedReelChromeOverlay extends StatefulWidget {
  const FeedReelChromeOverlay({
    super.key,
    required this.post,
    this.videoController,
    this.onLikeStateChanged,
    this.onSaveStateChanged,
    this.onCommentCountChanged,
    this.onPostDeleted,
  });

  final Map<String, dynamic> post;
  final VideoPlayerController? videoController;

  /// Syncs like state across duplicate posts (e.g. For You vs Following lists).
  final void Function(String postId, bool isLiked, int likes)? onLikeStateChanged;

  /// Syncs save state across duplicate posts (e.g. For You vs Following lists).
  final void Function(String postId, bool isSaved, int saves)? onSaveStateChanged;

  /// Syncs comment count when comments are fetched (uses `totalDocs` from API).
  final void Function(String postId, int commentCount)? onCommentCountChanged;

  /// Called after the current user deletes this post successfully.
  final void Function(String postId)? onPostDeleted;

  @override
  State<FeedReelChromeOverlay> createState() => _FeedReelChromeOverlayState();
}

class _FeedReelChromeOverlayState extends State<FeedReelChromeOverlay> {
  final _storageService = Get.find<StorageService>();
  final FeedRepository _feedRepo = FeedRepository();
  bool _likeRequestInFlight = false;
  bool _saveRequestInFlight = false;
  bool _reportRequestInFlight = false;
  bool _descriptionExpanded = false;

  Map<String, dynamic> get _post => widget.post;

  @override
  void initState() {
    super.initState();
    _hydrateSaveStateFromStorage();
    _hydrateLikeStateFromStorage();
  }

  @override
  void didUpdateWidget(FeedReelChromeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.post['id'] ?? '').toString() != (_post['id'] ?? '').toString()) {
      _descriptionExpanded = false;
      _hydrateSaveStateFromStorage();
      _hydrateLikeStateFromStorage();
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

  void _hydrateLikeStateFromStorage() {
    if (_post['isLiked'] == true) return;
    final id = (_post['id'] ?? '').toString().trim();
    if (id.isEmpty || !_storageService.isFeedPostLiked(id)) return;
    _post['isLiked'] = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _navigateToCreatorProfile() {
    final String creatorName = (_post['creator'] ?? 'Creator').toString();
    final String initials = (_post['creatorImage'] ?? 'UT').toString();
    final bool isTrainer = _post['isTrainer'] == true;
    final bool certificationsVerified = isCertifiedFromUiMap(_post);
    final String category = (_post['category'] ?? 'Fitness').toString();

    final String creatorId = (_post['creatorId'] ?? '').toString().trim();

    final trainerData = <String, dynamic>{
      'returnToFeedOnBlock': true,
      if (creatorId.isNotEmpty) '_id': creatorId,
      if (creatorId.isNotEmpty) 'id': creatorId,
      if (creatorId.isEmpty) 'id': creatorName.toLowerCase().replaceAll(' ', '_'),
      if (isTrainer) 'role': 'Trainer',
      'isTrainer': isTrainer,
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

  void _openCommentsSheet(BuildContext dialogContext) {
    if (!dialogContext.mounted) return;
    final feedId = (_post['id'] ?? _post['_id'] ?? _post['feedId'] ?? '').toString().trim();
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
          feedOwnerId: _reelCreatorUserId(),
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

  Widget _reelTopActionChip({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentVariant,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  static const int _descriptionCollapsedMaxLines = 2;

  TextStyle _descriptionTextStyle() {
    return AppTextStyles.bodyMedium.copyWith(
      color: Colors.white,
      fontSize: 14,
      shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
    );
  }

  Widget _buildPostDescription(BuildContext context) {
    final description = (_post['description'] ?? '').toString().trim();
    if (description.isEmpty) return const SizedBox.shrink();

    final textStyle = _descriptionTextStyle();
    final actionStyle = textStyle.copyWith(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white.withValues(alpha: 0.92));

    return LayoutBuilder(
      builder: (context, constraints) {
        final overflowPainter = TextPainter(
          text: TextSpan(text: description, style: textStyle),
          maxLines: _descriptionCollapsedMaxLines,
          textDirection: Directionality.of(context),
        )..layout(maxWidth: constraints.maxWidth);

        final canExpand = overflowPainter.didExceedMaxLines;
        final showToggle = canExpand || _descriptionExpanded;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              maxLines: _descriptionExpanded ? null : _descriptionCollapsedMaxLines,
              overflow: _descriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
              style: textStyle,
            ),
            if (showToggle)
              GestureDetector(
                onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(_descriptionExpanded ? 'View less' : 'View more', style: actionStyle),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildReelOverflowMenu(BuildContext context) {
    final isOwn = _isOwnReel();
    final isVideo = _post['isVideo'] == true;
    return PopupMenuButton<String>(
      tooltip: 'More options',
      padding: EdgeInsets.zero,
      offset: const Offset(0, 40),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'report') {
          unawaited(_showReportReelDialog());
        } else if (value == 'delete') {
          unawaited(_confirmDeleteOwnReel());
        }
      },
      itemBuilder: (context) {
        if (isOwn) {
          return [
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 22, color: AppColors.error),
                  const SizedBox(width: 12),
                  Text('Delete post', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ];
        }
        return [
          PopupMenuItem<String>(
            value: 'report',
            enabled: !_reportRequestInFlight,
            child: Row(
              children: [
                Icon(Icons.flag_outlined, size: 22, color: _reportRequestInFlight ? AppColors.primaryGray : AppColors.error),
                const SizedBox(width: 12),
                Text(
                  isVideo ? 'Report reel' : 'Report post',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ];
      },
      child: _reelTopActionChip(
        child: const Icon(Icons.more_horiz, color: Colors.white, size: 24),
      ),
    );
  }

  String? _currentUserIdOrNull() => _storageService.getUserId()?.trim();

  String? _reelCreatorUserId() => (_post['creatorId'] ?? '').toString().trim();

  /// True when the logged-in user owns this post.
  bool _isOwnReel() {
    final me = _currentUserIdOrNull();
    final creator = _reelCreatorUserId();
    if (me == null || me.isEmpty || creator == null || creator.isEmpty) return false;
    return me == creator;
  }

  Future<void> _showReportReelDialog() async {
    final feedId = (_post['id'] ?? '').toString().trim();
    final creatorUserId = _reelCreatorUserId();
    if (feedId.isEmpty || creatorUserId == null || creatorUserId.isEmpty || _currentUserIdOrNull() == null) {
      if (feedId.isNotEmpty && (creatorUserId == null || creatorUserId.isEmpty)) {
        Get.snackbar('Could not report', 'Creator information is missing for this reel.', snackPosition: SnackPosition.BOTTOM);
      }
      return;
    }

    final descriptionController = TextEditingController();
    String? selectedReason;

    await Get.dialog<void>(
      Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return Padding(
              padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24 + MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Report reel', style: AppTextStyles.titleLarge.copyWith(color: AppColors.onSurface)),
                    const SizedBox(height: 16),
                    Text(
                      'Reason',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ...ReportReasons.all.map(
                      (reason) => RadioListTile<String>(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(ReportReasons.getDisplayName(reason), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface)),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (value) => setDialogState(() => selectedReason = value),
                        activeColor: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Additional details (optional)',
                        labelStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: AppColors.accent, width: 2),
                        ),
                      ),
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                      maxLines: 3,
                      maxLength: 2000,
                      textInputAction: TextInputAction.done,
                      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                    ),
                    if (MediaQuery.of(context).viewInsets.bottom > 0) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                          icon: const Icon(Icons.keyboard_hide_outlined, size: 18),
                          label: const Text('Done'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: selectedReason == null
                              ? null
                              : () async {
                                  final apiReason = ReportReasons.getApiValue(selectedReason!);
                                  final details = descriptionController.text.trim();
                                  Get.back();
                                  await _submitReportReel(creatorUserId: creatorUserId, feedId: feedId, reason: apiReason, details: details.isEmpty ? null : details);
                                },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.onAccent),
                          child: const Text('Submit'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      descriptionController.dispose();
    });
  }

  Future<void> _submitReportReel({required String creatorUserId, required String feedId, required String reason, String? details}) async {
    if (_reportRequestInFlight) return;
    setState(() => _reportRequestInFlight = true);
    try {
      await _feedRepo.reportFeedRepo(creatorUserId: creatorUserId, feedId: feedId, reason: reason, details: details, reportRefType: ReportRefType.feeds);
      Get.snackbar('Report submitted', 'Thank you for your feedback.', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Could not report', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _reportRequestInFlight = false);
    }
  }

  Future<void> _confirmDeleteOwnReel() async {
    final feedId = (_post['id'] ?? '').toString().trim();
    if (feedId.isEmpty) return;

    final dialogContext = Get.context;
    if (dialogContext == null || !dialogContext.mounted) return;

    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete post?', style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface)),
        content: Text('This post will be permanently removed.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _feedRepo.deleteFeedRepo(feedId);
      if (!mounted) return;
      widget.onPostDeleted?.call(feedId);
      Get.snackbar('Deleted', 'Post removed', snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.completed, colorText: Colors.white);
    } catch (e) {
      if (!mounted) return;
      Get.snackbar('Could not delete', e.toString(), snackPosition: SnackPosition.BOTTOM, backgroundColor: AppColors.error, colorText: Colors.white);
    }
  }

  String? _feedIdForShare() {
    final id = (_post['id'] ?? _post['_id'] ?? _post['feedId'] ?? '').toString().trim();
    return WorkoutRepository.isValidMongoId(id) ? id : null;
  }

  void _shareFeedToChat(BuildContext hostContext) {
    final feedId = _feedIdForShare();
    if (feedId == null) {
      Get.snackbar(
        'Cannot share',
        'This post is not ready to share yet',
        backgroundColor: AppColors.error,
        colorText: AppColors.onError,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    ShareToChatService.share(context: hostContext, type: SharedContentType.feed, contentId: feedId);
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

  Widget _buildPostMetaColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _navigateToCreatorProfile,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '@${(_post['creator'] ?? 'user').toString().toLowerCase().replaceAll(' ', '')}',
                style: AppTextStyles.titleSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.7), blurRadius: 6, offset: const Offset(0, 2))],
                ),
              ),
              // if (showFeedCreatorVerifiedBadge(_post)) ...[
              //   const SizedBox(width: 6),
              //   verifiedBadgeIcon(size: 16),
              // ],
            ],
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
        if (((_post['description'] ?? '').toString().trim()).isNotEmpty) ...[const SizedBox(height: 8), _buildPostDescription(context)],
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
    );
  }

  Widget _buildInteractionColumn(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFeedCreatorVerifiedBadge(_post)) ...[
          GestureDetector(
            onTap: () {},
            child: Image.asset('assets/images/verify.png', width: 35.w),
          ),
          const SizedBox(height: 20),
        ],
        _likeButton(context),
        const SizedBox(height: 20),
        _commentButton(context),
        const SizedBox(height: 20),
        _saveButton(context),
        const SizedBox(height: 20),
        _buildVerticalInteractionSvgButton(assetPath: 'assets/icons/share.svg', count: _post['shares'] ?? 0, onTap: () => _shareFeedToChat(context)),
      ],
    );
  }

  Widget _buildBottomOverlay(BuildContext context) {
    final isVideo = _post['isVideo'] == true;
    return SafeArea(
      top: false,
      minimum: EdgeInsets.only(bottom: isVideo ? 4 : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _buildPostMetaColumn()),
                const SizedBox(width: 12),
                _buildInteractionColumn(context),
              ],
            ),
          ),
          if (isVideo)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _FeedReelVideoProgressBar(controller: widget.videoController),
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
          top: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildReelOverflowMenu(context),
                  if (_post['isVideo'] == true) ...[
                    const SizedBox(height: 8),
                    _reelTopActionChip(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 4.w),
                          _playbackDurationBadge(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomOverlay(context)),
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
        await _storageService.removeLikedFeedPostId(feedId);
      } else {
        await _feedRepo.likeFeedRepo(feedId);
        await _storageService.addLikedFeedPostId(feedId);
      }
    } catch (e) {
      if (!wasLiked && _isAlreadyLikedError(e)) {
        await _storageService.addLikedFeedPostId(feedId);
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
          Icon(isSaved ? Icons.bookmark : Icons.bookmark_border, size: 28, color: isSaved ? AppColors.accent : Colors.white),
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
    if (!mounted) return;
    final c = widget.controller;
    if (c == null) return;
    try {
      if (!c.value.isInitialized) return;
    } catch (_) {
      return;
    }
    setState(() {});
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
    if (!mounted || _scrubbing) return;
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
    if (!mounted) return const SizedBox.shrink();
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
