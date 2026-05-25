import 'package:get_right/app_url.dart';
import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/models/journal_exercise_type.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/models/workout_journal_model.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

class WorkoutJournalListPage {
  const WorkoutJournalListPage({
    required this.entries,
    required this.page,
    required this.limit,
    this.syncFailed = false,
    this.syncError,
  });

  final List<WorkoutJournalModel> entries;
  final int page;
  final int limit;

  /// True when the list API failed (e.g. backend populate error) — caller may keep local state.
  final bool syncFailed;
  final String? syncError;
}

class WorkoutRepository {
  final _network = NetworkApiService();

  static final RegExp _mongoIdRe = RegExp(r'^[a-fA-F0-9]{24}$');

  static bool isValidMongoId(String? id) {
    final trimmed = id?.trim();
    return trimmed != null && trimmed.isNotEmpty && _mongoIdRe.hasMatch(trimmed);
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Resolves a workout journal id from API responses (`data`, nested `workoutJournal`, list `data[]`, etc.).
  static String? journalIdFrom(dynamic response) {
    if (response is! Map) return null;
    final root = Map<String, dynamic>.from(response);

    final direct = _mongoId(root['_id'] ?? root['id']);
    if (direct != null) return direct;

    final data = root['data'];
    if (data is List) {
      for (final item in data) {
        if (item is Map) {
          final id = _mongoId(Map<String, dynamic>.from(item)['_id'] ?? Map<String, dynamic>.from(item)['id']);
          if (id != null) return id;
        }
      }
    }

    if (data is Map) {
      final dm = Map<String, dynamic>.from(data);
      final fromData = _mongoId(dm['_id'] ?? dm['id']);
      if (fromData != null) return fromData;

      final workoutJournalRef = dm['workoutJournal'];
      if (workoutJournalRef is String) {
        final fromString = _mongoId(workoutJournalRef);
        if (fromString != null) return fromString;
      }

      for (final key in ['workoutJournal', 'journal', 'workout', 'result']) {
        final nested = dm[key];
        if (nested is Map) {
          final nm = Map<String, dynamic>.from(nested);
          final nestedId = _mongoId(nm['_id'] ?? nm['id']);
          if (nestedId != null) return nestedId;
        }
      }

      for (final key in ['workoutJournalId', 'journalId']) {
        final id = _mongoId(dm[key]);
        if (id != null) return id;
      }
    }

    return null;
  }

  static String? _mongoId(dynamic raw) {
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final oid = m[r'$oid'] ?? m['oid'];
      if (oid != null) return _mongoId(oid);
    }
    final id = raw?.toString().trim();
    if (id == null || id.isEmpty || !_mongoIdRe.hasMatch(id)) return null;
    return id;
  }

  /// `GET /customer/workout-journal?page=&limit=&dateFrom=` → journal entry list.
  ///
  /// Returns an empty page with [WorkoutJournalListPage.syncFailed] when the server
  /// responds with 5xx (e.g. invalid Mongoose populate on `workout.refExercise.thumbnail`).
  Future<WorkoutJournalListPage> fetchWorkoutJournalEntries({
    int page = 1,
    int limit = 10,
    DateTime? dateFrom,
  }) async {
    final fromKey = _dateKey(dateFrom ?? DateTime.now());
    try {
      final raw = await _network.get(AppUrl.customerWorkoutJournalList(page: page, limit: limit, dateFrom: fromKey));
      if (!_isOk(raw)) {
        throw Exception(_messageFrom(raw) ?? 'Could not load workout journal');
      }

      final entries = <WorkoutJournalModel>[];
      if (raw is Map) {
        final data = raw['data'];
        if (data is List) {
          for (final item in data) {
            if (item is Map) {
              entries.add(journalFromApiEntry(Map<String, dynamic>.from(item)));
            }
          }
        }
      }

      return WorkoutJournalListPage(entries: entries, page: page, limit: limit);
    } on ServerException catch (e) {
      return WorkoutJournalListPage(entries: [], page: page, limit: limit, syncFailed: true, syncError: e.message);
    }
  }

  /// Maps one journal list item from `GET /customer/workout-journal`.
  static WorkoutJournalModel journalFromApiEntry(Map<String, dynamic> entry) {
    final id = entry['_id']?.toString() ?? '';
    final date = DateTime.tryParse(entry['date']?.toString() ?? '') ?? DateTime.now();
    final createdAt = DateTime.tryParse(entry['createdAt']?.toString() ?? '') ?? date;
    final updatedAt = DateTime.tryParse(entry['updatedAt']?.toString() ?? '');
    final duration = (entry['duration'] as num?)?.toInt();
    final notes = entry['notes']?.toString();
    final journalType = entry['type']?.toString();

    final warmupExercises = <WorkoutExerciseModel>[];
    final workoutExercises = <WorkoutExerciseModel>[];
    final workoutItems = entry['workout'];
    if (workoutItems is List) {
      for (final item in workoutItems) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final exercise = workoutExerciseFromApi(map);
        final type = map['type']?.toString() ?? journalType;
        if (JournalExerciseType.fromApi(type)?.isWarmup == true) {
          warmupExercises.add(exercise);
        } else {
          workoutExercises.add(exercise);
        }
      }
    }

