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

  Future<dynamic> followUserRepo(String userId) async {
    return _network.post(AppUrl.profileUserFollow(userId), <String, dynamic>{});
  }

  Future<dynamic> unfollowUserRepo(String userId) async {
    return _network.post(AppUrl.profileUserUnfollow(userId), <String, dynamic>{});
  }
}
