import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Saved Posts Screen - Display all bookmarked posts
class SavedPostsScreen extends StatefulWidget {
  const SavedPostsScreen({super.key});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  final _storageService = Get.find<StorageService>();
  List<Map<String, dynamic>> _savedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  void _loadSavedPosts() {
    setState(() {
      _isLoading = true;
      _savedPosts = _storageService.getSavedPosts();
      _isLoading = false;
    });
  }

  Future<void> _removePost(String postId) async {
    await _storageService.removeSavedPost(postId);
    _loadSavedPosts();
    Get.snackbar(
      'Removed',
      'Post removed from saved collection',
      backgroundColor: AppColors.primaryGray,
      colorText: AppColors.onPrimary,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 2),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        centerTitle: true,
        title: Text('Saved Posts', style: AppTextStyles.titleLarge.copyWith()),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _savedPosts.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: () async {
                _loadSavedPosts();
              },
              color: AppColors.accent,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _savedPosts.length,
                itemBuilder: (context, index) {
                  final post = _savedPosts[index];
                  return _buildPostCard(post);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
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
            'No Saved Posts',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Posts you bookmark will appear here',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Get.toNamed(AppRoutes.feed),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.explore, size: 20),
            label: Text('Explore Feed', style: AppTextStyles.buttonMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGray.withValues(alpha: 0.2), width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.accent.withValues(alpha: 0.2),
              child: Text(
                post['creatorInitials'] ?? post['creator']?[0]?.toUpperCase() ?? 'U',
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              post['creator'] ?? 'Unknown',
              style: AppTextStyles.titleSmall.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(post['timestamp'] ?? '', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
            trailing: PopupMenuButton(
              icon: Icon(Icons.more_vert, color: AppColors.primaryGray),
              itemBuilder: (context) => [
                PopupMenuItem(
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Text('Remove from Saved', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
                    ],
                  ),
                  onTap: () => Future.delayed(const Duration(milliseconds: 100), () => _removePost(post['id'] ?? '')),
                ),
              ],
            ),
          ),

          // Post Image/Thumbnail
          GestureDetector(
            onTap: () => Get.toNamed(AppRoutes.postDetail, arguments: post),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Stack(
                children: [
                  Image.network(
                    post['thumbnail'] ?? '',
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 300,
                      color: AppColors.primaryGray.withValues(alpha: 0.2),
                      child: Icon(Icons.image_not_supported, size: 48, color: AppColors.primaryGray),
                    ),
                  ),
                  if (post['isVideo'] == true)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                            if (post['duration'] != null) ...[const SizedBox(width: 4), Text(post['duration'], style: AppTextStyles.labelSmall.copyWith(color: Colors.white))],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Post Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                if (post['title'] != null)
                  Text(
                    post['title'],
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
                  ),
                if (post['title'] != null) const SizedBox(height: 8),

                // Description
                if (post['description'] != null)
                  Text(
                    post['description'],
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (post['description'] != null) const SizedBox(height: 12),

                // Engagement Stats
                Row(
                  children: [
                    _buildStatItem(Icons.favorite_outline, _formatCount(post['likes'] ?? 0), AppColors.primaryGray),
                    const SizedBox(width: 16),
                    _buildStatItem(Icons.comment_outlined, _formatCount(post['comments'] ?? 0), AppColors.primaryGray),
                    const SizedBox(width: 16),
                    _buildStatItem(Icons.bookmark, _formatCount(post['saves'] ?? 0), AppColors.accent),
                  ],
                ),

                // Category/Tags
                if (post['category'] != null || (post['tags'] != null && (post['tags'] as List).isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (post['category'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              post['category'],
                              style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (post['tags'] != null)
                          ...(post['tags'] as List)
                              .take(3)
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: AppColors.primaryGray.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Text(tag.toString(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray)),
                                ),
                              ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(
          count,
          style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
