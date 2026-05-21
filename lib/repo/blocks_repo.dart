import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';

/// Block / unblock users and list blocked users.
class BlocksRepository {
  final NetworkApiService _network = NetworkApiService();

  /// `GET /user/block?page=&limit=` — `data.blocked.blocked[]`.
  Future<dynamic> getBlockedUsersRepo({required int page, required int limit}) async {
    return _network.get(AppUrl.userBlocks, params: <String, dynamic>{'page': page, 'limit': limit});
  }

  /// `POST /user/block/:userId`
  Future<dynamic> blockUserRepo(String userId) async {
    return _network.post(AppUrl.userBlock(userId), <String, dynamic>{});
  }

  /// `DELETE /user/block/:userId`
  Future<dynamic> unblockUserRepo(String userId) async {
    return _network.delete(AppUrl.userBlock(userId));
  }
}
