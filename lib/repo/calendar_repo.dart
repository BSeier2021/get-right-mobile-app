import 'dart:io';

import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

class CalendarRepository {
  final _network = NetworkApiService();

  static const String typeCompleted = 'Completed';
  static const String typeIncomplete = 'Incomplete';
  static const String typeInProgress = 'InProgress';
  static const String typeRest = 'Rest';

  /// Readable API / network error for UI.
  static String errorMessageFrom(Object error) {
    if (error is BadRequestException) return error.message;
    if (error is UnauthorizedException) return error.message;
    if (error is ForbiddenException) return error.message;
    if (error is NotFoundException) return error.message;
    if (error is ConflictException) return error.message;
    if (error is ServerException) return error.message;
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }

  /// Calendar day at midnight UTC — matches `2026-07-27T00:00:00.000Z`.
  static String dateToApiIso(DateTime date) => DateTime.utc(date.year, date.month, date.day).toIso8601String();

  static Map<String, dynamic> createEntryBody({
    required DateTime date,
    required String type,
    String? notes,
    String? workoutJournal,
    String? runningLog,
  }) {
    final body = <String, dynamic>{
      'date': dateToApiIso(date),
      'type': type.trim(),
    };
    if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes.trim();
    if (workoutJournal != null && WorkoutRepository.isValidMongoId(workoutJournal)) {
      body['workoutJournal'] = workoutJournal.trim();
    }
    if (runningLog != null && WorkoutRepository.isValidMongoId(runningLog)) {
      body['runningLog'] = runningLog.trim();
    }
    return body;
  }

  /// `GET /customer/calendar?year=&month=` — returns day-keyed planner map.
  Future<Map<DateTime, Map<String, dynamic>>> fetchCalendarMonth({required int year, required int month}) async {
    final raw = await _network.get(AppUrl.customerCalendarList(year: year, month: month));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load calendar');
    }

