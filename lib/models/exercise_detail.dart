import 'package:get_right/utils/image_url_sanitizer.dart';

class ExerciseRecommendations {
  const ExerciseRecommendations({
    this.sets,
    this.reps,
    this.restTimeSeconds,
    this.weight,
  });

  final int? sets;
  final int? reps;
  final int? restTimeSeconds;
  final num? weight;

  factory ExerciseRecommendations.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ExerciseRecommendations();
    return ExerciseRecommendations(
      sets: (json['sets'] as num?)?.toInt(),
      reps: (json['reps'] as num?)?.toInt(),
      restTimeSeconds: (json['restTime'] as num?)?.toInt(),
      weight: json['weight'] as num?,
    );
  }

  String get setsLabel => sets?.toString() ?? '—';
  String get repsLabel => reps?.toString() ?? '—';

  String get restTimeLabel {
    if (restTimeSeconds == null) return '—';
    return '$restTimeSeconds sec';
  }

  String? get weightLabel {
    if (weight == null) return null;
    final w = weight!;
    if (w == w.roundToDouble()) return '${w.toInt()} lbs';
    return '$w lbs';
  }
}

/// Full exercise from `GET /user/exercises/:exerciseId`.
class ExerciseDetail {
  const ExerciseDetail({
    required this.id,
    required this.name,
    this.type,
    this.description,
    this.categoryName,
    this.tagNames = const [],
    this.proTips = const [],
    this.formCues = const [],
    this.targetMuscles = const [],
    this.secondaryMuscles = const [],
    this.recommendations,
    this.thumbnailUrl,
    this.videoThumbnailUrl,
    this.iconUrl,
    this.videoUrl,
    this.durationSeconds,
  });

  final String id;
  final String name;
  final String? type;
  final String? description;
  final String? categoryName;
  final List<String> tagNames;
  final List<String> proTips;
  final List<String> formCues;
  final List<String> targetMuscles;
  final List<String> secondaryMuscles;
  final ExerciseRecommendations? recommendations;
  final String? thumbnailUrl;
  /// HLS preview frame from `video.thumbnail`.
  final String? videoThumbnailUrl;
  final String? iconUrl;
  final String? videoUrl;
  final double? durationSeconds;

  /// Hero / preview: video frame first, then legacy thumbnail, then exercise icon.
  String? get displayImageUrl => videoThumbnailUrl ?? thumbnailUrl ?? iconUrl;

  String get difficultyLabel => type?.trim().isNotEmpty == true ? type!.trim() : '—';

  String get durationLabel {
    final sec = durationSeconds;
    if (sec == null || sec <= 0) return '—';
    if (sec < 60) {
      if (sec == sec.roundToDouble()) return '${sec.round()} sec';
      return '${sec.toStringAsFixed(1)} sec';
    }
    final min = (sec / 60).ceil();
    return '$min min';
  }

  String get categoryLabel => categoryName?.trim().isNotEmpty == true ? categoryName!.trim() : '—';

  String get equipmentLabel {
    if (tagNames.isNotEmpty) return tagNames.first;
    return '—';
  }

  factory ExerciseDetail.fromJson(Map<String, dynamic> json) {
    final category = json['category'];
    String? categoryName;
    if (category is Map) {
      categoryName = Map<String, dynamic>.from(category)['name']?.toString().trim();
    }

    final rec = json['recommendations'];
    final recommendations = rec is Map ? ExerciseRecommendations.fromJson(Map<String, dynamic>.from(rec)) : null;

    final video = json['video'];
    String? videoThumbnailUrl;
    String? videoUrl;
    double? durationSeconds;

    if (video is Map) {
      final vm = Map<String, dynamic>.from(video);
      videoThumbnailUrl = _mediaUrlFrom(vm['thumbnail']);
      videoUrl = ImageUrlSanitizer.resolveMediaUrl(_rawUrlFrom(vm));
      final meta = vm['metadata'];
      if (meta is Map) {
        durationSeconds = (Map<String, dynamic>.from(meta)['duration'] as num?)?.toDouble();
      }
    }

    durationSeconds ??= (json['duration'] as num?)?.toDouble();

    final equipment = _namesFromList(json['equipment']);
    final tags = _namesFromList(json['tags']);

    return ExerciseDetail(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? '',
      type: json['type']?.toString().trim(),
      description: json['description']?.toString().trim(),
      categoryName: categoryName,
      tagNames: tags.isNotEmpty ? tags : equipment,
      proTips: _stringList(json['proTips']),
      formCues: _stringList(json['formCue']),
      targetMuscles: _namesFromList(json['targetMuscle']),
      secondaryMuscles: _namesFromList(json['secondaryMuscle']),
      recommendations: recommendations,
      thumbnailUrl: _mediaUrlFrom(json['thumbnail']),
      videoThumbnailUrl: videoThumbnailUrl,
      iconUrl: _mediaUrlFrom(json['icon']),
      videoUrl: videoUrl,
      durationSeconds: durationSeconds,
    );
  }

  static ExerciseDetail? fromApiResponse(dynamic response) {
    if (response is! Map) return null;
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is! Map) return null;
    final exercise = Map<String, dynamic>.from(data)['exercise'];
    if (exercise is! Map) return null;
    return ExerciseDetail.fromJson(Map<String, dynamic>.from(exercise));
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

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e?.toString().trim() ?? '').where((s) => s.isNotEmpty).toList();
  }

  Map<String, dynamic> toFavoritePayload() => {
        'id': id,
        '_id': id,
        'name': name,
        'type': 'exercise',
        'equipment': equipmentLabel != '—' ? equipmentLabel : '',
        'difficulty': difficultyLabel != '—' ? difficultyLabel : '',
        'image': displayImageUrl ?? '',
        'muscleGroup': categoryLabel != '—' ? categoryLabel : '',
        'isFavorite': false,
      };
}
