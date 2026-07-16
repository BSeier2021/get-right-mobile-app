import 'dart:convert';
import 'dart:io';

import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

class CalendarRepository {
  final _network = NetworkApiService();

  static const String typeCompleted = 'Completed';
  static const String typeIncomplete = 'Incomplete';
  /// UI-only; API accepts only Completed | Incomplete | Rest Day — persisted as [typeIncomplete].
  static const String typeInProgress = 'InProgress';
  static const String typeRest = 'Rest Day';

  static const String progressPhotoFrontField = 'progressPhotoFront';
  static const String progressPhotoBackField = 'progressPhotoBack';

  /// UI slot (`front` | `side`) → multipart field name on calendar API.
  static String progressPhotoFieldForSlot(String slot) {
    switch (slot.trim().toLowerCase()) {
      case 'front':
        return progressPhotoFrontField;
      case 'side':
      case 'back':
        return progressPhotoBackField;
      default:
        return progressPhotoFrontField;
    }
  }

  /// API `fieldName` / multipart key → UI slot (`front` | `side`).
  static String? progressPhotoSlotFromFieldName(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower == progressPhotoFrontField.toLowerCase() || lower.contains('front')) return 'front';
    if (lower == progressPhotoBackField.toLowerCase() || lower.contains('back') || lower.contains('side')) {
      return 'side';
    }
    return null;
  }

  static Map<String, List<File>> progressPhotoMultipartFiles({
    required List<File> files,
    required String slot,
  }) {
    final valid = files.where((f) => f.path.isNotEmpty).toList();
    if (valid.isEmpty) return const {};
    return {progressPhotoFieldForSlot(slot): valid};
  }

  /// Maps app / legacy calendar types to API enum values.
  static String calendarTypeForApi(String type) {
    switch (type.trim()) {
      case typeCompleted:
        return typeCompleted;
      case typeIncomplete:
        return typeIncomplete;
      case typeRest:
        return typeRest;
      case typeInProgress:
        return typeIncomplete;
      default:
        final lower = type.trim().toLowerCase();
        if (lower == 'rest') return typeRest;
        if (lower == 'rest day') return typeRest;
        if (lower == 'inprogress' || lower == 'in progress') return typeIncomplete;
        if (lower == 'completed') return typeCompleted;
        if (lower == 'incomplete') return typeIncomplete;
        return type.trim();
    }
  }

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

  static bool typeRequiresDuration(String? type) {
    if (type == null) return false;
    return calendarTypeForApi(type).toLowerCase() == 'completed';
  }

  /// Seconds to send when marking a calendar day `Completed` (workout journal, run, or fallback).
  static int durationSecondsForDayComplete(Map<String, dynamic>? dayData) {
    if (dayData != null) {
      final workout = dayData['workout'];
      if (workout is Map) {
        final secs = _intFrom(workout['durationSeconds']);
        if (secs != null && secs > 0) return secs;
      }

      final runs = runsFromDayData(dayData);
      if (runs.isNotEmpty) {
        var total = 0;
        for (final run in runs) {
          final secs = _intFrom(run['durationSeconds']);
          if (secs != null && secs > 0) total += secs;
        }
        if (total > 0) return total;
      }

      final run = dayData['run'];
      if (run is Map) {
        final secs = _intFrom(run['durationSeconds']);
        if (secs != null && secs > 0) return secs;
      }
    }
    return 60;
  }

  static void applyDurationForCompletedType(Map<String, dynamic> body, String? type, int? durationInSeconds) {
    final effectiveType = type ?? body['type']?.toString();
    if (!typeRequiresDuration(effectiveType)) return;
    final secs = durationInSeconds ?? _intFrom(body['duration']) ?? _intFrom(body['durationInSeconds']) ?? 0;
    if (secs <= 0) {
      throw Exception('Duration in seconds is required when marking workout as complete');
    }
    body.remove('durationInSeconds');
    body['duration'] = secs;
  }

  static Map<String, dynamic> createEntryBody({
    required DateTime date,
    required String type,
    String? notes,
    String? workoutJournal,
    String? runningLog,
    int? durationInSeconds,
  }) {
    final body = <String, dynamic>{
      'date': dateToApiIso(date),
      'type': calendarTypeForApi(type),
    };
    if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes.trim();
    if (workoutJournal != null && WorkoutRepository.isValidMongoId(workoutJournal)) {
      body['workoutJournal'] = workoutJournal.trim();
    }
    if (runningLog != null && WorkoutRepository.isValidMongoId(runningLog)) {
      body['runningLog'] = runningLog.trim();
    }
    applyDurationForCompletedType(body, type, durationInSeconds);
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
      case 'rest day':
        return 'rest';
      default:
        return 'completed';
    }
  }

  static bool isRestDayData(Map<String, dynamic>? data) {
    if (data == null) return false;
    final entryType = data['calendarEntryType']?.toString();
    if (workoutStatusFromType(entryType) == 'rest') return true;
    return data['workoutStatus']?.toString() == 'rest';
  }

  static bool isCompletedDayData(Map<String, dynamic>? data) {
    if (data == null) return false;
    final entryType = data['calendarEntryType']?.toString();
    if (workoutStatusFromType(entryType) == 'completed') return true;
    return data['workoutStatus']?.toString() == 'completed';
  }

  static Map<String, dynamic> applyRestDayToDayData(Map<String, dynamic> data) {
    final updated = Map<String, dynamic>.from(data);
    updated['calendarEntryType'] = typeRest;
    updated['workoutStatus'] = 'rest';
    final program = updated['program'];
    if (program is Map) {
      updated['program'] = Map<String, dynamic>.from(program)..['status'] = 'rest';
    }
    return updated;
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

  static double distanceKmFromRunningLogValue(dynamic distanceRaw) {
    final raw = (distanceRaw as num?)?.toDouble() ?? 0.0;
    if (raw <= 0) return 0;
    if (raw >= 1000) return raw / 1000;
    return raw;
  }

  static List<Map<String, dynamic>> runSummariesFromEntryRunningLog(dynamic runningLogRaw) {
    final items = <dynamic>[];
    if (runningLogRaw is List) {
      items.addAll(runningLogRaw);
    } else if (runningLogRaw != null) {
      items.add(runningLogRaw);
    }

    final runs = <Map<String, dynamic>>[];
    for (final item in items) {
      final summary = runSummaryFromRunningLogRaw(item);
      if (summary != null) runs.add(summary);
    }
    return runs;
  }

  static List<Map<String, dynamic>> runsFromDayData(Map<String, dynamic>? dayData) {
    if (dayData == null) return const [];
    final runs = dayData['runs'];
    if (runs is List) {
      return runs.whereType<Map>().map((run) => Map<String, dynamic>.from(run)).toList();
    }
    final run = dayData['run'];
    if (run is Map) return [Map<String, dynamic>.from(run)];
    return const [];
  }

  static Map<String, dynamic>? runSummaryFromRunningLogRaw(dynamic runningLogRaw) {
    if (runningLogRaw == null) return null;
    if (runningLogRaw is String) {
      final id = _mongoId(runningLogRaw);
      if (id == null) return null;
      return {
        'id': id,
        'distance': '0 km',
        'time': '0:00',
        'durationSeconds': 0,
        'pace': '--:-- /km',
        'calories': 0,
        'activityType': 'Run',
        'isPlannedRoute': false,
      };
    }
    if (runningLogRaw is! Map) return null;

    final log = Map<String, dynamic>.from(runningLogRaw);
    var distanceKm = distanceKmFromRunningLogValue(log['distance']);
    final durationSeconds = (log['duration'] as num?)?.toInt() ?? 0;
    double? averagePace;

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
      if (distanceKm <= 0) {
        final estimated = (routeMap['estimatedDistance'] as num?)?.toDouble();
        if (estimated != null && estimated > 0) {
          distanceKm = distanceKmFromRunningLogValue(estimated);
        }
      }
    }

    if (distanceKm > 0 && durationSeconds > 0) {
      averagePace = (durationSeconds / 60) / distanceKm;
    }

    final activityType = RunningLogRepository.activityTypeFromRunningType(
      log['runningType']?.toString() ?? log['activityType']?.toString() ?? 'Run',
    );
    final isPlannedRoute = routeId != null && durationSeconds <= 0 && distanceKm <= 0;
    final calories = _intFrom(log['caloriesBurned']) ?? _intFrom(log['calories']);

    return {
      'id': _mongoId(log['_id'] ?? log['id']),
      'distance': '${distanceKm.toStringAsFixed(2)} km',
      'time': formatDurationSeconds(durationSeconds),
      'durationSeconds': durationSeconds,
      'pace': formatPaceMinPerKm(averagePace),
      'calories': calories ?? 0,
      'activityType': activityType,
      if (routeId != null) 'routeId': routeId,
      'isPlannedRoute': isPlannedRoute,
    };
  }

  static Map<String, dynamic>? mergeRunSummaryWithStoredCalories(
    Map<String, dynamic>? runSummary,
    Map<String, int> caloriesByRunId,
  ) {
    if (runSummary == null || caloriesByRunId.isEmpty) return runSummary;
    final runId = runSummary['id']?.toString();
    if (runId == null || runId.isEmpty) return runSummary;

    final storedCalories = caloriesByRunId[runId];
    if (storedCalories == null || storedCalories <= 0) return runSummary;

    return Map<String, dynamic>.from(runSummary)..['calories'] = storedCalories;
  }

  static Map<String, dynamic> applyStoredRunCaloriesToDayData(
    Map<String, dynamic> dayData,
    Map<String, int> caloriesByRunId,
  ) {
    final runs = runsFromDayData(dayData);
    if (runs.isEmpty) return dayData;

    final mergedRuns = runs.map((run) {
      final merged = mergeRunSummaryWithStoredCalories(run, caloriesByRunId);
      return merged ?? run;
    }).toList();

    return Map<String, dynamic>.from(dayData)
      ..['runs'] = mergedRuns
      ..['run'] = mergedRuns.first;
  }

  static Map<DateTime, Map<String, dynamic>> applyStoredRunCalories(
    Map<DateTime, Map<String, dynamic>> map,
    Map<String, int> caloriesByRunId,
  ) {
    if (caloriesByRunId.isEmpty) return map;
    return map.map(
      (date, dayData) => MapEntry(date, applyStoredRunCaloriesToDayData(dayData, caloriesByRunId)),
    );
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
    if (entry[progressPhotoFrontField] != null || entry[progressPhotoBackField] != null) return true;
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

  static bool isGenericMediaLabel(String? raw) {
    final value = raw?.trim().toLowerCase() ?? '';
    if (value.isEmpty) return false;
    const generic = {'image', 'video', 'audio', 'file', 'document', 'photo'};
    return generic.contains(value);
  }

  static String? photoIdFrom(dynamic photo) {
    if (photo is! Map) return null;
    final map = Map<String, dynamic>.from(photo);
    final id = map['_id']?.toString() ?? map['id']?.toString();
    if (id != null && _looksLikeMongoId(id)) return id.trim();
    return null;
  }

  /// Front/side slot for a progress photo (`front` | `side`).
  static String? photoSlotFrom(dynamic photo, {int? index}) {
    if (photo is! Map) {
      if (index == null) return null;
      return index == 0 ? 'front' : index == 1 ? 'side' : null;
    }

    final map = Map<String, dynamic>.from(photo);
    final fromFieldName = progressPhotoSlotFromFieldName(map['fieldName']?.toString());
    if (fromFieldName != null) return fromFieldName;

    final slot = map['slot']?.toString().trim().toLowerCase();
    if (slot == 'front' || slot == 'side' || slot == 'back') return slot == 'back' ? 'side' : slot;

    for (final field in ['photoType', 'progressPhotoType', 'label']) {
      final raw = map[field]?.toString().trim().toLowerCase() ?? '';
      if (raw.isEmpty || isGenericMediaLabel(raw)) continue;
      if (raw.contains('back') || raw.contains('side')) return 'side';
      if (raw.contains('front')) return 'front';
    }

    final legacyType = map['type']?.toString().trim().toLowerCase() ?? '';
    if (!isGenericMediaLabel(legacyType)) {
      if (legacyType.contains('back') || legacyType.contains('side')) return 'side';
      if (legacyType.contains('front')) return 'front';
    }

    if (index != null && index <= 1) return index == 0 ? 'front' : 'side';
    return null;
  }

  static String normalizePhotoSlot(
    String? raw, {
    required int index,
    String? entryNotes,
    int? totalPhotos,
    String? entryPhotoType,
  }) {
    if (!isGenericMediaLabel(raw)) {
      final value = raw?.trim().toLowerCase() ?? '';
      if (value.contains('back') || value.contains('side')) return 'side';
      if (value.contains('front')) return 'front';
    }

    final count = totalPhotos ?? 1;
    if (count == 1) {
      final entryType = entryPhotoType?.trim().toLowerCase() ?? '';
      if (entryType.contains('back') || entryType.contains('side')) return 'side';
      if (entryType.contains('front')) return 'front';

      final notes = entryNotes?.toLowerCase() ?? '';
      if (notes.contains('back') || notes.contains('side')) return 'side';
      if (notes.contains('front')) return 'front';
    }

    return index == 0 ? 'front' : 'side';
  }

  static List<Map<String, dynamic>> _orderedProgressPhotos(Map<String, Map<String, dynamic>> bySlot) {
    final ordered = <Map<String, dynamic>>[];
    if (bySlot.containsKey('front')) ordered.add(bySlot['front']!);
    if (bySlot.containsKey('side')) ordered.add(bySlot['side']!);
    for (final entry in bySlot.entries) {
      if (entry.key == 'front' || entry.key == 'side') continue;
      ordered.add(entry.value);
    }
    return ordered;
  }

  static String? progressPhotoIdForSlot(dynamic photosRaw, String slot) {
    if (photosRaw is! List) return null;
    final target = slot.toLowerCase();
    for (var i = 0; i < photosRaw.length; i++) {
      final photo = photosRaw[i];
      if (photoSlotFrom(photo, index: i) != target) continue;
      final id = photoIdFrom(photo);
      if (id != null) return id;
    }
    return null;
  }

  static String? progressPhotoIdFromDayData(Map<String, dynamic>? dayData, String slot) {
    if (dayData == null) return null;
    final fromList = progressPhotoIdForSlot(dayData['progressPhotos'], slot);
    if (fromList != null) return fromList;

    final fieldKey = progressPhotoFieldForSlot(slot);
    return photoIdFrom(dayData[fieldKey]);
  }

  static void _putProgressPhotoInSlot(
    Map<String, Map<String, dynamic>> bySlot,
    dynamic photo, {
    required String defaultSlot,
    String? fieldName,
  }) {
    if (photo is String) {
      final url = photoUrlFrom(photo);
      if (url == null) return;
      final slot = progressPhotoSlotFromFieldName(fieldName) ?? defaultSlot;
      bySlot[slot] = {
        'url': url,
        'slot': slot,
        if (fieldName != null) 'fieldName': fieldName,
      };
      return;
    }

    if (photo is! Map) return;
    final map = Map<String, dynamic>.from(photo);
    final url = photoUrlFrom(map);
    if (url == null) return;
    final slot = photoSlotFrom(map) ?? progressPhotoSlotFromFieldName(map['fieldName']?.toString() ?? fieldName) ?? defaultSlot;
    bySlot[slot] = {
      ...map,
      'url': url,
      'slot': slot,
      'fieldName': map['fieldName'] ?? fieldName ?? progressPhotoFieldForSlot(slot),
    };
  }

  static List<Map<String, dynamic>> progressPhotosFromEntry(Map<String, dynamic> entry) {
    final bySlot = <String, Map<String, dynamic>>{};

    _putProgressPhotoInSlot(
      bySlot,
      entry[progressPhotoFrontField],
      defaultSlot: 'front',
      fieldName: progressPhotoFrontField,
    );
    _putProgressPhotoInSlot(
      bySlot,
      entry[progressPhotoBackField],
      defaultSlot: 'side',
      fieldName: progressPhotoBackField,
    );

    final photos = entry['progressPhotos'];
    if (photos is! List || photos.isEmpty) {
      return _orderedProgressPhotos(bySlot);
    }

    final entryNotes = entry['notes']?.toString();
    final entryPhotoType = entry['progressPhotoType']?.toString();

    for (var i = 0; i < photos.length; i++) {
      final photo = photos[i];
      if (photo is String) {
        final url = photoUrlFrom(photo);
        if (url == null) continue;
        final slot = normalizePhotoSlot(
          null,
          index: i,
          entryNotes: entryNotes,
          totalPhotos: photos.length,
          entryPhotoType: entryPhotoType,
        );
        if (bySlot.containsKey(slot)) continue;
        bySlot[slot] = {'url': url, 'slot': slot};
        continue;
      }

      if (photo is Map) {
        final map = Map<String, dynamic>.from(photo);
        final url = photoUrlFrom(map);
        if (url == null) continue;
        final slot = photoSlotFrom(map, index: i) ??
            normalizePhotoSlot(
              map['photoType']?.toString() ?? map['progressPhotoType']?.toString() ?? map['label']?.toString(),
              index: i,
              entryNotes: entryNotes,
              totalPhotos: photos.length,
              entryPhotoType: entryPhotoType,
            );
        bySlot[slot] = {
          ...map,
          'url': url,
          'slot': slot,
          'fieldName': map['fieldName'] ?? progressPhotoFieldForSlot(slot),
        };
      }
    }

    return _orderedProgressPhotos(bySlot);
  }

  static bool dayHasProgressPhotos(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['hasProgressPhoto'] == true) return true;
    if (data[progressPhotoFrontField] != null || data[progressPhotoBackField] != null) return true;
    final photos = data['progressPhotos'];
    return photos is List && photos.isNotEmpty;
  }

  static String? progressPhotoUrlForType(dynamic photosRaw, String type) {
    if (photosRaw is! List || photosRaw.isEmpty) return null;

    final target = type.toLowerCase();
    String? lastMatch;

    for (var i = 0; i < photosRaw.length; i++) {
      final photo = photosRaw[i];
      if (photoSlotFrom(photo, index: i) != target) continue;
      final url = photoUrlFrom(photo);
      if (url != null) lastMatch = url;
    }

    return lastMatch;
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

  static List<Map<String, dynamic>> mergeProgressPhotoLists(
    dynamic existingRaw,
    dynamic incomingRaw, {
    String? incomingPhotoType,
  }) {
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

    void absorb(dynamic raw, {required bool isIncoming}) {
      if (raw is! List) return;
      for (var i = 0; i < raw.length; i++) {
        final photo = raw[i];
        if (photo is String) {
          final url = photoUrlFrom(photo);
          if (url == null) continue;
          final key = isIncoming && incomingPhotoType != null && raw.length == 1
              ? incomingPhotoType.toLowerCase()
              : (i == 0 ? 'front' : i == 1 ? 'side' : 'photo_$i');
          put(key, {'url': url, 'slot': key});
          continue;
        }

        if (photo is! Map) continue;
        final map = Map<String, dynamic>.from(photo);
        final explicitKey = photoSlotFrom(map, index: i);
        final key = explicitKey ??
            (isIncoming && incomingPhotoType != null && raw.length == 1
                ? incomingPhotoType.toLowerCase()
                : (i == 0 ? 'front' : i == 1 ? 'side' : 'photo_$i'));
        put(key, {...map, 'slot': key});
      }
    }

    absorb(existingRaw, isIncoming: false);
    absorb(incomingRaw, isIncoming: true);
    return _orderedProgressPhotos(byType);
  }

  static List<Map<String, dynamic>> upsertProgressPhoto({
    required List<Map<String, dynamic>> photos,
    required String type,
    required Map<String, dynamic> replacement,
  }) {
    final target = type.toLowerCase();
    final bySlot = <String, Map<String, dynamic>>{};
    for (var i = 0; i < photos.length; i++) {
      final slot = photoSlotFrom(photos[i], index: i);
      if (slot == null || slot == target) continue;
      bySlot[slot] = Map<String, dynamic>.from(photos[i]);
    }
    bySlot[target] = {
      ...replacement,
      'slot': target,
      'fieldName': replacement['fieldName'] ?? progressPhotoFieldForSlot(target),
    };
    return _orderedProgressPhotos(bySlot);
  }

  static bool hasResolvableProgressPhotos(dynamic photosRaw) {
    if (photosRaw is! List || photosRaw.isEmpty) return false;
    for (final photo in photosRaw) {
      if (photoUrlFrom(photo) != null) return true;
    }
    return false;
  }

  static Map<String, dynamic> mergeDayData(
    Map<String, dynamic>? existing,
    Map<String, dynamic> incoming, {
    String? incomingProgressPhotoType,
  }) {
    if (existing == null) return incoming;

    final merged = Map<String, dynamic>.from(existing)..addAll(incoming);
    final existingPhotos = existing['progressPhotos'];
    final incomingPhotos = incoming['progressPhotos'];

    if (existingPhotos is List || incomingPhotos is List) {
      final combined = mergeProgressPhotoLists(
        existingPhotos,
        incomingPhotos,
        incomingPhotoType: incomingProgressPhotoType,
      );
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
      'caloriesBurned': _intFrom(programStub['caloriesBurned']) ?? 0,
      'programDate': programStub['date']?.toString(),
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

    Map<String, dynamic>? enrollment;
    var workoutDays = const <Map<String, dynamic>>[];
    if (program['enrollmentId'] is Map) {
      enrollment = Map<String, dynamic>.from(program['enrollmentId'] as Map);
      final nestedProgram = enrollment['program'];
      if (nestedProgram is Map) {
        workoutDays = parseWorkoutDaysList(nestedProgram['workoutDays']);
      }
    }

    if (exercises.isEmpty && workoutDays.isEmpty) {
      final status = program['status']?.toString().trim() ?? '';
      if (status.isEmpty && enrollment == null) return null;
    }

    final dayNumber = _intFrom(program['dayNumber']) ?? inferProgramDayNumber(exercises, workoutDays) ?? 1;

    return buildProgramDay(
      enrollment: enrollment,
      programStub: program,
      workoutDays: workoutDays,
      exercises: exercises,
      dayNumber: dayNumber,
      entryType: entry['type']?.toString(),
    );
  }

  static void enrichExistingProgramEntry(
    Map<DateTime, Map<String, dynamic>> map,
    DateTime date,
    List<Map<String, dynamic>> workoutDays,
  ) {
    final existing = map[date];
    if (existing == null) return;

    final existingProgram = existing['program'];
    if (existingProgram is! Map) return;

    final mergedProgram = Map<String, dynamic>.from(existingProgram);
    if (mergedProgram['workoutDays'] == null ||
        (mergedProgram['workoutDays'] is List && (mergedProgram['workoutDays'] as List).isEmpty)) {
      mergedProgram['workoutDays'] = workoutDays;
    }
    map[date] = mergeDayData(existing, {'program': mergedProgram});
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
      final templateProgram = Map<String, dynamic>.from(entries.first.value['program'] as Map);
      final workoutDays = parseWorkoutDaysList(templateProgram['workoutDays']);
      if (workoutDays.isEmpty) continue;

      for (final entry in entries) {
        final entryId = entry.value['calendarEntryId']?.toString();
        if (entryId == null || entryId.isEmpty) continue;
        enrichExistingProgramEntry(map, entry.key, workoutDays);
      }
    }
  }

  static Map<String, dynamic> dayDataFromEntry(Map<String, dynamic> entry, {Map<String, dynamic>? nutrition}) {
    final photos = progressPhotosFromEntry(entry);
    final journal = entry['workoutJournal'];
    final programDay = programDayFromEntry(entry);
    final entryWorkoutStatus = workoutStatusFromType(entry['type']?.toString());
    final isRestDay = entryWorkoutStatus == 'rest';

    Map<String, dynamic>? resolvedProgramDay = programDay;
    if (programDay != null && isRestDay) {
      resolvedProgramDay = Map<String, dynamic>.from(programDay)..['status'] = 'rest';
    }

    final runs = runSummariesFromEntryRunningLog(entry['runningLog']);

    return {
      'calendarEntryId': entryIdFromCalendarRecord(entry),
      'calendarEntryType': entry['type']?.toString(),
      'workoutStatus': isRestDay
          ? 'rest'
          : (resolvedProgramDay != null
              ? workoutStatusFromType(resolvedProgramDay['status']?.toString())
              : entryWorkoutStatus),
      'hasProgressPhoto': photos.isNotEmpty || hasProgressPhotosInEntry(entry),
      'progressPhotos': photos,
      'workout': workoutSummaryFromJournal(journal),
      if (runs.isNotEmpty) 'runs': runs,
      if (runs.isNotEmpty) 'run': runs.first,
      'nutrition': nutrition,
      'notes': displayNotesFrom(entry['notes']?.toString()),
      if (resolvedProgramDay != null) 'program': resolvedProgramDay,
    };
  }

  static Map<String, dynamic>? nutritionSummaryFromApi(dynamic nutritionRaw) {
    if (nutritionRaw is! Map) return null;
    final nutrition = Map<String, dynamic>.from(nutritionRaw);
    final calories = nutrition['calories'];
    final macros = nutrition['macronutrients'];
    if (calories is! Map && macros is! Map) return null;

    final consumed = calories is Map ? _intFrom(calories['consumed']) ?? 0 : 0;
    final burned = calories is Map ? _intFrom(calories['burned']) ?? 0 : 0;
    final goal = calories is Map ? _intFrom(calories['goal']) ?? 0 : 0;
    final remaining = calories is Map ? _intFrom(calories['remaining']) ?? 0 : 0;
    final progressPercent = calories is Map ? _intFrom(calories['progressPercent']) ?? 0 : 0;

    double macroGrams(String key) {
      if (macros is! Map) return 0;
      final macro = macros[key];
      if (macro is! Map) return 0;
      final grams = macro['grams'];
      if (grams is num) return grams.toDouble();
      return double.tryParse(grams?.toString() ?? '') ?? 0;
    }

    double macroPercent(String key) {
      if (macros is! Map) return 0;
      final macro = macros[key];
      if (macro is! Map) return 0;
      final percent = macro['percent'];
      if (percent is num) return percent.toDouble();
      return double.tryParse(percent?.toString() ?? '') ?? 0;
    }

    final protein = macroGrams('protein');
    final carbs = macroGrams('carbs');
    final fats = macroGrams('fats');

    return {
      'caloriesConsumed': consumed,
      'caloriesBurned': burned,
      'caloriesGoal': goal,
      'caloriesRemaining': remaining,
      'caloriesProgressPercent': progressPercent,
      'calories': '$consumed/$goal',
      'protein': '${protein.round()}g',
      'proteinGrams': protein.round(),
      'proteinPercent': macroPercent('protein').round(),
      'carbs': '${carbs.round()}g',
      'carbsGrams': carbs.round(),
      'carbsPercent': macroPercent('carbs').round(),
      'fats': '${fats.round()}g',
      'fatsGrams': fats.round(),
      'fatsPercent': macroPercent('fats').round(),
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

  /// `POST /customer/calendar` — JSON when no files; multipart uses `progressPhotoFront` / `progressPhotoBack`.
  Future<Map<String, dynamic>> createCalendarEntry({
    required DateTime date,
    required String type,
    String? notes,
    String? workoutJournal,
    String? runningLog,
    int? durationInSeconds,
    List<File>? progressPhotoFiles,
    String? progressPhotoType,
  }) async {
    final body = createEntryBody(
      date: date,
      type: type,
      notes: notes,
      workoutJournal: workoutJournal,
      runningLog: runningLog,
      durationInSeconds: durationInSeconds,
    );
    final files = progressPhotoFiles?.where((f) => f.path.isNotEmpty).toList() ?? const <File>[];
    final multipartFiles = progressPhotoType != null && files.isNotEmpty
        ? progressPhotoMultipartFiles(files: files, slot: progressPhotoType)
        : const <String, List<File>>{};

    final dynamic raw;
    if (multipartFiles.isNotEmpty) {
      raw = await _network.postMultipart(
        url: AppUrl.customerCalendarCreate,
        fields: body,
        files: multipartFiles,
      );
    } else {
      raw = await _network.post(AppUrl.customerCalendarCreate, body);
    }

    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not create calendar entry');
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  static Map<String, dynamic> updateEntryBody({
    String? notes,
    String? type,
    String? runningLog,
    String? workoutJournal,
    int? durationInSeconds,
  }) {
    final body = <String, dynamic>{};
    if (notes != null) body['notes'] = notes.trim();
    final resolvedType = type != null && type.trim().isNotEmpty ? calendarTypeForApi(type) : null;
    if (resolvedType != null) body['type'] = resolvedType;
    if (runningLog != null && WorkoutRepository.isValidMongoId(runningLog)) {
      body['runningLog'] = runningLog.trim();
    }
    if (workoutJournal != null && WorkoutRepository.isValidMongoId(workoutJournal)) {
      body['workoutJournal'] = workoutJournal.trim();
    }
    if (durationInSeconds != null && durationInSeconds > 0) {
      body.remove('durationInSeconds');
      body['duration'] = durationInSeconds;
    }
    applyDurationForCompletedType(body, resolvedType ?? type, durationInSeconds);
    if (body.isEmpty) throw Exception('Nothing to update');
    return body;
  }

  static String? workoutJournalIdFromDayData(Map<String, dynamic>? dayData) {
    if (dayData == null) return null;
    final workout = dayData['workout'];
    if (workout is! Map) return null;
    final journalId = Map<String, dynamic>.from(workout)['journalId']?.toString().trim();
    return WorkoutRepository.isValidMongoId(journalId) ? journalId : null;
  }

  /// `PUT /customer/calendar/:id` — update notes, type, runningLog, remove/replace progress photos.
  /// Multipart replace: `removeProgressPhotosIds` + `progressPhotoFront` or `progressPhotoBack` file field.
  Future<Map<String, dynamic>> updateCalendarEntry({
    required String calendarEntryId,
    String? notes,
    String? type,
    String? runningLog,
    String? workoutJournal,
    int? durationInSeconds,
    List<File>? progressPhotoFiles,
    String? progressPhotoType,
    List<String>? removeProgressPhotoIds,
  }) async {
    final id = calendarEntryId.trim();
    if (!WorkoutRepository.isValidMongoId(id)) {
      throw Exception('Invalid calendar entry id');
    }

    final files = progressPhotoFiles?.where((f) => f.path.isNotEmpty).toList() ?? const <File>[];
    final multipartFiles = progressPhotoType != null && files.isNotEmpty
        ? progressPhotoMultipartFiles(files: files, slot: progressPhotoType)
        : const <String, List<File>>{};

    Map<String, dynamic> body;
    try {
      body = updateEntryBody(
        notes: notes,
        type: type,
        runningLog: runningLog,
        workoutJournal: workoutJournal,
        durationInSeconds: durationInSeconds,
      );
    } catch (e) {
      if (multipartFiles.isEmpty) rethrow;
      body = <String, dynamic>{};
    }

    final removeIds = removeProgressPhotoIds?.map((e) => e.trim()).where(WorkoutRepository.isValidMongoId).toList() ?? const <String>[];
    if (removeIds.isNotEmpty) {
      body['removeProgressPhotosIds'] = jsonEncode(removeIds);
    }
    final dynamic raw;
    if (multipartFiles.isNotEmpty) {
      raw = await _network.putMultipart(
        url: AppUrl.customerCalendarById(id),
        fields: body,
        files: multipartFiles,
      );
    } else {
      raw = await _network.put(AppUrl.customerCalendarById(id), body);
    }

    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not update calendar entry');
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  static Map<String, dynamic> completeProgramWorkoutBody({
    required int durationSeconds,
    int? caloriesBurned,
    String? workoutJournalId,
  }) {
    if (durationSeconds <= 0) {
      throw Exception('Duration in seconds is required when marking workout as complete');
    }

    final program = <String, dynamic>{
      'duration': durationSeconds,
      'status': 'completed',
    };
    if (caloriesBurned != null && caloriesBurned > 0) {
      program['caloriesBurned'] = caloriesBurned;
    }

    final body = <String, dynamic>{
      'type': calendarTypeForApi(typeCompleted),
      'program': program,
    };
    if (workoutJournalId != null && WorkoutRepository.isValidMongoId(workoutJournalId)) {
      body['workoutJournal'] = workoutJournalId.trim();
    }
    return body;
  }

  /// Marks a mapped program workout complete on its calendar entry.
  /// API expects duration under `program.duration`, not top-level `duration`.
  Future<Map<String, dynamic>> completeProgramWorkoutOnCalendar({
    required String calendarEntryId,
    required int durationSeconds,
    int? caloriesBurned,
    String? workoutJournalId,
  }) async {
    final id = calendarEntryId.trim();
    if (!WorkoutRepository.isValidMongoId(id)) {
      throw Exception('Invalid calendar entry id');
    }

    final body = completeProgramWorkoutBody(
      durationSeconds: durationSeconds,
      caloriesBurned: caloriesBurned,
      workoutJournalId: workoutJournalId,
    );
    final raw = await _network.put(AppUrl.customerCalendarById(id), body);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not complete program workout');
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

  /// Links a workout journal to the calendar day (`PUT` or `POST /customer/calendar` with `workoutJournal`).
  Future<Map<String, dynamic>> attachWorkoutJournalToCalendar({
    required DateTime date,
    required String workoutJournalId,
    String type = typeIncomplete,
    int? durationInSeconds,
  }) async {
    final journalId = workoutJournalId.trim();
    if (!WorkoutRepository.isValidMongoId(journalId)) {
      throw Exception('Invalid workout journal id');
    }

    final day = normalizedDate(date);
    final month = await fetchCalendarMonth(year: day.year, month: day.month);
    final dayData = dayDataForDate(month, day);
    final existingJournalId = workoutJournalIdFromDayData(dayData);
    if (existingJournalId == journalId) {
      return <String, dynamic>{};
    }

    final entryId = entryIdForDate(month, day);
    if (entryId != null) {
      return updateCalendarEntry(
        calendarEntryId: entryId,
        type: type,
        workoutJournal: journalId,
        durationInSeconds: typeRequiresDuration(type) ? (durationInSeconds ?? durationSecondsForDayComplete(dayData)) : null,
      );
    }

    return createCalendarEntry(
      date: day,
      type: type,
      workoutJournal: journalId,
      durationInSeconds: typeRequiresDuration(type) ? (durationInSeconds ?? durationSecondsForDayComplete(dayData)) : null,
    );
  }

  /// `DELETE /customer/calendar/:id/running-logs/:runningLogId` — unlink one run from a day (log remains).
  Future<Map<String, dynamic>?> unlinkRunningLogFromCalendar({
    required String calendarEntryId,
    required String runningLogId,
  }) async {
    final entryId = calendarEntryId.trim();
    final logId = runningLogId.trim();
    if (!WorkoutRepository.isValidMongoId(entryId) || !WorkoutRepository.isValidMongoId(logId)) {
      throw Exception('Invalid calendar entry or running log id');
    }

    final raw = await _network.delete(AppUrl.customerCalendarUnlinkRunningLog(entryId, logId));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not remove run from calendar day');
    }
    return dayDataFromMutationResponse(raw);
  }

  /// Links a completed run log to the calendar day (`PUT` or `POST /customer/calendar` with `runningLog`).
  Future<Map<String, dynamic>> attachRunningLogToCalendar({
    required DateTime date,
    required String runningLogId,
    String? calendarEntryId,
    String type = typeCompleted,
    int? durationInSeconds,
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
        durationInSeconds: typeRequiresDuration(type) ? durationInSeconds : null,
      );
    }

    return createCalendarEntry(
      date: runDate,
      type: type,
      runningLog: logId,
      durationInSeconds: typeRequiresDuration(type) ? durationInSeconds : null,
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
