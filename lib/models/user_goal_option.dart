/// One item from `GET /user/goals` → `data.goals[]`.
class UserGoalOption {
  final String id;
  final String name;
  final String? icon;

  const UserGoalOption({required this.id, required this.name, this.icon});

  factory UserGoalOption.fromJson(Map<String, dynamic> json) {
    return UserGoalOption(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      icon: json['icon']?.toString(),
    );
  }
}
