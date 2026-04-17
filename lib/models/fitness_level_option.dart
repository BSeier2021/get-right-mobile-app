/// One item from `GET /user/fitness-level` → `data.fitnessLevels[]`.
class FitnessLevelOption {
  /// API value sent as `fitnessLevel` on profile update (e.g. `Beginner`).
  final String value;
  final String title;
  final String description;

  const FitnessLevelOption({required this.value, required this.title, required this.description});

  factory FitnessLevelOption.fromJson(Map<String, dynamic> json) {
    final title = json['title']?.toString() ?? '';
    final value = (json['value']?.toString().trim().isNotEmpty == true) ? json['value'].toString().trim() : title;
    final desc = json['description']?.toString() ?? '';
    return FitnessLevelOption(value: value, title: title.isNotEmpty ? title : value, description: desc);
  }
}
