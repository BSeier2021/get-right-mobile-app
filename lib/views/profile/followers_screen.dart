import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Followers Screen - Display list of followers
class FollowersScreen extends StatefulWidget {
  const FollowersScreen({super.key});

  @override
  State<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  // Mock followers data
  final List<Map<String, dynamic>> _followers = [
    {'id': '1', 'name': 'Mike Johnson', 'username': 'mike_johnson', 'avatar': 'MJ', 'isFollowing': false, 'isFollowedBy': true},
    {'id': '2', 'name': 'Sarah Williams', 'username': 'sarah_w', 'avatar': 'SW', 'isFollowing': true, 'isFollowedBy': true},
    {'id': '3', 'name': 'Alex Chen', 'username': 'alexchen_fit', 'avatar': 'AC', 'isFollowing': false, 'isFollowedBy': true},
    {'id': '4', 'name': 'Emma Davis', 'username': 'emma_davis', 'avatar': 'ED', 'isFollowing': true, 'isFollowedBy': true},
    {'id': '5', 'name': 'David Brown', 'username': 'david_brown_fit', 'avatar': 'DB', 'isFollowing': false, 'isFollowedBy': true},
  ];

  void _toggleFollow(String id) {
    setState(() {
      final follower = _followers.firstWhere((f) => f['id'] == id);
      follower['isFollowing'] = !(follower['isFollowing'] ?? false);
    });
  }

  void _viewProfile(Map<String, dynamic> user) {
    // Navigate to user's profile screen
    Get.toNamed(AppRoutes.profile);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        centerTitle: true,
        title: Text('Followers', style: AppTextStyles.titleLarge.copyWith()),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _followers.length,
        itemBuilder: (context, index) {
          final follower = _followers[index];
          return _buildUserCard(follower);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isFollowing = user['isFollowing'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGray.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => _viewProfile(user),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.accent.withOpacity(0.2),
              child: Text(
                user['avatar'] ?? 'U',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // User Info
          Expanded(
            child: GestureDetector(
              onTap: () => _viewProfile(user),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'] ?? '',
                    style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('@${user['username'] ?? ''}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
          ),
          // Follow Button
          ElevatedButton(
            onPressed: () => _toggleFollow(user['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? AppColors.primaryGray.withOpacity(0.2) : AppColors.accent,
              foregroundColor: isFollowing ? AppColors.onSurface : AppColors.onAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600, color: isFollowing ? AppColors.onSurface : AppColors.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}
