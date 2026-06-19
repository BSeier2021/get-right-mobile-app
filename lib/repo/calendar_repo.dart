import 'dart:io';

import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/repo/workout_repo.dart';

class CalendarRepository {
  final _network = NetworkApiService();

  static const String typeCompleted = 'Completed';
  static const String typeIncomplete = 'Incomplete';
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
  }) {
    final body = <String, dynamic>{
      'date': dateToApiIso(date),
      'type': type.trim(),
    };
    if (notes != null && notes.trim().isNotEmpty) body['notes'] = notes.trim();
    if (workoutJournal != null && WorkoutRepository.isValidMongoId(workoutJournal)) {
      body['workoutJournal'] = workoutJournal.trim();
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

  static DateTime dateKeyFromEntry(Map<String, dynamic> entry) {
    final year = _intFrom(entry['year']);
    final month = _intFrom(entry['month']);
    final day = _intFrom(entry['day']);
    if (year != null && month != null && day != null) {
      return DateTime(year, month, day);
    }

    final parsed = DateTime.tryParse(entry['date']?.toString() ?? '');
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    return DateTime.now();
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
    final calories = durationSeconds > 0 ? (durationSeconds / 60 * 5).round() : 0;
    final parsedWorkouts = journalWorkoutsFromJournal(journal);

    return {
      'duration': formatDurationSeconds(durationSeconds),
      'exercises': parsedWorkouts.length,
      'sets': setCount,
      'calories': calories,
      'journalId': journal['_id']?.toString(),
      'notes': journal['notes']?.toString().trim() ?? '',
      'journalDate': journal['date']?.toString(),
      'workouts': parsedWorkouts,
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
          final setMap = Map<String, dynamic>.from(setRaw);
          sets.add({
            'setNumber': _intFrom(setMap['sets']) ?? (i + 1),
            'reps': setMap['reps']?.toString() ?? '-',
            'weight': setMap['weight']?.toString() ?? '-',
            'restTime': _intFrom(setMap['restTime']),
          });
        }
      }

      result.add({
        'id': workout['_id']?.toString(),
        'name': name,
        'iconUrl': exerciseIconUrlFromWorkout(workout),
        'sets': sets,
      });
    }
    return result;
  }

  static bool hasProgressPhotosInEntry(Map<String, dynamic> entry) {
    final photos = entry['progressPhotos'];
    return photos is List && photos.isNotEmpty;
  }

  static String? photoUrlFrom(dynamic photo) {
    if (photo is String) {
      final value = photo.trim();
      return value.isNotEmpty && value != 'null' ? value : null;
    }
    if (photo is! Map) return null;

    final map = Map<String, dynamic>.from(photo);
    for (final key in ['url', 'imageUrl', 'fileUrl', 'photoUrl', 'path', 'src', 'secureUrl']) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty && value != 'null') return value;
    }

    final file = map['file'];
    if (file is Map) {
      final nested = photoUrlFrom(file);
      if (nested != null) return nested;
    }

    final media = map['media'];
    if (media is Map) return photoUrlFrom(media);

    return null;
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
            map['type']?.toString() ?? map['photoType']?.toString() ?? map['label']?.toString(),
            index: i,
            entryNotes: entryNotes,
          ),
        });
      }
    }

    return result;
  }

  static String? progressPhotoUrlForType(dynamic photosRaw, String type) {
    if (photosRaw is! List || photosRaw.isEmpty) return null;

    final target = type.toLowerCase();
    for (final photo in photosRaw) {
      if (photo is! Map) continue;
      final map = Map<String, dynamic>.from(photo);
      final photoType = map['type']?.toString().toLowerCase() ?? '';
      if (photoType.contains(target)) {
        return photoUrlFrom(map);
      }
    }

    final fallbackIndex = target == 'front' ? 0 : 1;
    if (fallbackIndex < photosRaw.length) {
      return photoUrlFrom(photosRaw[fallbackIndex]);
    }
    return null;
  }

  static String mergePhotoTypeNotes(String? existing, String type) {
    final tag = '$type progress photo';
    final base = existing?.trim() ?? '';
    if (base.isEmpty) return tag;
    if (base.toLowerCase().contains(type.toLowerCase())) return base;
    return '$base · $tag';
  }

  static List<Map<String, dynamic>> programExercisesFrom(dynamic exercisesRaw) {
    if (exercisesRaw is! List) return const [];
    return exercisesRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Map<String, dynamic>? programDayFromEntry(Map<String, dynamic> entry) {
    final programRaw = entry['program'];
    if (programRaw is! Map) return null;
    final program = Map<String, dynamic>.from(programRaw);
    final exercises = programExercisesFrom(program['exercises']);
    if (exercises.isEmpty) return null;

    var totalSets = 0;
    for (final ex in exercises) {
      totalSets += _intFrom(ex['numberOfSets']) ?? 0;
    }

    String? title;
    String? difficulty;
    int? durationWeeks;
    String? enrollmentId;
    final enrollment = program['enrollmentId'];
    if (enrollment is Map) {
      enrollmentId = enrollment['_id']?.toString();
      final nestedProgram = enrollment['program'];
      if (nestedProgram is Map) {
        final nested = Map<String, dynamic>.from(nestedProgram);
        title = nested['title']?.toString();
        difficulty = nested['difficultyLevel']?.toString();
        durationWeeks = _intFrom(nested['duration']);
      }
    }

    final status = program['status']?.toString().trim().isNotEmpty == true ? program['status']?.toString() : entry['type']?.toString();

    return {
      'title': title ?? 'Program Workout',
      'status': status ?? '',
      'difficulty': difficulty ?? '',
      'durationWeeks': durationWeeks ?? 0,
      'exercises': exercises,
      'exerciseCount': exercises.length,
      'totalSets': totalSets,
      'programId': program['programId']?.toString(),
      'enrollmentId': enrollmentId,
    };
  }

  static Map<String, dynamic> dayDataFromEntry(Map<String, dynamic> entry, {Map<String, dynamic>? nutrition}) {
    final photos = progressPhotosFromEntry(entry);
    final journal = entry['workoutJournal'];
    final programDay = programDayFromEntry(entry);

    return {
      'calendarEntryId': entry['_id']?.toString(),
      'workoutStatus': workoutStatusFromType(entry['type']?.toString()),
      'hasProgressPhoto': hasProgressPhotosInEntry(entry),
      'progressPhotos': photos,
      'workout': workoutSummaryFromJournal(journal),
      'run': null,
      'nutrition': nutrition,
      'notes': entry['notes']?.toString().trim() ?? '',
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
    return map;
  }

  /// `POST /customer/calendar` — JSON when no files; multipart when [progressPhotoFiles] is set.
  Future<Map<String, dynamic>> createCalendarEntry({
    required DateTime date,
    required String type,
    String? notes,
    String? workoutJournal,
    List<File>? progressPhotoFiles,
  }) async {
    final body = createEntryBody(date: date, type: type, notes: notes, workoutJournal: workoutJournal);
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

  static Map<String, dynamic> updateEntryBody({String? notes, String? type}) {
    final body = <String, dynamic>{};
    if (notes != null) body['notes'] = notes.trim();
    if (type != null && type.trim().isNotEmpty) body['type'] = type.trim();
    return body;
  }

  /// `PUT /customer/calendar/:id` — update notes, type, and/or append progress photos.
  Future<Map<String, dynamic>> updateCalendarEntry({
    required String calendarEntryId,
    String? notes,
    String? type,
    List<File>? progressPhotoFiles,
  }) async {
    final id = calendarEntryId.trim();
    if (!WorkoutRepository.isValidMongoId(id)) {
      throw Exception('Invalid calendar entry id');
    }

    final body = updateEntryBody(notes: notes, type: type);
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

  static String? entryIdForDate(Map<DateTime, Map<String, dynamic>> dayData, DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    return _mongoId(dayData[key]?['calendarEntryId']);
  }

  /// Creates a new entry or updates an existing one when [calendarEntryId] is provided.
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
