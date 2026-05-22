import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';

class WorkoutRepository {
  final _network = NetworkApiService();

  /// `POST /customer/workout` — add exercise to a workout journal.
  Future<Map<String, dynamic>> createWorkout(Map<String, dynamic> body) async {
    final raw = await _network.post(AppUrl.customerWorkout, body);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not save workout');
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  static String? createdWorkoutId(dynamic response) {
    if (response is! Map) return null;
    final data = Map<String, dynamic>.from(response)['data'];
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);
    final workout = m['workout'];
    if (workout is Map) {
      final wm = Map<String, dynamic>.from(workout);
      return wm['_id']?.toString() ?? wm['id']?.toString();
    }
    return m['_id']?.toString() ?? m['id']?.toString();
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
    final st = m['status'];
    return st == 200 || st == '200';
  }

  static String? _messageFrom(dynamic response) {
    if (response is! Map) return null;
    final m = Map<String, dynamic>.from(response);
    return m['message']?.toString();
  }
}
