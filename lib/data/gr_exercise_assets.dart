/// Asset paths for bundled GR exercise catalog images.
class GrExerciseAssets {
  GrExerciseAssets._();

  static const String _base = 'assets/gr_json/assets/Categories';

  static String muscleGroupImage(String imageName) => '$_base/$imageName.png';

  static String exerciseImage(String muscleGroupKey, String imageName) {
    final folder = switch (muscleGroupKey) {
      'chest' => 'chestExercises',
      'back' => 'backExercises',
      'arms' => 'armsExercises',
      'legs' => 'legsExercises',
      'core' => 'coreExercises',
      _ => 'chestExercises',
    };
    return '$_base/$folder/$imageName.png';
  }

  static String equipmentImage(String imageName) => '$_base/equipment/$imageName.png';

  static String modalityImage(String imageName) => '$_base/modality/$imageName.png';
}
