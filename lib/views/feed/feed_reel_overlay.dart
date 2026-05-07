import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

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
  const FeedReelChromeOverlay({super.key, required this.post});

  final Map<String, dynamic> post;

  @override
  State<FeedReelChromeOverlay> createState() => _FeedReelChromeOverlayState();
}

class _FeedReelChromeOverlayState extends State<FeedReelChromeOverlay> {
  final _storageService = Get.find<StorageService>();

  Map<String, dynamic> get _post => widget.post;

  void _navigateToCreatorProfile() {
    final String creatorName = (_post['creator'] ?? 'Creator').toString();
    final String initials = (_post['creatorImage'] ?? 'UT').toString();
    final bool isTrainer = _post['isTrainer'] == true;
    final String category = (_post['category'] ?? 'Fitness').toString();

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

  void _openCommentsSheet(BuildContext dialogContext) {
    showModalBottomSheet(
      context: dialogContext,
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
                  Text(formatFeedInteractionCount(_post['comments'] ?? 0), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
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
                  const SizedBox(width: 8),
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
                Text(
                  _post['duration'] ?? '30s',
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
          bottom: 30,
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
      ],
    );
  }

  Widget _likeButton(BuildContext context) {
    final bool isLiked = _post['isLiked'] ?? false;
    final int count = _post['likes'] ?? 0;
    return GestureDetector(
      onTap: () {
        setState(() {
          _post['isLiked'] = !isLiked;
          _post['likes'] = (_post['likes'] ?? 0) + ((_post['isLiked'] as bool) ? 1 : -1);
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset('assets/icons/heart.svg', width: 28, height: 28, colorFilter: ColorFilter.mode(isLiked ? Colors.red : Colors.white, BlendMode.srcIn)),
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

  Widget _saveButton(BuildContext context) {
    final bool isSaved = _post['isSaved'] ?? false;
    final int count = _post['saves'] ?? 0;
    return GestureDetector(
      onTap: () async {
        final wasSaved = isSaved;
        setState(() {
          _post['isSaved'] = !wasSaved;
          _post['saves'] = (_post['saves'] ?? 0) + (!wasSaved ? 1 : -1);
        });
        if (!wasSaved) {
          await _storageService.addSavedPost(_post);
        } else {
          await _storageService.removeSavedPost(_post['id']);
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
