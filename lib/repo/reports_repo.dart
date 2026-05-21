import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';

/// Current user's submitted reports (`GET /user/report`).
class ReportsRepository {
  final NetworkApiService _network = NetworkApiService();

  Future<dynamic> getReportsRepo({int page = 1, int limit = 50}) async {
    return _network.get(AppUrl.userReports, params: {'page': page, 'limit': limit});
  }
}
