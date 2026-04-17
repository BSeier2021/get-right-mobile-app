/// One item from `GET /user/exercise-plan` → `data.exercisePlans[]`.
class ExercisePlanOption {
  /// API value sent as `exerciseFrequency` / exercise plan on profile update (e.g. `Daily`, `FiveTimesaWeek`).
  final String value;
  final String title;
  final String description;

  const ExercisePlanOption({required this.value, required this.title, required this.description});

  factory ExercisePlanOption.fromJson(Map<String, dynamic> json) {
    final title = json['title']?.toString() ?? '';
    final value = (json['value']?.toString().trim().isNotEmpty == true) ? json['value'].toString().trim() : title;
    final desc = json['description']?.toString() ?? '';
    return ExercisePlanOption(value: value, title: title.isNotEmpty ? title : value, description: desc);
  }
}
