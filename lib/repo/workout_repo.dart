import 'package:get_right/app_url.dart';
import 'package:get_right/models/exercise_set_model.dart';
import 'package:get_right/models/journal_exercise_type.dart';
import 'package:get_right/models/workout_exercise_model.dart';
import 'package:get_right/models/workout_journal_model.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

class WorkoutJournalListPage {
  const WorkoutJournalListPage({required this.entries, required this.page, required this.limit, this.syncFailed = false, this.syncError});

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

  static bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Normalizes a calendar day to UTC midnight ISO — required for journal date matching.
  static String toJournalDate(DateTime date) => DateTime.utc(date.year, date.month, date.day).toIso8601String();

  /// API stores timed sets in `reps` (same field as rep count). Values >= [timedRepsOffset] encode seconds.
  static const int timedRepsOffset = 10000;

  static int encodeTimedRepsForApi(int seconds) => timedRepsOffset + seconds;

  /// Decodes timed seconds from API `reps` (offset encoding or legacy `1000 + seconds`).
  static int? decodeTimedSecondsFromApiReps(dynamic repsRaw) {
    int? asOffset(int n) {
      if (n >= timedRepsOffset) return n - timedRepsOffset;
      if (n > 1000 && n < timedRepsOffset) return n - 1000;
      return null;
    }

    if (repsRaw is num) {
      return asOffset(repsRaw.toInt());
    }
    final parsed = int.tryParse(repsRaw?.toString() ?? '');
    if (parsed == null) return null;
    return asOffset(parsed);
  }

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

