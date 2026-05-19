import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';

/// Public trainer profile: details, posts, programs, bundles, follow.
class TrainerProfileRepository {
  final NetworkApiService _network = NetworkApiService();

  Future<dynamic> getProfileDetailsRepo(String userId) async {
    return _network.get(AppUrl.profileUserDetails(userId));
  }

  Future<dynamic> getProfilePostsRepo(String userId, {int page = 1, int limit = 30}) async {
    return _network.get(AppUrl.profileUserPosts(userId), params: {'page': page, 'limit': limit});
  }

  Future<dynamic> getProfileProgramsRepo(String userId, {int page = 1, int limit = 50}) async {
    return _network.get(AppUrl.profileUserPrograms(userId), params: {'page': page, 'limit': limit});
  }

  Future<dynamic> getProfileBundlesRepo(String userId, {int page = 1, int limit = 50}) async {
    return _network.get(AppUrl.profileUserBundles(userId), params: {'page': page, 'limit': limit});
  }

  /// `POST /user/follow/:userId` → `data.isFollowing` (true).
  Future<bool> followUserRepo(String userId) async {
    final raw = await _network.post(AppUrl.userFollow(userId), <String, dynamic>{});
    return _parseIsFollowing(raw, expected: true);
  }

  /// `DELETE /user/follow/:userId` → `data.isFollowing` (false).
  Future<bool> unfollowUserRepo(String userId) async {
    final raw = await _network.delete(AppUrl.userFollow(userId));
    return _parseIsFollowing(raw, expected: false);
  }

  bool _parseIsFollowing(dynamic raw, {required bool expected}) {
    if (raw is Map) {
      final data = raw['data'];
      if (data is Map) {
        final v = data['isFollowing'];
        if (v is bool) return v;
      }
    }
    return expected;
  }
}
