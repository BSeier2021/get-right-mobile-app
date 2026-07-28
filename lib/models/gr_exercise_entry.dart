import 'package:get_right/data/gr_exercise_assets.dart';
import 'package:get_right/models/exercise_library_model.dart';

/// One exercise from the bundled GR `ExerciseList.json` catalog.
class GrExerciseEntry {
  const GrExerciseEntry({
    required this.id,
    required this.name,
    required this.muscleGroupKey,
    required this.imageName,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.movementType,
    this.modality,
    this.experienceLevel,
    this.tags = const [],
    this.description,
    this.setup,
    this.instructions = const [],
    this.formCues = const [],
    this.repRange,
    this.equipment = const [],
  });

  final String id;
  final String name;
  final String muscleGroupKey;
  final String imageName;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String? movementType;
  final String? modality;
  final String? experienceLevel;
  final List<String> tags;
  final String? description;
  final String? setup;
  final List<String> instructions;
  final List<String> formCues;
  final String? repRange;
  final List<String> equipment;

  String get imageAssetPath => GrExerciseAssets.exerciseImage(muscleGroupKey, imageName);

  String get primaryMuscleLabel => primaryMuscles.isNotEmpty ? primaryMuscles.first : muscleGroupKey;

  String? get equipmentLabel => equipment.isNotEmpty ? equipment.join(', ') : null;

  factory GrExerciseEntry.fromJson(Map<String, dynamic> json, {required String muscleGroupKey}) {
    return GrExerciseEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString().trim() ?? '',
      muscleGroupKey: muscleGroupKey,
      imageName: json['imageName']?.toString() ?? json['id']?.toString() ?? '',
      primaryMuscles: _stringList(json['primaryMuscles']),
      secondaryMuscles: _stringList(json['secondaryMuscles']),
      movementType: json['movementType']?.toString(),
      modality: json['modality']?.toString(),
      experienceLevel: json['experienceLevel']?.toString(),
      tags: _stringList(json['tags']),
      description: json['description']?.toString(),
      setup: json['setup']?.toString(),
      instructions: _instructionList(json),
      formCues: _stringList(json['formCues']),
      repRange: json['repRange']?.toString(),
      equipment: _stringList(json['equipment']),
    );
  }

  ExerciseLibraryModel toExerciseLibraryModel() {
    return ExerciseLibraryModel(
      id: id,
      name: name,
      primaryMuscle: primaryMuscleLabel,
      secondaryMuscle: secondaryMuscles.isNotEmpty ? secondaryMuscles.join(', ') : null,
      difficulty: _titleCase(experienceLevel ?? 'intermediate'),
      equipmentRequired: equipmentLabel,
      instructions: instructions.isNotEmpty ? instructions : (formCues.isNotEmpty ? formCues : const []),
      tips: formCues,
      iconUrl: imageAssetPath,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e?.toString().trim() ?? '').where((s) => s.isNotEmpty).toList();
  }

  static List<String> _instructionList(Map<String, dynamic> json) {
    final instructions = _stringList(json['instructions']);
    if (instructions.isNotEmpty) return instructions;
    final single = json['instructions']?.toString().trim();
    if (single != null && single.isNotEmpty) return [single];
    return const [];
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