    return WorkoutJournalModel(
      id: id,
      userId: entry['customer']?.toString() ?? '',
      date: date,
      warmupExercises: warmupExercises,
      workoutExercises: workoutExercises,
      createdAt: createdAt,
      updatedAt: updatedAt,
      durationSeconds: duration,
      notes: notes,
    );
  }

  static String _refExerciseId(dynamic refExercise) {
    if (refExercise is Map) {
      final m = Map<String, dynamic>.from(refExercise);
      return m['_id']?.toString() ?? m['id']?.toString() ?? '';
    }
    return refExercise?.toString() ?? '';
  }

  static String? _refExerciseIconUrl(dynamic refExercise) {
    if (refExercise is! Map) return null;
    final icon = Map<String, dynamic>.from(refExercise)['icon'];
    if (icon is! Map) return null;
    return ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(icon)['url']?.toString());
  }

  static WorkoutExerciseModel workoutExerciseFromApi(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final refRaw = json['refExercise'];
    final refExercise = _refExerciseId(refRaw);
    var name = json['name']?.toString() ?? '';
    if (name.isEmpty && refRaw is Map) {
      name = Map<String, dynamic>.from(refRaw)['name']?.toString() ?? '';
    }
    final supersetId = json['supersetIdentifier']?.toString();
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now();
    final updatedAt = DateTime.tryParse(json['updatedAt']?.toString() ?? '');

    final sets = <ExerciseSetModel>[];
    final setsRaw = json['exercise'];
    if (setsRaw is List) {
      for (var i = 0; i < setsRaw.length; i++) {
        final raw = setsRaw[i];
        if (raw is! Map) continue;
        sets.add(_exerciseSetFromApi(Map<String, dynamic>.from(raw), i));
      }
    }

    return WorkoutExerciseModel(
      id: id,
      exerciseName: name,
      exerciseId: refExercise,
      iconUrl: _refExerciseIconUrl(refRaw),
      sets: sets,
      isSuperset: supersetId != null && supersetId.isNotEmpty,
      supersetId: supersetId,
      date: createdAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static ExerciseSetModel _exerciseSetFromApi(Map<String, dynamic> sm, int fallbackIndex) {
    final repsRaw = sm['reps'];
    String? repsType;
    int? reps;
    int? timeSeconds;

    if (repsRaw == 'FAILURE') {
      repsType = 'FAILURE';
    } else if (repsRaw == 'AMRAP') {
      repsType = 'AMRAP';
    } else if (repsRaw is num) {
      if (repsRaw > 1000) {
        timeSeconds = repsRaw.toInt();
      } else {
        reps = repsRaw.toInt();
      }
    } else {
      final parsed = int.tryParse(repsRaw?.toString() ?? '');
      if (parsed != null && parsed > 1000) {
        timeSeconds = parsed;
      } else {
        reps = parsed;
      }
    }

    double? weight;
    final w = sm['weight'];
    if (w != null) weight = double.tryParse(w.toString());

    return ExerciseSetModel(
      id: sm['_id']?.toString() ?? 'set_$fallbackIndex',
      setNumber: (sm['sets'] as num?)?.toInt() ?? (fallbackIndex + 1),
      reps: reps,
      repsType: repsType,
      timeSeconds: timeSeconds,
      weight: weight,
    );
  }

  /// Merges all journal entries for [day] (default today) into one model for the UI.
  static WorkoutJournalModel? todayEntryFrom(WorkoutJournalListPage page, {DateTime? day}) {
    final target = day ?? DateTime.now();
    final matching = page.entries.where((e) => _isSameDay(e.date, target)).toList();
    if (matching.isEmpty) {
      return page.entries.isNotEmpty ? _mergeJournalEntries(page.entries) : null;
    }
    return _mergeJournalEntries(matching);
  }

  static WorkoutJournalModel _mergeJournalEntries(List<WorkoutJournalModel> entries) {
    final sorted = List<WorkoutJournalModel>.from(entries)..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final warmupExercises = <WorkoutExerciseModel>[];
    final workoutExercises = <WorkoutExerciseModel>[];
    var totalDuration = 0;
    final notesParts = <String>[];

    for (final entry in sorted) {
      warmupExercises.addAll(entry.warmupExercises);
      workoutExercises.addAll(entry.workoutExercises);
      totalDuration += entry.durationSeconds ?? 0;
      final note = entry.notes?.trim();
      if (note != null && note.isNotEmpty) notesParts.add(note);
    }

    final earliest = sorted.first;
    final latest = sorted.last;

    return WorkoutJournalModel(
      id: latest.id,
      userId: latest.userId,
      date: latest.date,
      warmupExercises: warmupExercises,
      workoutExercises: workoutExercises,
      createdAt: earliest.createdAt,
      updatedAt: latest.updatedAt,
      durationSeconds: totalDuration > 0 ? totalDuration : latest.durationSeconds,
      notes: notesParts.isEmpty ? null : notesParts.join('\n'),
    );
  }

  /// Builds `POST /customer/workout-journal` body (all of `workout`, `duration`, `notes` are required).
  static Map<String, dynamic> createJournalBody({
    required String date,
    List<String> workout = const [],
    int duration = 0,
    String notes = '',
    String? type,
  }) {
    return {
      'date': date,
      if (type != null && type.isNotEmpty) 'type': type,
      'workout': workout,
      'duration': duration,
      'notes': notes,
    };
  }

  /// Finds today's journal id via list API; creates one via POST when missing.
  Future<String> getOrCreateWorkoutJournalId({DateTime? date}) async {
    final day = date ?? DateTime.now();
    final dateKey = _dateKey(day);

    try {
      final page = await fetchWorkoutJournalEntries(dateFrom: day);
      final today = todayEntryFrom(page, day: day);
      if (today != null && isValidMongoId(today.id)) return today.id;
    } catch (_) {
      // Fall through to POST when list fails or is empty.
    }

    final postRaw = await _network.post(
      AppUrl.customerWorkoutJournalCreate,
      createJournalBody(date: dateKey, type: JournalExerciseType.workout.apiValue),
    );
    if (!_isOk(postRaw)) {
      throw Exception(_messageFrom(postRaw) ?? 'Could not create workout journal');
    }

    final fromPost = journalIdFrom(postRaw);
    if (fromPost != null) return fromPost;

    throw Exception('Workout journal id missing from server response');
  }

  /// Saves/completes a workout journal session (`POST /customer/workout-journal`).
  Future<Map<String, dynamic>> submitWorkoutJournal({
    required String date,
    required List<String> workoutIds,
    required int duration,
    required String notes,
    String type = 'Workout',
  }) async {
    final raw = await _network.post(
      AppUrl.customerWorkoutJournalCreate,
      createJournalBody(date: date, workout: workoutIds, duration: duration, notes: notes, type: type),
    );
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not save workout journal');
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  /// Builds `POST /customer/workout` body — `type` is `Warmup` or `Workout` from [JournalExerciseType].
  static Map<String, dynamic> createWorkoutBody({
    required String type,
    required String name,
    required List<Map<String, dynamic>> exercise,
    String? refExercise,
    String? supersetIdentifier,
    String? workoutJournal,
  }) {
    final body = <String, dynamic>{
      'type': type,
      'name': name,
      'exercise': exercise,
    };
    if (refExercise != null && refExercise.trim().isNotEmpty) {
      body['refExercise'] = refExercise.trim();
    }
    if (supersetIdentifier != null && supersetIdentifier.trim().isNotEmpty) {
      body['supersetIdentifier'] = supersetIdentifier.trim();
    }
    if (workoutJournal != null && isValidMongoId(workoutJournal)) {
      body['workoutJournal'] = workoutJournal.trim();
    }
    return body;
  }

  /// `POST /customer/workout` — create warmup/workout exercise.
  Future<Map<String, dynamic>> createWorkout(Map<String, dynamic> body) async {
    final raw = await _network.post(AppUrl.customerWorkout, body);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not save workout');
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  static String? createdWorkoutId(dynamic response) {
    if (response is! Map) return null;
    final data = Map<String, dynamic>.from(response)['data'];
    if (data is! Map) return null;
    final m = Map<String, dynamic>.from(data);
    final workout = m['workout'];
    if (workout is Map) {
      final wm = Map<String, dynamic>.from(workout);
      return wm['_id']?.toString() ?? wm['id']?.toString();
    }
    return m['_id']?.toString() ?? m['id']?.toString();
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
    final st = m['status'];
    return st == 200 || st == '200';
  }

  static String? _messageFrom(dynamic response) {
    if (response is! Map) return null;
    final m = Map<String, dynamic>.from(response);
    final message = m['message'];
    if (message is String) return message;
    if (message is List && message.isNotEmpty) {
      final parts = <String>[];
      for (final item in message) {
        if (item is Map) {
          final field = item['field']?.toString();
          final msg = item['message']?.toString();
          if (msg != null && msg.isNotEmpty) {
            parts.add(field != null && field.isNotEmpty ? '$field: $msg' : msg);
          }
        } else if (item is String && item.isNotEmpty) {
          parts.add(item);
        }
      }
      if (parts.isNotEmpty) return parts.join(', ');
      final first = message.first;
      if (first is Map && first['message'] != null) {
        return first['message'].toString();
      }
    }
    return null;
  }
}
