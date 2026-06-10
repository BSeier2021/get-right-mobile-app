import 'package:get_right/utils/image_url_sanitizer.dart';

/// One exercise from `GET /user/exercises/category/:categoryId`.
class ExerciseLibraryItem {
  const ExerciseLibraryItem({
    required this.id,
    required this.name,
    this.tagNames = const [],
    this.thumbnailUrl,
    this.videoThumbnailUrl,
    this.iconUrl,
    this.videoUrl,
  });

  final String id;
  final String name;
  final List<String> tagNames;
  final String? thumbnailUrl;
  /// Preview frame from `video.thumbnail`.
  final String? videoThumbnailUrl;
  final String? iconUrl;
  final String? videoUrl;

  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  /// Card hero: video frame first, then legacy thumbnail, then exercise icon.
  String? get displayImageUrl => videoThumbnailUrl ?? thumbnailUrl ?? iconUrl;

  factory ExerciseLibraryItem.fromJson(Map<String, dynamic> json) {
    final tags = _namesFromList(json['tags']);
    final equipment = _namesFromList(json['equipment']);

    final video = json['video'];
    String? videoThumbnailUrl;
    String? videoUrl;
    if (video is Map) {
      final vm = Map<String, dynamic>.from(video);
      videoThumbnailUrl = _mediaUrlFrom(vm['thumbnail']);
      videoUrl = ImageUrlSanitizer.resolveMediaUrl(_rawUrlFrom(vm));
    }

    return ExerciseLibraryItem(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? '',
      tagNames: tags.isNotEmpty ? tags : equipment,
      thumbnailUrl: _mediaUrlFrom(json['thumbnail']),
      videoThumbnailUrl: videoThumbnailUrl,
      iconUrl: _mediaUrlFrom(json['icon']),
      videoUrl: videoUrl,
    );
  }

  static String? _rawUrlFrom(dynamic media) {
    if (media is! Map) return null;
    return Map<String, dynamic>.from(media)['url']?.toString();
  }

  static String? _mediaUrlFrom(dynamic media) {
    return ImageUrlSanitizer.resolveMediaUrl(_rawUrlFrom(media));
  }

  static List<String> _namesFromList(dynamic raw) {
    if (raw is! List) return [];
    final out = <String>[];
    for (final item in raw) {
      if (item is Map) {
        final name = Map<String, dynamic>.from(item)['name']?.toString().trim();
        if (name != null && name.isNotEmpty) out.add(name);
      } else if (item is String && item.trim().isNotEmpty) {
        out.add(item.trim());
      }
    }
    return out;
  }

  Map<String, dynamic> toRouteArgs({required String muscleGroupName}) => {
        'id': id,
        '_id': id,
        'name': name,
        'equipment': tagNames.isNotEmpty ? tagNames.first : '',
        'tags': tagNames,
        'difficulty': '',
        'image': displayImageUrl ?? '',
        'muscleGroup': muscleGroupName,
        'isFavorite': false,
        'fromLibrary': true,
      };
}

class ExercisesByCategoryPage {
  const ExercisesByCategoryPage({
    required this.exercises,
    required this.total,
    required this.page,
    required this.hasMore,
  });

  final List<ExerciseLibraryItem> exercises;
  final int total;
  final int page;
  final bool hasMore;
}
