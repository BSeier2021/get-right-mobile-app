import 'package:get_right/app_url.dart';
import 'package:get_right/models/discover_user.dart';
import 'package:get_right/network/network_services.dart';

class DiscoverRepository {
  final _network = NetworkApiService();

  /// `GET /user/discover` — search users with sort, role, pagination.
  Future<DiscoverUsersPage> fetchDiscoverUsers({
    String? search,
    String? role,
    DiscoverSort sort = DiscoverSort.newest,
    int page = 1,
    int limit = 20,
  }) async {
    final raw = await _network.get(
      AppUrl.usersDiscover(
        search: search,
        role: role,
        sort: sort.apiValue,
        page: page,
        limit: limit,
      ),
    );
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load discover users');
    }
    return DiscoverUsersPage.fromApiResponse(raw);
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
    if (m['users'] is List) return true;
    final data = m['data'];
    if (data is Map && data['users'] is List) return true;
    final st = m['status'];
    return st == 200 || st == '200' || st == 201 || st == '201';
  }

  static String? _messageFrom(dynamic response) {
    if (response is! Map) return null;
    final message = Map<String, dynamic>.from(response)['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    return null;
  }
}
