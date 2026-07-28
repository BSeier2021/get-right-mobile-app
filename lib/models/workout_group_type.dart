enum WorkoutGroupType {
  single,
  superset,
  circuit;

  String get label => switch (this) {
        WorkoutGroupType.single => 'Regular Exercise',
        WorkoutGroupType.superset => 'Superset',
        WorkoutGroupType.circuit => 'Circuit',
      };

  String get subtitle => switch (this) {
        WorkoutGroupType.single => 'Add as the next exercise.',
        WorkoutGroupType.superset => 'Pair this exercise with another for a superset.',
        WorkoutGroupType.circuit => 'Add 3+ exercises to create a circuit.',
      };

  int get minExercises => switch (this) {
        WorkoutGroupType.single => 1,
        WorkoutGroupType.superset => 2,
        WorkoutGroupType.circuit => 3,
      };

  bool get isGrouped => this != WorkoutGroupType.single;

  static WorkoutGroupType? fromArgs(dynamic raw) {
    final value = raw?.toString().trim().toLowerCase();
    return switch (value) {
      'single' || 'regular' => WorkoutGroupType.single,
      'superset' => WorkoutGroupType.superset,
      'circuit' || 'giantset' || 'giant_set' || 'giant-set' => WorkoutGroupType.circuit,
      _ => null,
    };
  }

  String get apiValue => switch (this) {
        WorkoutGroupType.single => 'single',
        WorkoutGroupType.superset => 'superset',
        WorkoutGroupType.circuit => 'circuit',
      };
}
