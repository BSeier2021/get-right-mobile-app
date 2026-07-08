import 'package:get_right/app_url.dart';
import 'package:get_right/models/customer_progress.dart';
import 'package:get_right/network/network_services.dart';

class ProgressRepository {
  final _network = NetworkApiService();

  /// `GET /customer/profile/progress` — summary stats + weekly activity for [startDate]…[endDate].
  Future<CustomerProgress> fetchCustomerProgress({DateTime? startDate, DateTime? endDate}) async {
    final raw = await _network.get(AppUrl.customerProfileProgress(startDate: startDate, endDate: endDate));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load progress');
    }
    return CustomerProgress.fromApiResponse(raw);
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
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
