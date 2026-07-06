class CustomerProgressSummary {
  const CustomerProgressSummary({
    required this.totalWorkouts,
    required this.workoutsThisWeek,
    required this.totalDistanceKm,
    required this.activeDays,
  });

  final int totalWorkouts;
  final int workoutsThisWeek;
  final double totalDistanceKm;
  final int activeDays;

  factory CustomerProgressSummary.fromJson(Map<String, dynamic> json) {
    return CustomerProgressSummary(
      totalWorkouts: _toInt(json['totalWorkouts']),
      workoutsThisWeek: _toInt(json['workoutsThisWeek']),
      totalDistanceKm: _toDouble(json['totalDistanceKm']),
      activeDays: _toInt(json['activeDays']),
    );
  }

  static const empty = CustomerProgressSummary(
    totalWorkouts: 0,
    workoutsThisWeek: 0,
    totalDistanceKm: 0,
    activeDays: 0,
  );
}

class WeeklyActivityDay {
  const WeeklyActivityDay({
    required this.day,
    required this.date,
    required this.minutes,
    required this.workouts,
  });

  final String day;
  final String date;
  final int minutes;
  final int workouts;

  factory WeeklyActivityDay.fromJson(Map<String, dynamic> json) {
    return WeeklyActivityDay(
      day: json['day']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      minutes: _toInt(json['minutes']),
      workouts: _toInt(json['workouts']),
    );
  }
}

class CustomerProgress {
  const CustomerProgress({
    required this.summary,
    required this.weeklyActivity,
  });

  final CustomerProgressSummary summary;
  final List<WeeklyActivityDay> weeklyActivity;

  factory CustomerProgress.fromApiResponse(dynamic raw) {
    final payload = _unwrapPayload(raw);
    if (payload == null) {
      return const CustomerProgress(summary: CustomerProgressSummary.empty, weeklyActivity: []);
    }
    return CustomerProgress.fromJson(payload);
  }

  factory CustomerProgress.fromJson(Map<String, dynamic> json) {
    final summaryRaw = json['summary'];
    final summary = summaryRaw is Map
        ? CustomerProgressSummary.fromJson(Map<String, dynamic>.from(summaryRaw))
        : CustomerProgressSummary.empty;

    final activityRaw = json['weeklyActivity'];
    final activity = <WeeklyActivityDay>[];
    if (activityRaw is List) {
      for (final item in activityRaw) {
        if (item is Map) {
          activity.add(WeeklyActivityDay.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return CustomerProgress(summary: summary, weeklyActivity: activity);
  }

  static Map<String, dynamic>? _unwrapPayload(dynamic raw) {
    if (raw is! Map) return null;
    final root = Map<String, dynamic>.from(raw);
    if (root['summary'] is Map || root['weeklyActivity'] is List) {
      return root;
    }
    final data = root['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }
}

int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString()) ?? 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}
