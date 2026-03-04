import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';
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
  int _currentIndex = 0;
  final _storageService = Get.find<StorageService>();

  @override
  void initState() {
    super.initState();

    // Get arguments from GetX navigation
    final arguments = Get.arguments as Map<String, dynamic>?;
    _posts = arguments?['posts'] as List<Map<String, dynamic>>? ?? [];
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

    final post = _posts[index];
    final videoUrl = post['videoUrl'] as String?;

    if (videoUrl == null || videoUrl.isEmpty) return;

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      controller
          .initialize()
          .then((_) {
            if (mounted && _videoControllers.containsKey(index)) {
              setState(() {
                if (index == _currentIndex) {
                  controller.setLooping(true);
                  controller.play();
                  _isPlaying[index] = true;
                }
              });
            }
          })
          .catchError((error) {
            // Handle video loading error
            debugPrint('Error initializing video: $error');
          });

      _videoControllers[index] = controller;
      _isPlaying[index] = false;
    } catch (e) {
      debugPrint('Error creating video controller: $e');
    }
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
    if (!_videoControllers.containsKey(_currentIndex)) return;

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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player or thumbnail
        if (hasVideo)
          GestureDetector(
            onTap: _togglePlayPause,
            child: Center(
              child: AspectRatio(aspectRatio: _videoControllers[index]!.value.aspectRatio, child: VideoPlayer(_videoControllers[index]!)),
            ),
          )
        else
          GestureDetector(
            onTap: _togglePlayPause,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  post['thumbnail'] ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [const Color(0xFF9333EA), const Color(0xFFFBBF24)]),
                    ),
                  ),
                ),
                // Loading indicator
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
          right: 16.w,
          bottom: 100.h,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Profile Avatar
              GestureDetector(
                onTap: () => _navigateToCreatorProfile(post),
                child: Container(
                  margin: EdgeInsets.only(bottom: 20.h),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 25.r,
                    backgroundColor: AppColors.accent.withOpacity(0.2),
                    child: Text(
                      post['creatorImage'] ?? 'U',
                      style: AppTextStyles.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

              // Like button
              _buildVerticalInteractionButton(
                icon: post['isLiked'] ? Icons.favorite : Icons.favorite_border,
                count: post['likes'] ?? 0,
                color: post['isLiked'] ? Colors.red : Colors.white,
                onTap: () {
                  setState(() {
                    post['isLiked'] = !post['isLiked'];
                    post['likes'] += post['isLiked'] ? 1 : -1;
                  });
                },
              ),
              SizedBox(height: 20.h),

              // Comment button
              _buildVerticalInteractionButton(icon: Icons.comment_outlined, count: post['comments'] ?? 0, color: Colors.white, onTap: () => _showComments(post)),
              SizedBox(height: 20.h),

              // Save/Bookmark button
              _buildVerticalInteractionButton(
                icon: post['isSaved'] ? Icons.bookmark : Icons.bookmark_border,
                count: post['saves'] ?? 0,
                color: Colors.white,
                onTap: () async {
                  final isSaved = post['isSaved'] ?? false;
                  setState(() {
                    post['isSaved'] = !isSaved;
                    post['saves'] += !isSaved ? 1 : -1;
                  });
                  if (!isSaved) {
                    await _storageService.addSavedPost(post);
                  } else {
                    await _storageService.removeSavedPost(post['id']);
                  }
                },
              ),
              SizedBox(height: 20.h),

              // Share button
              _buildVerticalInteractionButton(icon: Icons.share_outlined, count: post['shares'] ?? 0, color: Colors.white, onTap: () => _showShareOptions(post)),
            ],
          ),
        ),

        // Bottom left text content
        Positioned(
          left: 16.w,
          bottom: 15.h,
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
                    if (post['isTrainer'])
                      Padding(
                        padding: EdgeInsets.only(left: 6.w),
                        child: Icon(Icons.verified, color: AppColors.completed, size: 18.sp),
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

  Widget _buildVerticalInteractionButton({required IconData icon, required int count, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 28.sp),
          SizedBox(height: 6.h),
          Text(
            _formatCount(count),
            style: AppTextStyles.labelSmall.copyWith(
              color: Colors.white,
              fontSize: 12.sp,
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

  void _showComments(Map<String, dynamic> post) {
    Get.snackbar('Comments', '${post['comments']} comments', backgroundColor: AppColors.accent, colorText: AppColors.onAccent, snackPosition: SnackPosition.BOTTOM);
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
