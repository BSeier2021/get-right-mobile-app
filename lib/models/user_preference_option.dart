import 'package:get_right/utils/customer_profile_enums.dart';

/// One item from `GET /user/preferences` → `data.preferences[]`.
class UserPreferenceOption {
  final String id;
  final String name;
  /// Slug for `POST /customer/profile/update` field `primaryFocus` (not Mongo `_id`).
  final String value;
  final String? description;
  final String? icon;

  const UserPreferenceOption({required this.id, required this.name, required this.value, this.description, this.icon});

  factory UserPreferenceOption.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    final explicit = json['value']?.toString().trim() ?? json['key']?.toString().trim() ?? json['slug']?.toString().trim();
    final fromApi = CustomerProfileEnums.normalizePrimaryFocus(explicit);
    final fromName = CustomerProfileEnums.primaryFocusFromDisplayName(name);
    final value = fromApi ?? fromName ?? 'general_fitness';
    return UserPreferenceOption(
      id: json['_id']?.toString() ?? '',
      name: name,
      value: CustomerProfileEnums.isValidPrimaryFocus(value) ? value : 'general_fitness',
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
    );
  }
}