    final root = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final data = root['data'];
    final entries = data is Map ? data['entries'] : null;
    final list = entries is List ? entries : const <dynamic>[];
    return dayDataMapFromEntries(list);
  }

  static DateTime normalizedDate(DateTime date) => DateTime(date.year, date.month, date.day);

  static bool isSameCalendarDay(DateTime a, DateTime b) {
    final left = normalizedDate(a);
    final right = normalizedDate(b);
    return left.year == right.year && left.month == right.month && left.day == right.day;
  }

  static String? entryIdFromCalendarRecord(Map<String, dynamic> entry) {
    return _mongoId(entry['_id'] ?? entry['id'] ?? entry['calendarEntryId']);
  }

  static Map<String, dynamic>? dayDataForDate(Map<DateTime, Map<String, dynamic>> dayData, DateTime date) {
    final key = normalizedDate(date);
    final direct = dayData[key];
    if (direct != null) return direct;

    for (final item in dayData.entries) {
      if (isSameCalendarDay(item.key, date)) return item.value;
    }
    return null;
  }

  static String? entryIdForDate(Map<DateTime, Map<String, dynamic>> dayData, DateTime date) {
    final data = dayDataForDate(dayData, date);
    return _mongoId(data?['calendarEntryId']);
  }

  static DateTime dateKeyFromEntry(Map<String, dynamic> entry) {
    final year = _intFrom(entry['year']);
    final month = _intFrom(entry['month']);
    final day = _intFrom(entry['day']);
    if (year != null && month != null && day != null) {
      return normalizedDate(DateTime(year, month, day));
    }

    final parsed = DateTime.tryParse(entry['date']?.toString() ?? '');
    if (parsed != null) {
      return normalizedDate(DateTime(parsed.year, parsed.month, parsed.day));
    }

    return normalizedDate(DateTime.now());
  }

  static int? _intFrom(dynamic raw) {
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  static String workoutStatusFromType(String? type) {
    switch (type?.trim().toLowerCase()) {
      case 'completed':
        return 'completed';
      case 'incomplete':
        return 'incomplete';
      case 'inprogress':
      case 'in progress':
        return 'inprogress';
      case 'rest':
        return 'rest';
      default:
        return 'completed';
    }
  }

  static String formatDurationSeconds(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final hours = safe ~/ 3600;
    final minutes = (safe % 3600) ~/ 60;
    final secs = safe % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  static String formatPaceMinPerKm(double? paceMinPerKm) {
    if (paceMinPerKm == null || paceMinPerKm <= 0) return '--:-- /km';
    final minutes = paceMinPerKm.floor();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')} /km';
  }

  static Map<String, dynamic>? runSummaryFromRunningLogRaw(dynamic runningLogRaw) {
    if (runningLogRaw == null) return null;
    if (runningLogRaw is! Map) return null;

    final log = Map<String, dynamic>.from(runningLogRaw);
    var distanceMeters = (log['distance'] as num?)?.toDouble() ?? 0.0;
    final durationSeconds = (log['duration'] as num?)?.toInt() ?? 0;
    double? averagePace;
    if (distanceMeters > 0 && durationSeconds > 0) {
      averagePace = (durationSeconds / 60) / (distanceMeters / 1000);
    }

    String? routeId;
    final routeRaw = log['route'];
    if (routeRaw is String && WorkoutRepository.isValidMongoId(routeRaw)) {
      routeId = routeRaw.trim();
    } else if (routeRaw is Map) {
      final routeMap = Map<String, dynamic>.from(routeRaw);
      final nested = routeMap['_id'] ?? routeMap['id'];
      if (WorkoutRepository.isValidMongoId(nested?.toString())) {
        routeId = nested.toString().trim();
      }
    }

    final activityType = log['runningType']?.toString() ?? 'Run';
    final isPlannedRoute = routeId != null && durationSeconds <= 0 && distanceMeters <= 0;

    return {
      'id': log['_id']?.toString(),
      'distance': '${(distanceMeters / 1000).toStringAsFixed(2)} km',
      'time': formatDurationSeconds(durationSeconds),
      'pace': formatPaceMinPerKm(averagePace),
      'calories': (log['caloriesBurned'] as num?)?.toInt() ?? 0,
      'activityType': activityType,
      if (routeId != null) 'routeId': routeId,
      'isPlannedRoute': isPlannedRoute,
    };
  }

  static Map<String, dynamic>? workoutSummaryFromJournal(dynamic journalRaw) {
    if (journalRaw is! Map) return null;
    final journal = Map<String, dynamic>.from(journalRaw);
    final workouts = journal['workout'];
    if (workouts is! List || workouts.isEmpty) return null;

    var setCount = 0;
    for (final workout in workouts) {
      if (workout is! Map) continue;
      final exercises = Map<String, dynamic>.from(workout)['exercise'];
      if (exercises is List) setCount += exercises.length;
    }

    final durationSeconds = _intFrom(journal['duration']) ?? 0;
    final journalCalories = _intFrom(journal['caloriesBurned']);
    final calories = journalCalories ?? (durationSeconds > 0 ? (durationSeconds / 60 * 5).round() : 0);
    final parsedWorkouts = journalWorkoutsFromJournal(journal);

    return {
      'duration': formatDurationSeconds(durationSeconds),
      'durationSeconds': durationSeconds,
      'exercises': parsedWorkouts.length,
      'sets': setCount,
      'calories': calories,
      'journalId': journal['_id']?.toString(),
      'journalType': journal['type']?.toString(),
      'notes': journal['notes']?.toString().trim() ?? '',
      'journalDate': journal['date']?.toString(),
      'workouts': parsedWorkouts,
    };
  }

  static Map<String, dynamic> journalSetFromApi(Map<String, dynamic> setMap, int fallbackIndex) {
    final setNumber = _intFrom(setMap['sets']) ?? (fallbackIndex + 1);
    final restTime = _intFrom(setMap['restTime']);

    int? timeSeconds;
    final timeField = setMap['time'];
    if (timeField is num && timeField > 0) {
      timeSeconds = timeField.toInt();
    } else {
      timeSeconds = WorkoutRepository.decodeTimedSecondsFromApiReps(setMap['reps']);
    }

    String? repsDisplay;
    final repsRaw = setMap['reps'];
    if (repsRaw == 'FAILURE') {
      repsDisplay = 'FAILURE';
    } else if (repsRaw == 'AMRAP') {
      repsDisplay = 'AMRAP';
    } else if (timeSeconds == null || timeSeconds <= 0) {
      if (repsRaw != null) {
        final parsed = int.tryParse(repsRaw.toString());
        if (parsed != null && parsed > 0) repsDisplay = parsed.toString();
      }
    }

    String? weightDisplay;
    final weightRaw = setMap['weight'];
    if (weightRaw != null) {
      final ws = weightRaw.toString().trim();
      if (ws.toUpperCase() == 'BW') {
        weightDisplay = 'BW';
      } else if (ws.isNotEmpty && ws.toLowerCase() != 'null') {
        weightDisplay = ws;
      }
    }

    double? distance;
    final distanceRaw = setMap['distance'];
    if (distanceRaw is num && distanceRaw > 0) {
      distance = distanceRaw.toDouble();
    }

    return {
      'setNumber': setNumber,
      'reps': repsDisplay,
      'weight': weightDisplay,
      'timeSeconds': timeSeconds,
      'time': timeSeconds != null && timeSeconds > 0 ? formatDurationSeconds(timeSeconds) : null,
      'distance': distance,
      'restTime': restTime,
      'hasReps': repsDisplay != null,
      'hasWeight': weightDisplay != null,
      'hasTime': timeSeconds != null && timeSeconds > 0,
      'hasDistance': distance != null && distance > 0,
    };
  }

  static String? exerciseIconUrlFromWorkout(Map<String, dynamic> workout) {
    final ref = workout['refExercise'];
    if (ref is Map) {
      final icon = Map<String, dynamic>.from(ref)['icon'];
      if (icon is Map) return photoUrlFrom(icon);
    }
    return null;
  }

  static List<Map<String, dynamic>> journalWorkoutsFromJournal(Map<String, dynamic> journal) {
    final workouts = journal['workout'];
    if (workouts is! List) return const [];

    final result = <Map<String, dynamic>>[];
    for (final item in workouts) {
      if (item is! Map) continue;
      final workout = Map<String, dynamic>.from(item);

      String name = workout['name']?.toString().trim() ?? '';
      final ref = workout['refExercise'];
      if (name.isEmpty && ref is Map) {
        name = Map<String, dynamic>.from(ref)['name']?.toString().trim() ?? '';
      }
      if (name.isEmpty) name = 'Exercise';

      final sets = <Map<String, dynamic>>[];
      final exerciseSets = workout['exercise'];
      if (exerciseSets is List) {
        for (var i = 0; i < exerciseSets.length; i++) {
          final setRaw = exerciseSets[i];
          if (setRaw is! Map) continue;
          sets.add(journalSetFromApi(Map<String, dynamic>.from(setRaw), i));
        }
      }

      final exerciseType = WorkoutRepository.workoutItemTypeFromMap(workout)?.apiValue ?? journal['type']?.toString();

      result.add({
        'id': workout['_id']?.toString(),
        'name': name,
        'iconUrl': exerciseIconUrlFromWorkout(workout),
        'sets': sets,
        if (exerciseType != null) 'exerciseType': exerciseType,
      });
    }
    return result;
  }

  static bool hasProgressPhotosInEntry(Map<String, dynamic> entry) {
    final photos = entry['progressPhotos'];
    return photos is List && photos.isNotEmpty;
  }

  static String? photoUrlFrom(dynamic photo) {
    String? raw;

    if (photo is String) {
      raw = photo.trim();
    } else if (photo is Map) {
      final map = Map<String, dynamic>.from(photo);
      for (final key in ['url', 'imageUrl', 'fileUrl', 'photoUrl', 'path', 'src', 'secureUrl', 'location', 'key', 'filePath', 'filename']) {
        final value = map[key];
        if (value is Map) {
          raw = photoUrlFrom(value);
        } else {
          raw = value?.toString().trim();
        }
        if (raw != null && raw.isNotEmpty && raw != 'null') break;
      }

      raw ??= photoUrlFrom(map['file']);
      raw ??= photoUrlFrom(map['media']);
      raw ??= photoUrlFrom(map['icon']);
      raw ??= photoUrlFrom(map['thumbnail']);
      raw ??= photoUrlFrom(map['image']);
      raw ??= photoUrlFrom(map['photo']);
    }

    if (raw == null || raw.isEmpty || raw == 'null') return null;
    if (_looksLikeMongoId(raw)) return null;

    return ImageUrlSanitizer.resolveMediaUrl(raw) ?? ImageUrlSanitizer.asHttpUrlOrNull(raw);
  }

  static bool _looksLikeMongoId(String value) {
    return RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(value.trim());
  }

  static String normalizePhotoType(String? raw, {required int index, String? entryNotes}) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.contains('front')) return 'front';
    if (value.contains('side')) return 'side';

    final notes = entryNotes?.toLowerCase() ?? '';
    if (notes.contains('front')) return 'front';
    if (notes.contains('side')) return 'side';

    return index == 0 ? 'front' : 'side';
  }

  static List<Map<String, dynamic>> progressPhotosFromEntry(Map<String, dynamic> entry) {
    final photos = entry['progressPhotos'];
    if (photos is! List || photos.isEmpty) return const [];

    final entryNotes = entry['notes']?.toString();
    final result = <Map<String, dynamic>>[];

    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      if (photo is String) {
        final url = photoUrlFrom(photo);
        if (url == null) continue;
        result.add({
          'url': url,
          'type': normalizePhotoType(null, index: i, entryNotes: entryNotes),
        });
        continue;
      }

      if (photo is Map) {
        final map = Map<String, dynamic>.from(photo);
        final url = photoUrlFrom(map);
        if (url == null) continue;
        result.add({
          ...map,
          'url': url,
          'type': normalizePhotoType(
            map['type']?.toString() ?? map['photoType']?.toString() ?? map['progressPhotoType']?.toString() ?? map['label']?.toString(),
            index: i,
            entryNotes: entryNotes,
          ),
        });
      }
    }

    return result;
  }

  static bool dayHasProgressPhotos(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['hasProgressPhoto'] == true) return true;
    final photos = data['progressPhotos'];
    return photos is List && photos.isNotEmpty;
  }

  static String? progressPhotoUrlForType(dynamic photosRaw, String type) {
    if (photosRaw is! List || photosRaw.isEmpty) return null;

    final target = type.toLowerCase();
    String? lastMatch;

    for (final photo in photosRaw) {
      if (photo is! Map) continue;
      final map = Map<String, dynamic>.from(photo);
      final photoType = map['type']?.toString().toLowerCase() ?? '';
      if (!photoType.contains(target)) continue;
      final url = photoUrlFrom(map);
      if (url != null) lastMatch = url;
    }
    if (lastMatch != null) return lastMatch;

    final fallbackIndex = target == 'front' ? 0 : 1;
    if (fallbackIndex < photosRaw.length) {
      return photoUrlFrom(photosRaw[fallbackIndex]);
    }
    return null;
  }

  static Map<String, dynamic>? dayDataFromMutationResponse(dynamic raw) {
    if (raw is! Map) return null;
    final root = Map<String, dynamic>.from(raw);

    final data = root['data'];
    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);
      for (final key in ['entry', 'calendar', 'calendarEntry', 'result']) {
        final nested = dataMap[key];
        if (nested is Map) {
          return dayDataFromEntry(
            Map<String, dynamic>.from(nested),
            nutrition: nutritionSummaryFromApi(dataMap['nutrition']),
          );
        }
      }
      if (dataMap.containsKey('_id')) {
        return dayDataFromEntry(dataMap, nutrition: nutritionSummaryFromApi(dataMap['nutrition']));
      }
    }

    if (root.containsKey('_id')) {
      return dayDataFromEntry(root);
    }
    return null;
  }

  static List<Map<String, dynamic>> mergeProgressPhotoLists(dynamic existingRaw, dynamic incomingRaw) {
    final byType = <String, Map<String, dynamic>>{};

    void put(String key, Map<String, dynamic> map) {
      final nextUrl = photoUrlFrom(map);
      final previous = byType[key];
      if (previous != null) {
        final previousUrl = photoUrlFrom(previous);
        if (nextUrl == null && previousUrl != null) return;
      }
      byType[key] = map;
    }

    void absorb(dynamic raw) {
      if (raw is! List) return;
      for (var i = 0; i < raw.length; i++) {
        final photo = raw[i];
        if (photo is String) {
          final url = photoUrlFrom(photo);
          if (url == null) continue;
          final key = i == 0 ? 'front' : i == 1 ? 'side' : 'photo_$i';
          put(key, {'url': url, 'type': key == 'side' ? 'side' : 'front'});
          continue;
        }

        if (photo is! Map) continue;
        final map = Map<String, dynamic>.from(photo);
        final typeRaw = map['type']?.toString().toLowerCase() ?? '';
        final key = typeRaw.contains('side')
            ? 'side'
            : typeRaw.contains('front')
            ? 'front'
            : 'photo_$i';
        put(key, map);
      }
    }

    absorb(existingRaw);
    absorb(incomingRaw);
    return byType.values.toList();
  }

  static bool hasResolvableProgressPhotos(dynamic photosRaw) {
    if (photosRaw is! List || photosRaw.isEmpty) return false;
    for (final photo in photosRaw) {
      if (photoUrlFrom(photo) != null) return true;
    }
    return false;
  }

  static Map<String, dynamic> mergeDayData(Map<String, dynamic>? existing, Map<String, dynamic> incoming) {
    if (existing == null) return incoming;

    final merged = Map<String, dynamic>.from(existing)..addAll(incoming);
    final existingPhotos = existing['progressPhotos'];
    final incomingPhotos = incoming['progressPhotos'];

    if (existingPhotos is List || incomingPhotos is List) {
      final combined = mergeProgressPhotoLists(existingPhotos, incomingPhotos);
      if (combined.isNotEmpty) {
        merged['progressPhotos'] = combined;
      }
      merged['hasProgressPhoto'] =
          hasResolvableProgressPhotos(combined) ||
          existing['hasProgressPhoto'] == true ||
          incoming['hasProgressPhoto'] == true;
    }

    merged['calendarEntryId'] ??= existing['calendarEntryId'] ?? incoming['calendarEntryId'];
    merged['calendarEntryType'] ??= incoming['calendarEntryType'] ?? existing['calendarEntryType'];
    return merged;
  }

  static final RegExp _progressPhotoNoteTag = RegExp(r'^(front|side)\s+progress\s+photo$', caseSensitive: false);

  /// User-facing notes only — strips internal progress-photo tags saved in older builds.
  static String displayNotesFrom(String? raw) {
    final notes = raw?.trim() ?? '';
    if (notes.isEmpty) return '';

    final parts = notes.split(RegExp(r'\s*[·•]\s*'));
    final filtered = parts.map((part) => part.trim()).where((part) {
      if (part.isEmpty) return false;
      return !_progressPhotoNoteTag.hasMatch(part);
    }).toList();

    return filtered.join(' · ').trim();
  }

  static bool hasUserNotes(String? raw) => displayNotesFrom(raw).isNotEmpty;

  static List<Map<String, dynamic>> programExercisesFrom(dynamic exercisesRaw) {
    if (exercisesRaw is! List) return const [];
    return exercisesRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static List<Map<String, dynamic>> parseWorkoutDaysList(dynamic raw) {
    if (raw is! List) return const [];
    final days = raw.whereType<Map>().map((day) => Map<String, dynamic>.from(day)).toList();
    days.sort((a, b) => (_intFrom(a['dayNumber']) ?? 0).compareTo(_intFrom(b['dayNumber']) ?? 0));
    return days;
  }

  static int? inferProgramDayNumber(List<Map<String, dynamic>> dayExercises, List<Map<String, dynamic>> workoutDays) {
    if (dayExercises.isEmpty || workoutDays.isEmpty) return null;
    final signature = dayExercises.map((e) => e['exerciseName']?.toString()).join('|');
    for (final day in workoutDays) {
      final exercises = programExercisesFrom(day['exercises']);
      final daySignature = exercises.map((e) => e['exerciseName']?.toString()).join('|');
      if (signature.isNotEmpty && signature == daySignature) {
        return _intFrom(day['dayNumber']);
      }
    }
    return null;
  }

  static Map<String, dynamic> buildProgramDay({
    required Map<String, dynamic>? enrollment,
    required Map<String, dynamic> programStub,
    required List<Map<String, dynamic>> workoutDays,
    required List<Map<String, dynamic>> exercises,
    required int dayNumber,
    String? entryType,
  }) {
    var totalSets = 0;
    for (final ex in exercises) {
      totalSets += _intFrom(ex['numberOfSets']) ?? 0;
    }

    String? title;
    String? difficulty;
    int? durationWeeks;
    String? enrollmentId;
    if (enrollment != null) {
      final enrollmentMap = Map<String, dynamic>.from(enrollment);
      enrollmentId = enrollmentMap['_id']?.toString();
      final nestedProgram = enrollmentMap['program'];
      if (nestedProgram is Map) {
        final nested = Map<String, dynamic>.from(nestedProgram);
        title = nested['title']?.toString();
        difficulty = nested['difficultyLevel']?.toString();
        durationWeeks = _intFrom(nested['duration']);
      }
    }

    final status = programStub['status']?.toString().trim().isNotEmpty == true ? programStub['status']?.toString() : entryType;

    return {
      'title': title ?? 'Program Workout',
      'status': status ?? 'incomplete',
      'difficulty': difficulty ?? '',
      'durationWeeks': durationWeeks ?? 0,
      'exercises': exercises,
      'exerciseCount': exercises.length,
      'totalSets': totalSets,
      'programId': programStub['programId']?.toString(),
      'enrollmentId': enrollmentId,
      'workoutDays': workoutDays,
      'dayNumber': dayNumber,
      'currentDayNumber': dayNumber,
    };
  }

  static Map<String, dynamic>? programDayFromEntry(Map<String, dynamic> entry) {
    final programRaw = entry['program'];
    if (programRaw is! Map) return null;
    final program = Map<String, dynamic>.from(programRaw);
    final exercises = programExercisesFrom(program['exercises']);
    if (exercises.isEmpty) return null;

    Map<String, dynamic>? enrollment;
    var workoutDays = const <Map<String, dynamic>>[];
    if (program['enrollmentId'] is Map) {
      enrollment = Map<String, dynamic>.from(program['enrollmentId'] as Map);
      final nestedProgram = enrollment['program'];
      if (nestedProgram is Map) {
        workoutDays = parseWorkoutDaysList(nestedProgram['workoutDays']);
      }
    }

    final dayNumber = inferProgramDayNumber(exercises, workoutDays) ?? _intFrom(program['dayNumber']) ?? 1;

    return buildProgramDay(
      enrollment: enrollment,
      programStub: program,
      workoutDays: workoutDays,
      exercises: exercises,
      dayNumber: dayNumber,
      entryType: entry['type']?.toString(),
    );
  }

  static void expandProgramScheduleInMap(Map<DateTime, Map<String, dynamic>> map) {
    final grouped = <String, List<MapEntry<DateTime, Map<String, dynamic>>>>{};

    for (final entry in map.entries) {
      final program = entry.value['program'];
      if (program is! Map) continue;
      final enrollmentId = program['enrollmentId']?.toString();
      if (enrollmentId == null || enrollmentId.isEmpty) continue;
      grouped.putIfAbsent(enrollmentId, () => []).add(entry);
    }

    for (final entries in grouped.values) {
      entries.sort((a, b) => a.key.compareTo(b.key));
      final templateProgram = Map<String, dynamic>.from(entries.first.value['program'] as Map);
      final workoutDays = templateProgram['workoutDays'] is List
          ? (templateProgram['workoutDays'] as List).whereType<Map>().map((day) => Map<String, dynamic>.from(day)).toList()
          : const <Map<String, dynamic>>[];
      if (workoutDays.isEmpty) continue;

      final anchorDate = entries.first.key;

      for (var i = 0; i < workoutDays.length; i++) {
        final workoutDay = workoutDays[i];
        final dayNumber = _intFrom(workoutDay['dayNumber']) ?? (i + 1);
        final exercises = programExercisesFrom(workoutDay['exercises']);
        if (exercises.isEmpty) continue;

        final targetDate = i < entries.length ? entries[i].key : anchorDate.add(Duration(days: i));
        final dayProgram = Map<String, dynamic>.from(templateProgram)
          ..['exercises'] = exercises
          ..['exerciseCount'] = exercises.length
          ..['totalSets'] = exercises.fold<int>(0, (sum, ex) => sum + (_intFrom(ex['numberOfSets']) ?? 0))
          ..['workoutDays'] = workoutDays
          ..['dayNumber'] = dayNumber
          ..['currentDayNumber'] = dayNumber;

        if (map.containsKey(targetDate)) {
          final existing = map[targetDate]!;
          final existingProgram = existing['program'];
          if (existingProgram == null) {
            map[targetDate] = mergeDayData(existing, {
              'program': dayProgram,
              'workoutStatus': workoutStatusFromType(dayProgram['status']?.toString()),
            });
          } else if (existingProgram is Map) {
            final mergedProgram = Map<String, dynamic>.from(existingProgram);
            if (mergedProgram['workoutDays'] == null || (mergedProgram['workoutDays'] is List && (mergedProgram['workoutDays'] as List).isEmpty)) {
              mergedProgram['workoutDays'] = workoutDays;
            }
            mergedProgram['currentDayNumber'] = dayNumber;
            mergedProgram['dayNumber'] = dayNumber;
            map[targetDate] = mergeDayData(existing, {'program': mergedProgram});
          }
        } else {
          map[targetDate] = {
            'workoutStatus': workoutStatusFromType(dayProgram['status']?.toString()),
            'hasProgressPhoto': false,
            'progressPhotos': const [],
            'workout': null,
            'run': null,
            'nutrition': null,
            'notes': '',
            'program': dayProgram,
          };
        }
      }
    }
  }

  static Map<String, dynamic> dayDataFromEntry(Map<String, dynamic> entry, {Map<String, dynamic>? nutrition}) {
    final photos = progressPhotosFromEntry(entry);
    final journal = entry['workoutJournal'];
    final programDay = programDayFromEntry(entry);

    return {
      'calendarEntryId': entryIdFromCalendarRecord(entry),
      'calendarEntryType': entry['type']?.toString(),
      'workoutStatus': programDay != null
          ? workoutStatusFromType(programDay['status']?.toString())
          : workoutStatusFromType(entry['type']?.toString()),
      'hasProgressPhoto': photos.isNotEmpty || hasProgressPhotosInEntry(entry),
      'progressPhotos': photos,
      'workout': workoutSummaryFromJournal(journal),
      'run': runSummaryFromRunningLogRaw(entry['runningLog']),
      'nutrition': nutrition,
      'notes': displayNotesFrom(entry['notes']?.toString()),
      if (programDay != null) 'program': programDay,
    };
  }

  static Map<String, dynamic>? nutritionSummaryFromApi(dynamic nutritionRaw) {
    if (nutritionRaw is! Map) return null;
    final nutrition = Map<String, dynamic>.from(nutritionRaw);
    final calories = nutrition['calories'];
    final macros = nutrition['macronutrients'];
    if (calories is! Map && macros is! Map) return null;

    final consumed = calories is Map ? _intFrom(calories['consumed']) ?? 0 : 0;
    final goal = calories is Map ? _intFrom(calories['goal']) ?? 0 : 0;

    double macroGrams(String key) {
      if (macros is! Map) return 0;
      final macro = macros[key];
      if (macro is! Map) return 0;
      final grams = macro['grams'];
      if (grams is num) return grams.toDouble();
      return double.tryParse(grams?.toString() ?? '') ?? 0;
    }

    final protein = macroGrams('protein');
    final carbs = macroGrams('carbs');
    final fats = macroGrams('fats');

    return {
      'calories': '$consumed/$goal',
      'protein': '${protein.round()}g',
      'carbs': '${carbs.round()}g',
      'fats': '${fats.round()}g',
    };
  }

  /// `GET /customer/calendar/:id` — full entry with nutrition for day detail view.
  Future<Map<String, dynamic>> fetchCalendarEntry(String calendarEntryId) async {
    final id = calendarEntryId.trim();
    if (!WorkoutRepository.isValidMongoId(id)) {
      throw Exception('Invalid calendar entry id');
    }

    final raw = await _network.get(AppUrl.customerCalendarById(id));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load calendar entry');
    }

    final root = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final data = root['data'];
    if (data is! Map) {
      throw Exception('Calendar entry not found');
    }

    final dataMap = Map<String, dynamic>.from(data);
    final entry = dataMap['entry'];
    if (entry is! Map) {
      throw Exception('Calendar entry not found');
    }

    return dayDataFromEntry(
      Map<String, dynamic>.from(entry),
      nutrition: nutritionSummaryFromApi(dataMap['nutrition']),
    );
  }

  static Map<DateTime, Map<String, dynamic>> dayDataMapFromEntries(List<dynamic> entries) {
    final map = <DateTime, Map<String, dynamic>>{};
    for (final item in entries) {
      if (item is! Map) continue;
      final entry = Map<String, dynamic>.from(item);
      if (entry['isDeleted'] == true) continue;
      map[dateKeyFromEntry(entry)] = dayDataFromEntry(entry);
    }
    expandProgramScheduleInMap(map);
    return map;
  }

  /// `POST /customer/calendar` — JSON when no files; multipart when [progressPhotoFiles] is set.
  Future<Map<String, dynamic>> createCalendarEntry({
    required DateTime date,
    required String type,
    String? notes,
    String? workoutJournal,
    String? runningLog,
    List<File>? progressPhotoFiles,
    String? progressPhotoType,
  }) async {
    final body = createEntryBody(date: date, type: type, notes: notes, workoutJournal: workoutJournal, runningLog: runningLog);
    if (progressPhotoType != null && progressPhotoType.trim().isNotEmpty) {
      body['progressPhotoType'] = progressPhotoType.trim().toLowerCase();
    }
    final files = progressPhotoFiles?.where((f) => f.path.isNotEmpty).toList() ?? const <File>[];

    final dynamic raw;
    if (files.isNotEmpty) {
      raw = await _network.postMultipart(
        url: AppUrl.customerCalendarCreate,
        fields: body,
        files: {'progressPhotos': files},
      );
    } else {
      raw = await _network.post(AppUrl.customerCalendarCreate, body);
    }

    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not create calendar entry');
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  static Map<String, dynamic> updateEntryBody({String? notes, String? type, String? runningLog}) {
    final body = <String, dynamic>{};
    if (notes != null) body['notes'] = notes.trim();
    if (type != null && type.trim().isNotEmpty) body['type'] = type.trim();
    if (runningLog != null && WorkoutRepository.isValidMongoId(runningLog)) {
      body['runningLog'] = runningLog.trim();
    }
    return body;
  }

  /// `PUT /customer/calendar/:id` — update notes, type, runningLog, and/or append progress photos.
  Future<Map<String, dynamic>> updateCalendarEntry({
    required String calendarEntryId,
    String? notes,
    String? type,
    String? runningLog,
    List<File>? progressPhotoFiles,
    String? progressPhotoType,
  }) async {
    final id = calendarEntryId.trim();
    if (!WorkoutRepository.isValidMongoId(id)) {
      throw Exception('Invalid calendar entry id');
    }

    final body = updateEntryBody(notes: notes, type: type, runningLog: runningLog);
    if (progressPhotoType != null && progressPhotoType.trim().isNotEmpty) {
      body['progressPhotoType'] = progressPhotoType.trim().toLowerCase();
    }
    final files = progressPhotoFiles?.where((f) => f.path.isNotEmpty).toList() ?? const <File>[];

    final dynamic raw;
    if (files.isNotEmpty) {
      raw = await _network.putMultipart(
        url: AppUrl.customerCalendarById(id),
        fields: body,
        files: {'progressPhotos': files},
      );
    } else {
      raw = await _network.put(AppUrl.customerCalendarById(id), body);
    }

    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not update calendar entry');
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  /// `DELETE /customer/calendar/:id` — remove a calendar entry.
  Future<Map<String, dynamic>> deleteCalendarEntry({required String calendarEntryId}) async {
    final id = calendarEntryId.trim();
    if (!WorkoutRepository.isValidMongoId(id)) {
      throw Exception('Invalid calendar entry id');
    }

    final raw = await _network.delete(AppUrl.customerCalendarById(id));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not delete calendar entry');
    }
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  static Map<String, dynamic> mapProgramBody({
    required String enrollmentId,
    required String programId,
    required DateTime startDate,
  }) {
    return {
      'enrollmentId': enrollmentId.trim(),
      'programId': programId.trim(),
      'startDate': dateToApiIso(startDate),
    };
  }

  /// `POST /customer/calendar/program/map` — map enrolled program workout days to calendar.
  Future<Map<String, dynamic>> mapProgramToCalendar({
    required String enrollmentId,
    required String programId,
    required DateTime startDate,
  }) async {
    final enrollment = enrollmentId.trim();
    final program = programId.trim();
    if (!WorkoutRepository.isValidMongoId(enrollment)) {
      throw Exception('Invalid enrollment id');
    }
    if (!WorkoutRepository.isValidMongoId(program)) {
      throw Exception('Invalid program id');
    }

    final raw = await _network.post(
      AppUrl.customerCalendarProgramMap,
      mapProgramBody(enrollmentId: enrollment, programId: program, startDate: startDate),
    );

    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not add program to calendar');
    }
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  static Map<String, dynamic> moveProgramBody({
    required String calendarEntryId,
    required DateTime targetDate,
  }) {
    return {
      'calendarEntryId': calendarEntryId.trim(),
      'targetDate': dateToApiIso(targetDate),
    };
  }

  /// `POST /customer/calendar/program/move` — move a mapped program workout to another date.
  Future<Map<String, dynamic>> moveProgramWorkout({
    required String calendarEntryId,
    required DateTime targetDate,
  }) async {
    final id = calendarEntryId.trim();
    if (!WorkoutRepository.isValidMongoId(id)) {
      throw Exception('Invalid calendar entry id');
    }

    final raw = await _network.post(
      AppUrl.customerCalendarProgramMove,
      moveProgramBody(calendarEntryId: id, targetDate: targetDate),
    );

    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not move program workout');
    }
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  /// Links a completed run log to the calendar day (`PUT` or `POST /customer/calendar` with `runningLog`).
  Future<Map<String, dynamic>> attachRunningLogToCalendar({
    required DateTime date,
    required String runningLogId,
    String? calendarEntryId,
    String type = typeCompleted,
  }) async {
    final logId = runningLogId.trim();
    if (!WorkoutRepository.isValidMongoId(logId)) {
      throw Exception('Invalid running log id');
    }

    final runDate = normalizedDate(date);
    var entryId = _mongoId(calendarEntryId);

    if (entryId == null) {
      final month = await fetchCalendarMonth(year: runDate.year, month: runDate.month);
      entryId = entryIdForDate(month, runDate);
    }

    if (entryId != null) {
      return updateCalendarEntry(
        calendarEntryId: entryId,
        type: type,
        runningLog: logId,
      );
    }

    return createCalendarEntry(
      date: runDate,
      type: type,
      runningLog: logId,
    );
  }

  Future<Map<String, dynamic>> saveOrUpdateCalendarEntry({
    required DateTime date,
    String? calendarEntryId,
    required String type,
    String? notes,
    String? workoutJournal,
    List<File>? progressPhotoFiles,
  }) async {
    final existingId = _mongoId(calendarEntryId);
    if (existingId != null) {
      return updateCalendarEntry(
        calendarEntryId: existingId,
        notes: notes,
        progressPhotoFiles: progressPhotoFiles,
      );
    }

    return createCalendarEntry(
      date: date,
      type: type,
      notes: notes,
      workoutJournal: workoutJournal,
      progressPhotoFiles: progressPhotoFiles,
    );
  }

  static String? entryIdFrom(dynamic response) {
    if (response is! Map) return null;
    final root = Map<String, dynamic>.from(response);

    final direct = _mongoId(root['_id'] ?? root['id']);
    if (direct != null) return direct;

    final data = root['data'];
    if (data is Map) {
      final dm = Map<String, dynamic>.from(data);
      final fromData = _mongoId(dm['_id'] ?? dm['id']);
      if (fromData != null) return fromData;

      for (final key in ['calendar', 'entry', 'calendarEntry', 'result']) {
        final nested = dm[key];
        if (nested is Map) {
          final nestedId = _mongoId(Map<String, dynamic>.from(nested)['_id'] ?? Map<String, dynamic>.from(nested)['id']);
          if (nestedId != null) return nestedId;
        }
      }
    }
    return null;
  }

  static String? _mongoId(dynamic raw) {
    final id = raw?.toString().trim();
    if (id == null || id.isEmpty) return null;
    return WorkoutRepository.isValidMongoId(id) ? id : null;
  }

  static bool _isOk(dynamic response) {
    if (response is! Map) return false;
    final m = Map<String, dynamic>.from(response);
    if (m['success'] == true || m['success'] == 1) return true;
    final st = m['status'];
    return st == 200 || st == '200' || st == 201 || st == '201';
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
    }
    return null;
  }
}
