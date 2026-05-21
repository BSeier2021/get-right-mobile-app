/// One item from `GET /user/exercise-categories`.
class ExerciseCategoryOption {
  final String id;
  final String name;

  const ExerciseCategoryOption({required this.id, required this.name});

  factory ExerciseCategoryOption.fromJson(Map<String, dynamic> json) {
    return ExerciseCategoryOption(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? json['title']?.toString().trim() ?? '',
    );
  }
}
