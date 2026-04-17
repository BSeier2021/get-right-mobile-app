/// One item from `GET /user/preferences` → `data.preferences[]`.
class UserPreferenceOption {
  final String id;
  final String name;
  final String? description;
  final String? icon;

  const UserPreferenceOption({required this.id, required this.name, this.description, this.icon});

  factory UserPreferenceOption.fromJson(Map<String, dynamic> json) {
    return UserPreferenceOption(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      icon: json['icon']?.toString(),
    );
  }
}
