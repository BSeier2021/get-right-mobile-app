import 'package:get_right/utils/image_url_sanitizer.dart';

/// One category from `GET /user/exercise-categories` (library grid).
class ExerciseLibraryCategory {
  const ExerciseLibraryCategory({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.totalExercises = 0,
  });

  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final int totalExercises;

  factory ExerciseLibraryCategory.fromJson(Map<String, dynamic> json) {
    String? iconUrl;
    final icon = json['icon'];
    if (icon is Map) {
      iconUrl = ImageUrlSanitizer.asHttpUrlOrNull(Map<String, dynamic>.from(icon)['url']?.toString());
    }

    return ExerciseLibraryCategory(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? '',
      description: json['description']?.toString().trim(),
      iconUrl: iconUrl,
      totalExercises: (json['totalExercises'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toRouteArgs() => {
        'id': id,
        '_id': id,
        'name': name,
        'exerciseCount': totalExercises,
        if (iconUrl != null) 'imageUrl': iconUrl,
        if (description != null) 'description': description,
      };
}

class ExerciseCategoriesPage {
  const ExerciseCategoriesPage({
    required this.categories,
    required this.total,
    required this.page,
    required this.hasMore,
  });

  final List<ExerciseLibraryCategory> categories;
  final int total;
  final int page;
  final bool hasMore;
}
