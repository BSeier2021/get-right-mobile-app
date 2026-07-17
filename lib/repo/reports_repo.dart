import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';

/// Current user's submitted reports (`GET /user/report`).
class ReportsRepository {
  final NetworkApiService _network = NetworkApiService();

  /// Query: `page`, `limit`, optional `type` (`ReportRefTypeEnums`), optional `status` (`UserReportStatusEnums`).
  Future<dynamic> getReportsRepo({
    int page = 1,
    int limit = 20,
    String? type,
    String? status,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    final refType = type?.trim();
    if (refType != null && refType.isNotEmpty) params['type'] = refType;
    final reportStatus = status?.trim();
    if (reportStatus != null && reportStatus.isNotEmpty) params['status'] = reportStatus;
    return _network.get(AppUrl.userReports, params: params);
  }
}
