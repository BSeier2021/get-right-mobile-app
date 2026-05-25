/// Warmup vs main workout section for journal exercises (`POST /customer/workout` `type` field).
enum JournalExerciseType {
  warmup('Warmup'),
  workout('Workout');

  const JournalExerciseType(this.apiValue);

  final String apiValue;

  bool get isWarmup => this == JournalExerciseType.warmup;

  static JournalExerciseType fromIsWarmup(bool isWarmup) =>
      isWarmup ? JournalExerciseType.warmup : JournalExerciseType.workout;

  static JournalExerciseType? fromArgs(Map<String, dynamic>? args) {
    if (args == null) return null;
    final raw = args['exerciseType'];
    if (raw is JournalExerciseType) return raw;
    if (raw is String) return fromApi(raw);
    if (args['isWarmup'] != null) return fromIsWarmup(args['isWarmup'] == true);
    return null;
  }

  static JournalExerciseType? fromApi(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final type in JournalExerciseType.values) {
      if (type.apiValue.toLowerCase() == normalized || type.name.toLowerCase() == normalized) {
        return type;
      }
    }
    return null;
  }
}
