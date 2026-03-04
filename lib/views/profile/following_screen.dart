import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Following Screen - Display list of users being followed
class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  // Mock following data
  final List<Map<String, dynamic>> _following = [
    {'id': '1', 'name': 'John Trainer', 'username': 'john_trainer', 'avatar': 'JT', 'isFollowing': true, 'isVerified': true},
    {'id': '2', 'name': 'Fitness Queen', 'username': 'fitness_queen', 'avatar': 'FQ', 'isFollowing': true, 'isVerified': false},
    {'id': '3', 'name': 'Power Lifter Pro', 'username': 'powerlifter_pro', 'avatar': 'PL', 'isFollowing': true, 'isVerified': true},
    {'id': '4', 'name': 'Yoga Master', 'username': 'yoga_master', 'avatar': 'YM', 'isFollowing': true, 'isVerified': false},
  ];

  void _toggleFollow(String id) {
    setState(() {
      final user = _following.firstWhere((f) => f['id'] == id);
      final wasFollowing = user['isFollowing'] ?? false;
      user['isFollowing'] = !wasFollowing;

      if (wasFollowing) {
        // Remove from following list
        _following.removeWhere((f) => f['id'] == id);
      }
    });

    if (_following.isEmpty) {
      Get.snackbar(
        'Unfollowed',
        'You are not following anyone',
        backgroundColor: AppColors.primaryGray,
        colorText: AppColors.onPrimary,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
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
        centerTitle: true,
        title: Text('Following', style: AppTextStyles.titleLarge.copyWith()),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, color: AppColors.accent, size: 18),
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: _following.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _following.length,
              itemBuilder: (context, index) {
                final user = _following[index];
                return _buildUserCard(user);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.people_outline, size: 64, color: AppColors.accent),
            ),
            const SizedBox(height: 24),
            Text(
              'Not Following Anyone',
              style: AppTextStyles.titleLarge.copyWith(color: AppColors.onBackground, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Start following users to see their posts',
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
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isVerified = user['isVerified'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          const SizedBox(width: 12),
          // User Info
          Expanded(
            child: GestureDetector(
              onTap: () => _viewProfile(user),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user['name'] ?? '',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      ),
                      if (isVerified) ...[const SizedBox(width: 6), Icon(Icons.verified, size: 16, color: AppColors.accent)],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('@${user['username'] ?? ''}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray)),
                ],
              ),
            ),
          ),
          // Follow/Unfollow Button
          OutlinedButton(
            onPressed: () => _toggleFollow(user['id']),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.primaryGray.withOpacity(0.5), width: 1.5),
              foregroundColor: AppColors.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              minimumSize: const Size(0, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Following',
              style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
