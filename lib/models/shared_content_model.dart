/// Shareable content types for chat messages (`POST /user/chat/conversations/:id/messages`).
enum SharedContentType {
  feed('feed'),
  workoutJournal('workout_journal'),
  runningLog('running_log'),
  recipe('recipe'),
  foodSave('food_save');

  const SharedContentType(this.apiValue);

  final String apiValue;

  static SharedContentType? fromApi(String? raw) {
    final normalized = raw?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final type in SharedContentType.values) {
      if (type.apiValue == normalized) return type;
    }
    return null;
  }
}

class SharedContentPayload {
  const SharedContentPayload({required this.type, required this.id});

  final SharedContentType type;
  final String id;

  Map<String, dynamic> toJson() => {'type': type.apiValue, 'id': id.trim()};
}
