/// Allowed values for `POST /customer/profile/update` (backend validation).
abstract final class CustomerProfileEnums {
  static const Set<String> primaryFocusValues = {
    'strength_training',
    'running_cardio',
    'flexibility',
    'weight_loss',
    'general_fitness',
  };

  static const Set<String> mainGoalValues = {
    'lose_weight',
    'build_muscle',
    'stay_healthy',
    'improve_performance',
    'track_progress',
    'build_habits',
  };

  static bool isValidPrimaryFocus(String? v) {
    if (v == null) return false;
    return primaryFocusValues.contains(v.trim());
  }

  static bool isValidMainGoal(String? v) {
    if (v == null) return false;
    return mainGoalValues.contains(v.trim());
  }

  /// Maps display labels from UI / API `name` to [primaryFocusValues].
  static String? primaryFocusFromDisplayName(String? name) {
    if (name == null) return null;
    final key = name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    const map = <String, String>{
      'strength training': 'strength_training',
      'strength': 'strength_training',
      'muscle building': 'strength_training',
      'hypertrophy': 'strength_training',
      'running / cardio': 'running_cardio',
      'running cardio': 'running_cardio',
      'running': 'running_cardio',
      'cardio': 'running_cardio',
      'hiit': 'running_cardio',
      'flexibility': 'flexibility',
      'stretching': 'flexibility',
      'mobility': 'flexibility',
      'weight loss': 'weight_loss',
      'fat loss': 'weight_loss',
      'general fitness': 'general_fitness',
      'general': 'general_fitness',
      'wellness': 'general_fitness',
    };
    return map[key];
  }

  /// Maps display labels to [mainGoalValues].
  static String? mainGoalFromDisplayName(String? name) {
    if (name == null) return null;
    final key = name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    const map = <String, String>{
      'lose weight': 'lose_weight',
      'weight loss': 'lose_weight',
      'weight management': 'lose_weight',
      'build muscle': 'build_muscle',
      'muscle gain': 'build_muscle',
      'stay healthy': 'stay_healthy',
      'improve performance': 'improve_performance',
      'track progress': 'track_progress',
      'build habits': 'build_habits',
    };
    return map[key];
  }

  /// Returns a valid primary-focus slug, or null.
  static String? normalizePrimaryFocus(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (isValidPrimaryFocus(s)) return s;
    return primaryFocusFromDisplayName(s);
  }

  /// Returns a valid main-goal slug, or null.
  static String? normalizeMainGoal(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (isValidMainGoal(s)) return s;
    return mainGoalFromDisplayName(s);
  }

  static List<String> filterMainGoals(Iterable<String?> candidates) {
    final out = <String>[];
    for (final c in candidates) {
      final v = normalizeMainGoal(c);
      if (v != null && !out.contains(v)) out.add(v);
    }
    return out;
  }
}
