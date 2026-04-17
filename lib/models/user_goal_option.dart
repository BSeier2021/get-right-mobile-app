import 'package:get_right/utils/customer_profile_enums.dart';

/// One item from `GET /user/goals` → `data.goals[]`.
class UserGoalOption {
  final String id;
  final String name;
  /// Slug for `POST /customer/profile/update` field `mainGoals[]` (not Mongo `_id`).
  final String value;
  final String? icon;

  const UserGoalOption({required this.id, required this.name, required this.value, this.icon});

  factory UserGoalOption.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final explicit = json['value']?.toString().trim() ?? json['key']?.toString().trim() ?? json['slug']?.toString().trim();
    final fromApi = CustomerProfileEnums.normalizeMainGoal(explicit);
    final fromName = CustomerProfileEnums.mainGoalFromDisplayName(name);
    final value = fromApi ?? fromName ?? 'stay_healthy';
    return UserGoalOption(
      id: json['_id']?.toString() ?? '',
      name: name,
      value: CustomerProfileEnums.isValidMainGoal(value) ? value : 'stay_healthy',
      icon: json['icon']?.toString(),
    );
  }
}
