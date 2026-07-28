import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_right/models/shared_content_model.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/services/share_to_chat_service.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Post Detail Screen - View full post with comments
/// Modern Instagram-inspired design for personal fitness posts
class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _storageService = Get.find<StorageService>();
  late AnimationController _likeAnimationController;
  late Animation<double> _likeAnimation;

  late Map<String, dynamic> _post;
  bool _isLiked = false;
  bool _isSaved = false;
  int _likes = 0;
  bool _showAppBarTitle = false;

  // Mock comments data
  final List<Map<String, dynamic>> _comments = [
    {
      'id': '1',
      'user': 'Mike Johnson',
      'userInitials': 'MJ',
      'comment': 'Great form! This really helped me improve my technique.',
      'timestamp': '2 hours ago',
      'likes': 24,
      'isLiked': false,
    },
    {
      'id': '2',
      'user': 'Sarah Williams',
      'userInitials': 'SW',
      'comment': 'Can you make a video about deadlift form next? 🙏',
      'timestamp': '5 hours ago',
      'likes': 12,
      'isLiked': false,
    },
    {
      'id': '3',
      'user': 'Alex Chen',
      'userInitials': 'AC',
      'comment': 'This is exactly what I needed! Thanks for sharing 💪',
      'timestamp': '1 day ago',
      'likes': 8,
      'isLiked': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _post = Get.arguments as Map<String, dynamic>? ?? _getMockPost();
    _isLiked = _post['isLiked'] ?? false;
    _isSaved = _storageService.isPostSaved(_post['id'] ?? '');
    _likes = _post['likes'] ?? 0;

    // Initialize like animation
    _likeAnimationController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _likeAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _likeAnimationController, curve: Curves.elasticOut));

    // Listen to scroll for app bar title
    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showAppBarTitle) {
        setState(() => _showAppBarTitle = true);
      } else if (_scrollController.offset <= 300 && _showAppBarTitle) {
        setState(() => _showAppBarTitle = false);
      }
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    _likeAnimationController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getMockPost() {
    return {
      'id': '1',
      'creator': 'brogan seier',
      'creatorInitials': 'BS',
      'title': 'Perfect Squat Form',
      'description': 'Master your squat technique with these tips!',
      'isVideo': true,
      'thumbnail': 'https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=800',
      'likes': 315,
      'comments': 42,
      'saves': 89,
      'shares': 23,
      'isLiked': false,
      'isSaved': false,
      'timestamp': '2 hours ago',
      'duration': '1:24',
      'tags': ['#fitness', '#squat', '#formcheck'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Modern App Bar with smooth transitions
            SliverAppBar(
              systemOverlayStyle: SystemUiOverlayStyle.light,
              expandedHeight: MediaQuery.of(context).size.height * 0.5,
              pinned: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                ),
                onPressed: () => Get.back(),
              ),
              title: AnimatedOpacity(
                opacity: _showAppBarTitle ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _post['creator'] ?? '',
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                ),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: const Icon(Icons.more_vert, color: Colors.white),
                  ),
                  onPressed: _showPostOptions,
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: GestureDetector(
                  onDoubleTap: _handleDoubleTap,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Post Image/Video Thumbnail
                      Hero(
                        tag: 'post_${_post['id']}',
                        child: Image.network(
                          _post['thumbnail'] ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.6)]),
                            ),
                          ),
                        ),
                      ),
                      // Subtle gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withValues(alpha: 0.3), Colors.transparent, Colors.black.withValues(alpha: 0.5)],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      // Play button for videos
                      if (_post['isVideo'] == true)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2)],
                            ),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 56),
                          ),
                        ),
                      // Duration badge
                      if (_post['duration'] != null)
                        Positioned(
                          bottom: 10,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_circle_outline, color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  _post['duration'],
                                  style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Double-tap heart animation
                      Center(
                        child: AnimatedBuilder(
                          animation: _likeAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _likeAnimation.value,
                              child: Opacity(
                                opacity: _likeAnimationController.isAnimating ? 1.0 : 0.0,
                                child: Icon(
                                  Icons.favorite,
                                  color: Colors.white,
                                  size: 120,
                                  shadows: [Shadow(color: AppColors.error.withValues(alpha: 0.5), blurRadius: 30)],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Post Content
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instagram-style Action Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Like button
                        ScaleTransition(
                          scale: _likeAnimation,
                          child: IconButton(
                            icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border, size: 25),
                            color: _isLiked ? AppColors.error : AppColors.onBackground,
                            onPressed: _handleLike,
                          ),
                        ),
                        // Comment button
                        IconButton(
                          icon: const Icon(Icons.mode_comment_outlined, size: 25),
                          color: AppColors.onBackground,
                          onPressed: () {
                            _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                          },
                        ),
                        // Share button
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.share_outlined, size: 28), color: AppColors.onBackground, onPressed: _showShareOptions),
                        // Save button
                        IconButton(
                          icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border, size: 25),
                          color: _isSaved ? AppColors.accent : AppColors.onBackground,
                          onPressed: _handleSave,
                        ),
                      ],
                    ),
                  ),

                  // Likes count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '${_formatCount(_likes)} likes',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Creator Info & Caption
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                          child: Text(
                            _post['creatorInitials'] ?? 'U',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _post['creator'] ?? 'Unknown',
                                    style: AppTextStyles.titleSmall.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(_post['timestamp'] ?? '', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Title as bold caption
                              RichText(
                                text: TextSpan(
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, height: 1.4),
                                  children: [
                                    TextSpan(
                                      text: '${_post['title'] ?? ''}\n',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    TextSpan(text: _post['description'] ?? ''),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // Tags
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: (_post['tags'] as List<String>? ?? []).map((tag) {
                                  return Text(
                                    tag,
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // View all comments link
                  GestureDetector(
                    onTap: () {
                      _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text('View all ${_comments.length} comments', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Divider(height: 1, thickness: 1, color: AppColors.primaryGray.withValues(alpha: 0.2)),
                  const SizedBox(height: 16),

                  // Comments Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Comments',
                      style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Comments List
                  ..._comments.map((comment) => _buildCommentItem(comment)).toList(),

                  const SizedBox(height: 80), // Space for bottom input
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildCommentInput(),
      ),
    );
  }

  void _handleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
    });
    if (_isLiked) {
      _likeAnimationController.forward().then((_) {
        _likeAnimationController.reverse();
      });
    }
  }

  Future<void> _handleSave() async {
    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !_isSaved;
      _post['isSaved'] = _isSaved;
    });
    if (!wasSaved) {
      await _storageService.addSavedPost(_post);
      Get.snackbar(
        'Saved',
        'Post saved to your collection',
        backgroundColor: AppColors.accent,
        colorText: AppColors.onAccent,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } else {
      await _storageService.removeSavedPost(_post['id'] ?? '');
      Get.snackbar(
        'Unsaved',
        'Post removed from collection',
        backgroundColor: AppColors.primaryGray,
        colorText: AppColors.onPrimary,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  void _handleDoubleTap() {
    if (!_isLiked) {
      _handleLike();
    }
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accent.withValues(alpha: 0.2),
            child: Text(
              comment['userInitials'],
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment content
                RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground, height: 1.4),
                    children: [
                      TextSpan(
                        text: '${comment['user']} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: comment['comment']),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Comment actions
                Row(
                  children: [
                    Text(comment['timestamp'], style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        // TODO: Like comment
                      },
                      child: Text(
                        '${comment['likes']} likes',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        // TODO: Reply to comment
                      },
                      child: Text(
                        'Reply',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Like button
          GestureDetector(
            onTap: () {
              // TODO: Like comment
            },
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(comment['isLiked'] ? Icons.favorite : Icons.favorite_border, size: 16, color: comment['isLiked'] ? AppColors.error : AppColors.primaryGray),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: MediaQuery.of(context).viewInsets.bottom + 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.primaryGray.withValues(alpha: 0.2), width: 1)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // User avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
              child: Text(
                'YU',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            // Comment input
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onBackground),
              ),
            ),
            const SizedBox(width: 8),
            // Post button
            GestureDetector(
              onTap: () {
                if (_commentController.text.trim().isNotEmpty) {
                  // TODO: Post comment
                  _commentController.clear();
                  Get.snackbar(
                    'Posted',
                    'Your comment has been added',
                    backgroundColor: AppColors.completed,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.BOTTOM,
                    duration: const Duration(seconds: 2),
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12,
                  );
                }
              },
              child: Text(
                'Post',
                style: AppTextStyles.titleSmall.copyWith(color: _commentController.text.trim().isNotEmpty ? AppColors.accent : AppColors.primaryGray, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostOptions() {
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
              decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 8),
            _buildOptionItem(Icons.edit_outlined, 'Edit Post', () {
              Navigator.pop(context);
              // TODO: Edit post
            }),
            _buildOptionItem(Icons.delete_outline, 'Delete Post', () {
              Navigator.pop(context);
              // TODO: Delete post
            }),
            Divider(height: 1, thickness: 1, color: AppColors.primaryGray.withValues(alpha: 0.2)),
            _buildOptionItem(Icons.share_outlined, 'Share Post', () {
              Navigator.pop(context);
              _showShareOptions();
            }),
            _buildOptionItem(Icons.link, 'Copy Link', () {
              Navigator.pop(context);
              Get.snackbar(
                'Link Copied',
                'Post link copied to clipboard',
                backgroundColor: AppColors.completed,
                colorText: Colors.white,
                snackPosition: SnackPosition.BOTTOM,
                margin: const EdgeInsets.all(16),
                borderRadius: 12,
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(
                'Share Post',
                style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(Icons.message_outlined, 'Message', () {
                    Navigator.pop(context);
                    final feedId = (_post['id'] ?? _post['_id'] ?? '').toString().trim();
                    if (!WorkoutRepository.isValidMongoId(feedId)) return;
                    ShareToChatService.share(context: context, type: SharedContentType.feed, contentId: feedId);
                  }),
                  _buildShareOption(Icons.link, 'Copy Link', () {
                    Navigator.pop(context);
                    Get.snackbar(
                      'Link Copied',
                      'Post link copied to clipboard',
                      backgroundColor: AppColors.completed,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.BOTTOM,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                  }),
                  _buildShareOption(Icons.ios_share, 'Share', () {
                    Navigator.pop(context);
                    // TODO: Share via system
                  }),
                  _buildShareOption(Icons.qr_code, 'QR Code', () {
                    Navigator.pop(context);
                    // TODO: Show QR code
                  }),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
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

  Widget _buildShareOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(icon, color: AppColors.accent, size: 28),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.w500),
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
}
