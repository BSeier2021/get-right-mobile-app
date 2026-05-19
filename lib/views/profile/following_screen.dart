import 'package:flutter/material.dart';
import 'package:get_right/views/profile/user_follow_list_screen.dart';

/// Following list for a user profile.
class FollowingScreen extends StatelessWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UserFollowListScreen(type: UserFollowListType.following);
  }
}
