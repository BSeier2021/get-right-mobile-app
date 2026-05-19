import 'package:flutter/material.dart';
import 'package:get_right/views/profile/user_follow_list_screen.dart';

/// Followers list for a user profile.
class FollowersScreen extends StatelessWidget {
  const FollowersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserFollowListScreen(type: UserFollowListType.followers);
  }
}