      for (final key in ['workoutJournalDoc', 'workoutJournal', 'journal', 'workout', 'result']) {
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

  /// `GET /customer/workout-journal?page=&limit=&dateFrom=&dateTo=` → journal entry list.
  ///
  /// When [dateFrom] is set without [dateTo], both bounds use the same normalized day.
  /// Returns an empty page with [WorkoutJournalListPage.syncFailed] when the server
  /// responds with 5xx (e.g. invalid Mongoose populate on `workout.refExercise.thumbnail`).
  Future<WorkoutJournalListPage> fetchWorkoutJournalEntries({int page = 1, int limit = 10, DateTime? dateFrom, DateTime? dateTo}) async {
    final fromIso = dateFrom != null ? toJournalDate(dateFrom) : null;
    final toIso = dateTo != null ? toJournalDate(dateTo) : fromIso;
    try {
      final raw = await _network.get(AppUrl.customerWorkoutJournalList(page: page, limit: limit, dateFrom: fromIso, dateTo: toIso));
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

  static JournalExerciseType? workoutItemTypeFromMap(Map<String, dynamic> map) => _workoutItemTypeFromMap(map);

  static JournalExerciseType? _workoutItemTypeFromMap(Map<String, dynamic> map) {
    for (final key in ['type', 'workoutType', 'exerciseType']) {
      final parsed = JournalExerciseType.fromApi(map[key]?.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Maps one journal list item from `GET /customer/workout-journal`.
  static WorkoutJournalModel journalFromApiEntry(Map<String, dynamic> entry) {
    final id = entry['_id']?.toString() ?? '';
    final date = DateTime.tryParse(entry['date']?.toString() ?? '') ?? DateTime.now();
    final createdAt = DateTime.tryParse(entry['createdAt']?.toString() ?? '') ?? date;
    final updatedAt = DateTime.tryParse(entry['updatedAt']?.toString() ?? '');
    final duration = (entry['duration'] as num?)?.toInt();
    final caloriesRaw = entry['caloriesBurned'];
    final caloriesBurned = caloriesRaw is num ? caloriesRaw.round() : int.tryParse(caloriesRaw?.toString() ?? '');
    final journalType = entry['type']?.toString();

    final warmupExercises = <WorkoutExerciseModel>[];
    final workoutExercises = <WorkoutExerciseModel>[];
    final workoutItems = entry['workout'];
    if (workoutItems is List) {
      for (final item in workoutItems) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final itemType = _workoutItemTypeFromMap(map);
        final exercise = workoutExerciseFromApi(map, exerciseType: itemType);
        if (itemType?.isWarmup == true) {
          warmupExercises.add(exercise);
        } else if (itemType == JournalExerciseType.workout) {
          workoutExercises.add(exercise);
        } else if (JournalExerciseType.fromApi(journalType)?.isWarmup == true) {
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
      caloriesBurned: caloriesBurned,
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

  static String? _mediaUrlFrom(dynamic media) {
    if (media is Map) {
      return ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(media)['url']?.toString());
    }
    return null;
  }

  static String? _refExerciseVideoUrl(dynamic refExercise) {
    if (refExercise is! Map) return null;
    final video = Map<String, dynamic>.from(refExercise)['video'];
    if (video is! Map) return null;
    return ImageUrlSanitizer.resolveMediaUrl(Map<String, dynamic>.from(video)['url']?.toString());
  }

  static String? _refExerciseVideoThumbnailUrl(dynamic refExercise) {
    if (refExercise is! Map) return null;
    final video = Map<String, dynamic>.from(refExercise)['video'];
    if (video is Map) {
      final vm = Map<String, dynamic>.from(video);
      final thumb = _mediaUrlFrom(vm['thumbnail']);
      if (thumb != null && thumb.isNotEmpty) return thumb;
    }
    return _refExerciseIconUrl(refExercise);
  }

  /// Video URL + thumbnail from a populated `refExercise` object (journal list API).
  static ({String? videoUrl, String? thumbnailUrl}) videoMediaFromRefExercise(dynamic refExercise) {
    return (videoUrl: _refExerciseVideoUrl(refExercise), thumbnailUrl: _refExerciseVideoThumbnailUrl(refExercise));
  }

  static WorkoutExerciseModel workoutExerciseFromApi(Map<String, dynamic> json, {JournalExerciseType? exerciseType}) {
    final id = json['_id']?.toString() ?? '';
    final refRaw = json['refExercise'];
    final refExercise = _refExerciseId(refRaw);
    var name = json['name']?.toString() ?? '';
    if (name.isEmpty && refRaw is Map) {
      name = Map<String, dynamic>.from(refRaw)['name']?.toString() ?? '';
    }
    final supersetParsed = WorkoutExerciseModel.parseSupersetIdentifier(json['supersetIdentifier']?.toString());
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
      videoUrl: _refExerciseVideoUrl(refRaw),
      videoThumbnailUrl: _refExerciseVideoThumbnailUrl(refRaw),
      sets: sets,
      isSuperset: supersetParsed != null,
      supersetId: supersetParsed?.groupId,
      supersetOrder: supersetParsed?.order,
      date: createdAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      notes: _workoutNotesFromApi(json['notes']),
      exerciseType: exerciseType ?? _workoutItemTypeFromMap(json),
    );
  }

  static String? _workoutNotesFromApi(dynamic raw) {
    final note = raw?.toString().trim();
    if (note == null || note.isEmpty) return null;
    return note;
  }

  /// Encodes [ExerciseSetModel] list for `POST/PUT /customer/workout`.
  static List<Map<String, dynamic>> exerciseSetsToApi(List<ExerciseSetModel> sets) {
    const defaultRestTime = 90;
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < sets.length; i++) {
      final s = sets[i];
      final entry = <String, dynamic>{
        'sets': s.setNumber > 0 ? s.setNumber : i + 1,
        'restTime': defaultRestTime,
      };

      if (s.isTimed && s.timeSeconds != null && s.timeSeconds! > 0) {
        entry['time'] = s.timeSeconds;
      } else if (s.isFAILURE) {
        entry['reps'] = 'FAILURE';
      } else if (s.isAMRAP) {
        entry['reps'] = 'AMRAP';
      } else if (s.reps != null && s.reps! > 0) {
        entry['reps'] = s.reps.toString();
      }

      if (s.isBodyweight) {
        entry['weight'] = 'BW';
      } else if (s.weight != null && s.weight! > 0) {
        final w = s.weight!;
        entry['weight'] = w % 1 == 0 ? w.toInt().toString() : w.toString();
      }

      if (s.distance != null && s.distance! > 0) {
        final d = s.distance!;
        entry['distance'] = d % 1 == 0 ? d.toInt() : d;
      }

      out.add(entry);
    }
    return out;
  }

  static ExerciseSetModel _exerciseSetFromApi(Map<String, dynamic> sm, int fallbackIndex) {
    final repsRaw = sm['reps'];
    final apiRepsType = sm['repsType']?.toString().toUpperCase();
    String? repsType;
    int? reps;
    int? timeSeconds;

    final timeField = sm['time'];
    if (timeField is num && timeField > 0) {
      timeSeconds = timeField.toInt();
    }

    if (repsRaw == 'FAILURE') {
      repsType = 'FAILURE';
    } else if (repsRaw == 'AMRAP') {
      repsType = 'AMRAP';
    } else if (apiRepsType == 'TIME' || repsRaw == 'TIME') {
      final decoded = decodeTimedSecondsFromApiReps(repsRaw);
      if (decoded != null && decoded > 0) timeSeconds = decoded;
    } else {
      final timed = decodeTimedSecondsFromApiReps(repsRaw);
      if (timed != null && timed > 0) {
        timeSeconds = timed;
      } else if (repsRaw is num) {
        reps = repsRaw.toInt();
      } else {
        reps = int.tryParse(repsRaw?.toString() ?? '');
      }
    }

    double? weight;
    String? weightType;
    final w = sm['weight'];
    if (w != null) {
      final ws = w.toString().trim();
      if (ws.toUpperCase() == 'BW') {
        weightType = 'BW';
        weight = 0;
      } else {
        weight = double.tryParse(ws);
        if (weight != null && weight > 0) weightType = 'standard';
      }
    }
    final apiWeightType = sm['weightType']?.toString().trim();
    if (apiWeightType != null && apiWeightType.toUpperCase() == 'BW') {
      weightType = 'BW';
      weight ??= 0;
    }

    double? distance;
    final d = sm['distance'];
    if (d != null) distance = double.tryParse(d.toString());

    return ExerciseSetModel(
      id: sm['_id']?.toString() ?? 'set_$fallbackIndex',
      setNumber: (sm['sets'] as num?)?.toInt() ?? (fallbackIndex + 1),
      reps: reps,
      repsType: repsType,
      timeSeconds: timeSeconds,
      weight: weight,
      weightType: weightType,
      distance: distance,
      distanceUnit: sm['distanceUnit']?.toString(),
    );
  }

  /// Earliest journal entry id for [day] — one canonical journal per day for new workouts.
  static String? primaryJournalIdForDay(List<WorkoutJournalModel> entries, {DateTime? day, bool strict = false}) {
    if (entries.isEmpty) return null;
    final target = day ?? DateTime.now();
    final matching = entries.where((e) => _isSameDay(e.date, target)).toList();
    final pool = matching.isNotEmpty ? matching : (strict ? const <WorkoutJournalModel>[] : entries);
    if (pool.isEmpty) return null;
    final sorted = List<WorkoutJournalModel>.from(pool)..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final id = sorted.first.id;
    return isValidMongoId(id) ? id : null;
  }

  /// Merges all journal entries for [day] (default today) into one model for the UI.
  static WorkoutJournalModel? todayEntryFrom(WorkoutJournalListPage page, {DateTime? day, bool strict = false}) {
    final entries = entriesForDay(page, day: day, strict: strict);
    if (entries.isEmpty) return null;
    return _mergeJournalEntries(entries);
  }

  /// Raw journal entries for [day] (default today), without merging.
  ///
  /// When [strict] is true, returns only entries matching [day] (empty if none).
  static List<WorkoutJournalModel> entriesForDay(WorkoutJournalListPage page, {DateTime? day, bool strict = false}) {
    final target = day ?? DateTime.now();
    final matching = page.entries.where((e) => _isSameDay(e.date, target)).toList();
    if (matching.isNotEmpty) return matching;
    if (strict) return const [];
    return List<WorkoutJournalModel>.from(page.entries);
  }

  /// Maps each saved workout exercise id → its parent journal entry id.
  static Map<String, String> exerciseJournalMapFrom(List<WorkoutJournalModel> entries) {
    final map = <String, String>{};
    for (final entry in entries) {
      if (!isValidMongoId(entry.id)) continue;
      for (final ex in entry.allExercises) {
        if (isValidMongoId(ex.id)) map[ex.id] = entry.id;
      }
    }
    return map;
  }

  static WorkoutJournalModel? journalEntryById(List<WorkoutJournalModel> entries, String journalId) {
    for (final entry in entries) {
      if (entry.id == journalId) return entry;
    }
    return null;
  }

  static List<String> workoutIdsFrom(WorkoutJournalModel entry) => entry.allExercises.map((e) => e.id).where(isValidMongoId).toList();

  static WorkoutJournalModel _mergeJournalEntries(List<WorkoutJournalModel> entries) {
    final sorted = List<WorkoutJournalModel>.from(entries)..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final warmupExercises = <WorkoutExerciseModel>[];
    final workoutExercises = <WorkoutExerciseModel>[];
    final seenExerciseIds = <String>{};
    var totalDuration = 0;

    for (final entry in sorted) {
      for (final ex in entry.warmupExercises) {
        if (seenExerciseIds.add(ex.id)) warmupExercises.add(ex);
      }
      for (final ex in entry.workoutExercises) {
        if (seenExerciseIds.add(ex.id)) workoutExercises.add(ex);
      }
      totalDuration += entry.durationSeconds ?? 0;
    }

    final earliest = sorted.first;
    final latest = sorted.last;

    return WorkoutJournalModel(
      id: earliest.id,
      userId: earliest.userId,
      date: earliest.date,
      warmupExercises: warmupExercises,
      workoutExercises: workoutExercises,
      createdAt: earliest.createdAt,
      updatedAt: latest.updatedAt,
      durationSeconds: totalDuration > 0 ? totalDuration : latest.durationSeconds,
      caloriesBurned: latest.caloriesBurned,
    );
  }

  /// Workout ids present in today's journal list but not in [beforeIds] (after POST /customer/workout).
  Future<List<String>> findNewWorkoutIdsAfterCreate({required List<String> beforeIds, DateTime? date}) async {
    final day = date ?? DateTime.now();
    final before = beforeIds.where(isValidMongoId).map((id) => id.trim()).toSet();
    final page = await fetchWorkoutJournalEntries(dateFrom: day, dateTo: day);
    final entries = entriesForDay(page, day: day, strict: true);
    final found = <String>[];
    for (final entry in entries) {
      for (final id in workoutIdsFrom(entry)) {
        if (!before.contains(id)) found.add(id);
      }
    }
    return found;
  }

  /// One journal per calendar day — merge every workout id into the earliest journal entry.
  Future<String> consolidateDayJournal({
    List<String> newWorkoutIds = const [],
    List<String> existingJournalWorkoutIds = const [],
    String? preferredJournalId,
    DateTime? date,
    int duration = 0,
    String notes = '',
  }) async {
    final day = date ?? DateTime.now();
    final page = await fetchWorkoutJournalEntries(dateFrom: day, dateTo: day);
    final entries = entriesForDay(page, day: day, strict: true);

    var canonicalId = isValidMongoId(preferredJournalId) ? preferredJournalId!.trim() : null;
    canonicalId ??= primaryJournalIdForDay(entries, day: day);

    final allIds = <String>{};
    for (final entry in entries) {
      for (final id in workoutIdsFrom(entry)) {
        allIds.add(id);
      }
    }
    for (final id in existingJournalWorkoutIds) {
      if (isValidMongoId(id)) allIds.add(id.trim());
    }
    for (final id in newWorkoutIds) {
      if (isValidMongoId(id)) allIds.add(id.trim());
    }

    final deduped = allIds.toList();
    if (deduped.isEmpty) {
      if (canonicalId != null) return canonicalId;
      throw Exception('At least one workout is required');
    }

    final resolvedDuration = _resolveJournalDuration(
      entries: entries,
      requestedDuration: duration,
      journalId: canonicalId,
    );

    if (canonicalId != null) {
      await updateWorkoutJournal(journalId: canonicalId, workoutIds: deduped, duration: resolvedDuration, notes: notes);
      return canonicalId;
    }

    canonicalId = await findWorkoutJournalIdForToday(date: day);
    if (canonicalId != null) {
      final updateDuration = _resolveJournalDuration(
        entries: entries,
        requestedDuration: duration,
        journalId: canonicalId,
      );
      await updateWorkoutJournal(journalId: canonicalId, workoutIds: deduped, duration: updateDuration, notes: notes);
      return canonicalId;
    }

    return createWorkoutJournalEntry(date: toJournalDate(day), workoutIds: deduped, duration: resolvedDuration, notes: notes);
  }

  /// API requires journal `duration` >= 1 second.
  static int journalDurationForApi(int duration, {int? existingDuration}) {
    if (duration >= 1) return duration;
    if (existingDuration != null && existingDuration >= 1) return existingDuration;
    return 1;
  }

  static int _resolveJournalDuration({
    required List<WorkoutJournalModel> entries,
    required int requestedDuration,
    String? journalId,
  }) {
    if (requestedDuration >= 1) return requestedDuration;

    final existing = journalId != null ? journalEntryById(entries, journalId) : null;
    final existingDuration = existing?.durationSeconds;
    if (existingDuration != null && existingDuration >= 1) return existingDuration;

    for (final entry in entries) {
      final duration = entry.durationSeconds;
      if (duration != null && duration >= 1) return duration;
    }

    return 1;
  }

  /// Builds `PUT /customer/workout-journal/:id` body (partial update).
  static Map<String, dynamic> updateJournalBody({List<String>? workout, int? duration, String? notes, bool? isComplete}) {
    final body = <String, dynamic>{};
    if (workout != null) body['workout'] = workout;
    if (duration != null) body['duration'] = journalDurationForApi(duration);
    if (notes != null) body['notes'] = notes;
    if (isComplete != null) body['isComplete'] = isComplete;
    return body;
  }

  /// Updates an existing journal entry (`PUT /customer/workout-journal/:journalId`).
  Future<Map<String, dynamic>> updateWorkoutJournal({
    required String journalId,
    List<String>? workoutIds,
    int? duration,
    String? notes,
    bool? isComplete,
  }) async {
    final body = updateJournalBody(workout: workoutIds, duration: duration, notes: notes, isComplete: isComplete);
    if (body.isEmpty) throw Exception('Nothing to update');
    final raw = await _network.put(AppUrl.customerWorkoutJournalById(journalId), body);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not update workout journal');
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  /// Marks a journal complete — syncs to calendar via `isComplete: true`.
  Future<Map<String, dynamic>> completeWorkoutJournal({required String journalId, required int duration}) async {
    return updateWorkoutJournal(journalId: journalId, duration: duration, isComplete: true);
  }

  /// Builds `POST /customer/workout-journal` body (all of `workout`, `duration`, `notes` are required).
  static Map<String, dynamic> createJournalBody({required String date, List<String> workout = const [], int duration = 0, String notes = '', String? type}) {
    return {'date': date, if (type != null && type.isNotEmpty) 'type': type, 'workout': workout, 'duration': duration, 'notes': notes};
  }

  /// Returns today's journal id from list API, or null when none exists yet.
  Future<String?> findWorkoutJournalIdForToday({DateTime? date}) async {
    final day = date ?? DateTime.now();
    try {
      final page = await fetchWorkoutJournalEntries(dateFrom: day, dateTo: day);
      final entries = entriesForDay(page, day: day, strict: true);
      return primaryJournalIdForDay(entries, day: day, strict: true);
    } catch (_) {
      return null;
    }
  }

  /// Creates a journal entry — API requires at least one workout id.
  Future<String> createWorkoutJournalEntry({required String date, required List<String> workoutIds, int duration = 0, String notes = '', String? type}) async {
    if (workoutIds.isEmpty) {
      throw Exception('At least one workout is required');
    }
    final safeDuration = journalDurationForApi(duration);
    final postRaw = await _network.post(
      AppUrl.customerWorkoutJournalCreate,
      createJournalBody(date: date, workout: workoutIds, duration: safeDuration, notes: notes, type: type ?? JournalExerciseType.workout.apiValue),
    );
    if (!_isOk(postRaw)) {
      throw Exception(_messageFrom(postRaw) ?? 'Could not create workout journal');
    }
    final fromPost = journalIdFrom(postRaw);
    if (fromPost != null) return fromPost;
    throw Exception('Workout journal id missing from server response');
  }

  /// Links [workoutIds] to today's single canonical journal entry.
  Future<String> ensureWorkoutJournalLinked({
    required List<String> workoutIds,
    DateTime? date,
    String? existingJournalId,
    List<String> existingJournalWorkoutIds = const [],
    int duration = 0,
    String notes = '',
  }) async {
    return consolidateDayJournal(
      newWorkoutIds: workoutIds,
      existingJournalWorkoutIds: existingJournalWorkoutIds,
      preferredJournalId: existingJournalId,
      date: date,
      duration: duration,
      notes: notes,
    );
  }

  /// Saves/completes a workout journal session (`POST /customer/workout-journal`).
  Future<Map<String, dynamic>> submitWorkoutJournal({
    required String date,
    required List<String> workoutIds,
    required int duration,
    required String notes,
    String type = 'Workout',
  }) async {
    final safeDuration = journalDurationForApi(duration);
    final raw = await _network.post(AppUrl.customerWorkoutJournalCreate, createJournalBody(date: date, workout: workoutIds, duration: safeDuration, notes: notes, type: type));
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
    String? date,
    int? duration,
    String? notes,
  }) {
    final body = <String, dynamic>{'type': type, 'name': name, 'exercise': exercise};
    if (refExercise != null && refExercise.trim().isNotEmpty) {
      body['refExercise'] = refExercise.trim();
    }
    if (supersetIdentifier != null && supersetIdentifier.trim().isNotEmpty) {
      body['supersetIdentifier'] = supersetIdentifier.trim();
    }
    if (workoutJournal != null && isValidMongoId(workoutJournal)) {
      body['workoutJournal'] = workoutJournal.trim();
    }
    if (date != null && date.trim().isNotEmpty) {
      body['date'] = date.trim();
    }
    if (duration != null && duration >= 1) {
      body['duration'] = duration;
    }
    if (notes != null && notes.trim().isNotEmpty) {
      body['notes'] = notes.trim();
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

  /// Builds `PUT /customer/workout/:workoutId` body.
  static Map<String, dynamic> updateWorkoutBody({
    required String name,
    required List<Map<String, dynamic>> exercise,
    String? notes,
  }) {
    final body = <String, dynamic>{'name': name, 'exercise': exercise};
    if (notes != null) body['notes'] = notes;
    return body;
  }

  /// Updates an existing workout exercise (`PUT /customer/workout/:workoutId`).
  Future<Map<String, dynamic>> updateWorkout(String workoutId, Map<String, dynamic> body) async {
    final raw = await _network.put(AppUrl.customerWorkoutById(workoutId), body);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not update workout');
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  /// Journal id returned when `POST /customer/workout` auto-creates today's journal.
  static String? journalIdFromCreateWorkout(dynamic response) => journalIdFrom(response);

  /// Workout id from `POST /customer/workout` (`data.workoutJournalDoc.workout[]` or nested workout doc).
  static String? createdWorkoutId(dynamic response) {
    if (response is! Map) return null;
    final root = Map<String, dynamic>.from(response);
    final data = root['data'];
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      final journalDoc = m['workoutJournalDoc'];
      if (journalDoc is Map) {
        final doc = Map<String, dynamic>.from(journalDoc);
        final workoutRefs = doc['workout'];
        if (workoutRefs is List) {
          for (final ref in workoutRefs.reversed) {
            final id = _mongoId(ref);
            if (id != null) return id;
          }
        }
      }
      for (final key in ['workout', 'createdWorkout', 'result']) {
        final nested = m[key];
        if (nested is Map) {
          final wm = Map<String, dynamic>.from(nested);
          final id = wm['_id']?.toString() ?? wm['id']?.toString();
          if (id != null && isValidMongoId(id)) return id;
        }
      }
      final direct = m['_id']?.toString() ?? m['id']?.toString();
      if (direct != null && isValidMongoId(direct)) return direct;
    }
    final top = root['_id']?.toString() ?? root['id']?.toString();
    if (top != null && isValidMongoId(top)) return top;
    return null;
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
