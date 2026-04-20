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
      'running & cardio': 'running_cardio',
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

  /// UI labels for primary-focus dropdown (same order as [primaryFocusDisplayOptions]).
  static const List<String> primaryFocusDisplayOptions = [
    'Strength Training',
    'Running & Cardio',
    'Flexibility',
    'Weight Loss',
    'General Fitness',
  ];

  static String primaryFocusDisplayForSlug(String slug) {
    const inv = <String, String>{
      'strength_training': 'Strength Training',
      'running_cardio': 'Running & Cardio',
      'flexibility': 'Flexibility',
      'weight_loss': 'Weight Loss',
      'general_fitness': 'General Fitness',
    };
    return inv[slug.trim()] ?? slug;
  }

  static String mainGoalDisplayForSlug(String slug) {
    const inv = <String, String>{
      'lose_weight': 'Lose Weight',
      'build_muscle': 'Build Muscle',
      'stay_healthy': 'Stay Healthy',
      'improve_performance': 'Improve Performance',
      'track_progress': 'Track Progress',
      'build_habits': 'Build Habits',
    };
    return inv[slug.trim()] ?? slug;
  }

  /// Edit-profile exercise dropdown label → API `exerciseFrequency` value.
  static const Map<String, String> exerciseFrequencyDisplayToApi = {
    'Daily (7x/week)': 'Daily',
    '5 times per week': 'FiveTimesaWeek',
    '3 times per week': 'ThreeTimesaWeek',
    '2 times per week': 'TwoTimesaWeek',
    'Once per week': 'OnceAWeek',
  };

  static final Map<String, String> _exerciseApiToDisplay = {
    for (final e in exerciseFrequencyDisplayToApi.entries) e.value: e.key,
  };

  /// Returns API slug (e.g. `FiveTimesaWeek`) from dropdown label, or the same string if already an API value.
  static String? exerciseFrequencyApiFromDisplay(String? display) {
    if (display == null) return null;
    final t = display.trim();
    if (t.isEmpty) return null;
    final mapped = exerciseFrequencyDisplayToApi[t];
    if (mapped != null) return mapped;
    if (_exerciseApiToDisplay.containsKey(t)) return t;
    return null;
  }

  static String exerciseFrequencyDisplayFromApi(String? api) {
    if (api == null) return '';
    final k = api.trim();
    if (k.isEmpty) return '';
    return _exerciseApiToDisplay[k] ?? k;
  }
}
