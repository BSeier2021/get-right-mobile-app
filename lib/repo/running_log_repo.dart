import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get_right/app_url.dart';
import 'package:get_right/models/planned_route_model.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/repo/workout_repo.dart';
import 'package:get_right/utils/route_location_helper.dart';
import 'package:get_right/utils%20copy/utils.dart';

class PlannedRouteListPage {
  const PlannedRouteListPage({
    required this.routes,
    required this.page,
    required this.limit,
    this.totalDocs = 0,
    this.hasNextPage = false,
    this.syncFailed = false,
    this.syncError,
  });

  final List<PlannedRouteModel> routes;
  final int page;
  final int limit;
  final int totalDocs;
  final bool hasNextPage;
  final bool syncFailed;
  final String? syncError;
}

class RunningLogListPage {
  const RunningLogListPage({
    required this.runs,
    required this.page,
    required this.limit,
    this.totalDocs = 0,
    this.hasNextPage = false,
    this.syncFailed = false,
    this.syncError,
  });

  final List<RunModel> runs;
  final int page;
  final int limit;
  final int totalDocs;
  final bool hasNextPage;
  final bool syncFailed;
  final String? syncError;
}

class RunningLogRepository {
  final _network = NetworkApiService();

  /// Maps local activity keys (`walk`, `jog`, `run`, `bike`) to API `runningType` values.
  static String runningTypeFromActivity(String activityType) {
    switch (activityType.toLowerCase()) {
      case 'walk':
        return 'Walk';
      case 'jog':
        return 'Jog';
      case 'bike':
      case 'cycle':
        return 'Cycle';
      case 'other':
        return 'Other';
      case 'run':
      default:
        return 'Run';
    }
  }

  /// Maps API `runningType` values back to local UI activity labels.
  static String activityTypeFromRunningType(String runningType) {
    switch (runningType.toLowerCase()) {
      case 'walk':
        return 'Walk';
      case 'jog':
        return 'Jog';
      case 'cycle':
      case 'bike':
        return 'Bike';
      case 'other':
        return 'Other';
      case 'run':
      default:
        return 'Run';
    }
  }

  /// `GET /customer/planned-routes` — paginated saved routes.
  Future<PlannedRouteListPage> fetchPlannedRoutes({int page = 1, int limit = 10}) async {
    try {
      final raw = await _network.get(AppUrl.customerPlannedRoutesList(page: page, limit: limit));
      if (!_isOk(raw)) {
        throw Exception(_messageFrom(raw) ?? 'Could not load saved routes');
      }

      final routes = <PlannedRouteModel>[];
      var totalDocs = 0;
      var hasNextPage = false;

      if (raw is Map) {
        final data = raw['data'];
        if (data is Map) {
          final dm = Map<String, dynamic>.from(data);
          totalDocs = (dm['totalDocs'] as num?)?.toInt() ?? 0;
          hasNextPage = dm['hasNextPage'] == true;
          final items = dm['routes'];
          if (items is List) {
            for (final item in items) {
              if (item is Map) {
                routes.add(plannedRouteFromApi(Map<String, dynamic>.from(item)));
              }
            }
          }
        }
      }

      return PlannedRouteListPage(
        routes: routes,
        page: page,
        limit: limit,
        totalDocs: totalDocs,
        hasNextPage: hasNextPage,
      );
    } on ServerException catch (e) {
      return PlannedRouteListPage(routes: [], page: page, limit: limit, syncFailed: true, syncError: e.message);
    }
  }

  /// `GET /customer/running-logs` — paginated completed runs.
  Future<RunningLogListPage> fetchRunningLogs({int page = 1, int limit = 10}) async {
    try {
      final raw = await _network.get(AppUrl.customerRunningLogsList(page: page, limit: limit));
      if (!_isOk(raw)) {
        throw Exception(_messageFrom(raw) ?? 'Could not load running history');
      }

      final runs = <RunModel>[];
      var totalDocs = 0;
      var hasNextPage = false;

      if (raw is Map) {
        final data = raw['data'];
        if (data is Map) {
          final dm = Map<String, dynamic>.from(data);
          totalDocs = (dm['totalDocs'] as num?)?.toInt() ?? 0;
          hasNextPage = dm['hasNextPage'] == true;
          final items = dm['logs'];
          if (items is List) {
            for (final item in items) {
              if (item is Map) {
                runs.add(runModelFromApiLog(Map<String, dynamic>.from(item)));
              }
            }
          }
        }
      }

      return RunningLogListPage(
        runs: runs,
        page: page,
        limit: limit,
        totalDocs: totalDocs,
        hasNextPage: hasNextPage,
      );
    } on ServerException catch (e) {
      return RunningLogListPage(runs: [], page: page, limit: limit, syncFailed: true, syncError: e.message);
    }
  }

  static String? routeIdFromRunningLogJson(Map<String, dynamic> log) {
    final routeRaw = log['route'];
    if (routeRaw is String && WorkoutRepository.isValidMongoId(routeRaw)) {
      return routeRaw.trim();
    }
    if (routeRaw is Map) {
      final routeMap = Map<String, dynamic>.from(routeRaw);
      final nested = routeMap['_id'] ?? routeMap['id'];
      if (WorkoutRepository.isValidMongoId(nested?.toString())) {
        return nested.toString().trim();
      }
    }
    return null;
  }

  /// Resolves the planned-route id linked to a running log.
  Future<String?> fetchRouteIdForRunningLog(String logId) async {
    final raw = await _network.get(AppUrl.customerRunningLogById(logId.trim()));
    if (!_isOk(raw) || raw is! Map) return null;

    final data = raw['data'];
    if (data is! Map) return null;
    final log = Map<String, dynamic>.from(data)['log'];
    if (log is! Map) return null;
    return routeIdFromRunningLogJson(Map<String, dynamic>.from(log));
  }

  /// `GET /customer/running-logs/:logId` — single completed run.
  Future<RunModel> fetchRunningLogDetail(String logId) async {
    final raw = await _network.get(AppUrl.customerRunningLogById(logId));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load run details');
    }
    if (raw is Map) {
      final data = raw['data'];
      if (data is Map) {
        final log = Map<String, dynamic>.from(data)['log'];
        if (log is Map) {
          return runModelFromApiLog(Map<String, dynamic>.from(log));
        }
      }
    }
    throw Exception('Could not load run details');
  }

  /// `GET /customer/planned-routes/:routeId` — single saved route.
  Future<PlannedRouteModel> fetchPlannedRouteDetail(String routeId) async {
    final raw = await _network.get(AppUrl.customerPlannedRouteById(routeId));
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not load route details');
    }
    if (raw is Map) {
      final data = raw['data'];
      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        final routeRaw = dm['route'] ?? dm;
        if (routeRaw is Map) {
          return plannedRouteFromApi(Map<String, dynamic>.from(routeRaw));
        }
      }
    }
    throw Exception('Could not load route details');
  }

  /// Maps one route from `GET /customer/planned-routes`.
  static PlannedRouteModel plannedRouteFromApi(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now();
    final parsed = RouteLocationHelper.parseApiLocation(json['location']);
    final points = parsed.points.isNotEmpty ? parsed.points : latLngFromApiLocation(json['location']);
    final distance = _estimatedDistanceMeters(points);

    return PlannedRouteModel(
      id: id,
      name: 'Saved Route',
      routePoints: points,
      estimatedDistance: distance,
      createdAt: createdAt,
      isSaved: true,
      startPointName: parsed.startName,
      endPointName: parsed.endName,
    );
  }

  /// Maps one log from `GET /customer/running-logs`.
  static RunModel runModelFromApiLog(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final userRaw = json['user'];
    final userId = userRaw is Map
        ? (userRaw['_id']?.toString() ?? '')
        : userRaw?.toString() ?? '';
    final activityType = activityTypeFromRunningType(json['runningType']?.toString() ?? 'Run');
    var distanceMeters = (json['distance'] as num?)?.toDouble() ?? 0.0;
    final durationSeconds = (json['duration'] as num?)?.toInt() ?? 0;
    final startTime = DateTime.tryParse(json['startTime']?.toString() ?? '') ?? DateTime.now();
    final endTime = DateTime.tryParse(json['endTime']?.toString() ?? '') ?? startTime;
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? startTime;

    List<LocationPoint>? routePoints;
    String? startPointName;
    String? endPointName;
    final route = json['route'];
    if (route is Map) {
      final routeMap = Map<String, dynamic>.from(route);
      final parsed = RouteLocationHelper.parseApiLocation(routeMap['location']);
      if (parsed.points.isNotEmpty) {
        routePoints = parsed.points
            .map((point) => LocationPoint(latitude: point.latitude, longitude: point.longitude, timestamp: DateTime.now()))
            .toList();
        startPointName = parsed.startName;
        endPointName = parsed.endName;
      } else {
        routePoints = locationPointsFromApi(routeMap['location']);
      }
      if (distanceMeters <= 0) {
        final estimated = (routeMap['estimatedDistance'] as num?)?.toDouble();
        if (estimated != null && estimated > 0) {
          distanceMeters = estimated;
        }
      }
    }
    if (routePoints != null && routePoints.isEmpty) routePoints = null;

    double? averagePace;
    if (distanceMeters > 0 && durationSeconds > 0) {
      averagePace = (durationSeconds / 60) / (distanceMeters / 1000);
    }

    return RunModel(
      id: id,
      userId: userId,
      activityType: activityType,
      distanceMeters: distanceMeters,
      duration: Duration(seconds: durationSeconds),
      startTime: startTime,
      endTime: endTime,
      routePoints: routePoints,
      elevationGain: (json['elevationGain'] as num?)?.toDouble(),
      averagePace: averagePace,
      maxPace: null,
      maxSpeed: (json['averageSpeed'] as num?)?.toDouble(),
      caloriesBurned: (json['caloriesBurned'] as num?)?.toInt(),
      createdAt: createdAt,
      startPointName: startPointName,
      endPointName: endPointName,
      backendLogId: id.isNotEmpty ? id : null,
    );
  }

  static List<LatLng> latLngFromApiLocation(dynamic location) {
    if (location is! List) return [];
    final out = <LatLng>[];
    for (final item in location) {
      if (item is! Map) continue;
      final coords = _coordinatesFromWaypoint(Map<String, dynamic>.from(item));
      if (coords != null) out.add(coords);
    }
    return out;
  }

  static List<LocationPoint> locationPointsFromApi(dynamic location) {
    if (location is! List) return [];
    final out = <LocationPoint>[];
    for (final item in location) {
      if (item is! Map) continue;
      final coords = _coordinatesFromWaypoint(Map<String, dynamic>.from(item));
      if (coords != null) {
        out.add(LocationPoint(latitude: coords.latitude, longitude: coords.longitude, timestamp: DateTime.now()));
      }
    }
    return out;
  }

  static LatLng? _coordinatesFromWaypoint(Map<String, dynamic> waypoint) {
    final geo = waypoint['geo'];
    if (geo is Map) {
      final coords = geo['coordinates'];
      if (coords is List && coords.length >= 2) {
        return LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
      }
    }
    final direct = waypoint['coordinates'];
    if (direct is List && direct.length >= 2) {
      return LatLng((direct[1] as num).toDouble(), (direct[0] as num).toDouble());
    }
    final lat = waypoint['lat'] ?? waypoint['latitude'];
    final lng = waypoint['long'] ?? waypoint['longitude'];
    if (lat != null && lng != null) {
      return LatLng(double.parse(lat.toString()), double.parse(lng.toString()));
    }
    return null;
  }

  static double _estimatedDistanceMeters(List<LatLng> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
    }
    return total;
  }

  /// Builds waypoint array for `POST /customer/planned-routes`.
  static List<Map<String, dynamic>> locationWaypointsFromRunPoints(List<LocationPoint> points) {
    return points
        .map((p) => {
              'coordinates': [p.longitude, p.latitude],
            })
        .toList();
  }

  /// Builds `POST /customer/planned-routes` body from GPS track points.
  static Map<String, dynamic> createPlannedRouteBody(List<LocationPoint> points) {
    return {'location': locationWaypointsFromRunPoints(points)};
  }

  static String _locationNameForWaypoint(int index, int total) {
    if (index == 0) return 'Start';
    if (index == total - 1) return 'End';
    return 'Point $index';
  }

  /// Builds `location[]` with GeoJSON points for route planning / full API body.
  static List<Map<String, dynamic>> locationWaypointsFromLatLngs(
    List<LatLng> points, {
    String? startName,
    String? endName,
  }) {
    return List.generate(points.length, (index) {
      final point = points[index];
      String locationName;
      if (index == 0) {
        locationName = (startName != null && startName.trim().isNotEmpty) ? startName.trim() : _locationNameForWaypoint(index, points.length);
      } else if (index == points.length - 1) {
        locationName = (endName != null && endName.trim().isNotEmpty) ? endName.trim() : _locationNameForWaypoint(index, points.length);
      } else {
        locationName = _locationNameForWaypoint(index, points.length);
      }
      return {
        'geo': {
          'type': 'Point',
          'coordinates': [point.longitude, point.latitude],
        },
        'locationName': locationName,
      };
    });
  }

  /// Builds full `POST /customer/planned-routes` body from map-planned waypoints.
  static Map<String, dynamic> createPlannedRouteBodyFromMapPoints({
    required List<LatLng> points,
    required double estimatedDistanceMeters,
    int? estimatedTimeSeconds,
    String? startName,
    String? endName,
  }) {
    final estimatedTime = estimatedTimeSeconds ?? (estimatedDistanceMeters / 1000 * 6 * 60).round();
    return {
      'location': locationWaypointsFromLatLngs(points, startName: startName, endName: endName),
      'estimatedTime': estimatedTime,
      'estimatedDistance': estimatedDistanceMeters.round(),
    };
  }

  /// Saves a user-planned route via `POST /customer/planned-routes`.
  Future<PlannedRouteModel> savePlannedRouteFromMapPoints({
    required List<LatLng> points,
    required double estimatedDistanceMeters,
    int? estimatedTimeSeconds,
    String? startName,
    String? endName,
  }) async {
    if (points.isEmpty) {
      throw Exception('Add at least one point to save a route');
    }

    final body = createPlannedRouteBodyFromMapPoints(
      points: points,
      estimatedDistanceMeters: estimatedDistanceMeters,
      estimatedTimeSeconds: estimatedTimeSeconds,
      startName: startName,
      endName: endName,
    );
    logPlannedRouteSavePayload(body);

    final response = await createPlannedRoute(body);
    final id = plannedRouteIdFrom(response);
    if (id == null || id.isEmpty) {
      throw Exception('Route saved but no id returned');
    }

    return PlannedRouteModel(
      id: id,
      name: 'Saved Route',
      routePoints: List<LatLng>.from(points),
      estimatedDistance: estimatedDistanceMeters,
      createdAt: DateTime.now(),
      isSaved: true,
      startPointName: startName,
      endPointName: endName,
    );
  }

  /// Logs the `POST /customer/planned-routes` payload to the console ([APIX] tag).
  static void logPlannedRouteSavePayload(Map<String, dynamic> body) {
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(body);
      Utils.logSuccess('Planned Route Save Request Body:\n$pretty', name: 'APIX');
    } catch (_) {
      Utils.logSuccess('Planned Route Save Request Body: $body', name: 'APIX');
    }
  }

  /// Logs the `POST /customer/running-logs` payload to the console ([APIX] tag).
  static void logRunningLogSavePayload(Map<String, dynamic> body) {
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(body);
      Utils.logSuccess('Running Log Save Request Body:\n$pretty', name: 'APIX');
    } catch (_) {
      Utils.logSuccess('Running Log Save Request Body: $body', name: 'APIX');
    }
  }

  /// Preview/log what will be sent for planned-route save before a run is persisted.
  static void previewPlannedRouteSave({
    required List<LocationPoint> points,
    String? existingRouteId,
  }) {
    if (WorkoutRepository.isValidMongoId(existingRouteId)) {
      Utils.logInfo(
        'Planned route save skipped — reusing existing route id: ${existingRouteId!.trim()}',
        name: 'APIX',
      );
      return;
    }
    if (points.isEmpty) {
      Utils.logInfo('Planned route save skipped — no GPS points captured', name: 'APIX');
      return;
    }
    logPlannedRouteSavePayload(createPlannedRouteBody(points));
  }

  /// `POST /customer/planned-routes` — creates a backend route from GPS waypoints.
  Future<Map<String, dynamic>> createPlannedRoute(Map<String, dynamic> body) async {
    final raw = await _network.post(AppUrl.customerPlannedRoutes, body);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not save route');
    }
    return Map<String, dynamic>.from(raw as Map);
  }

  /// Resolves a backend route id — reuses [existingRouteId] when valid, otherwise creates from [points].
  Future<String> ensureRouteId({
    required List<LocationPoint> points,
    String? existingRouteId,
  }) async {
    if (WorkoutRepository.isValidMongoId(existingRouteId)) {
      final routeId = existingRouteId!.trim();
      Utils.logInfo(
        'Planned route save skipped — reusing existing route id: $routeId',
        name: 'APIX',
      );
      return routeId;
    }
    if (points.isEmpty) {
      throw Exception('No GPS points available to create route');
    }

    final body = createPlannedRouteBody(points);
    logPlannedRouteSavePayload(body);
    final response = await createPlannedRoute(body);
    final id = plannedRouteIdFrom(response);
    if (id == null || id.isEmpty) {
      throw Exception('Route saved but no id returned');
    }
    return id;
  }

  static String? plannedRouteIdFrom(dynamic response) {
    if (response is! Map) return null;
    final data = Map<String, dynamic>.from(response)['data'];
    if (data is! Map) return null;
    final route = Map<String, dynamic>.from(data)['route'];
    if (route is! Map) return null;
    return Map<String, dynamic>.from(route)['_id']?.toString();
  }

  static String? runningLogIdFrom(dynamic response) {
    if (response is! Map) return null;
    final root = Map<String, dynamic>.from(response);
    final direct = root['_id']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;

    final data = root['data'];
    if (data is! Map) return null;
    final dm = Map<String, dynamic>.from(data);
    for (final key in ['log', 'runningLog', 'running-log', 'result']) {
      final nested = dm[key];
      if (nested is Map) {
        final id = Map<String, dynamic>.from(nested)['_id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    }
    return dm['_id']?.toString();
  }

  static int elevationGainForApi(double? elevationGain) {
    if (elevationGain == null || elevationGain.isNaN || elevationGain.isInfinite) {
      return 0;
    }
    return elevationGain.round().clamp(0, 999999);
  }

  static Map<String, dynamic> sanitizeRunningLogBody(Map<String, dynamic> body) {
    final sanitized = Map<String, dynamic>.from(body);
    sanitized['elevationGain'] = elevationGainForApi(
      sanitized['elevationGain'] is num ? (sanitized['elevationGain'] as num).toDouble() : null,
    );
    return sanitized;
  }

  /// Builds `POST /customer/running-logs` body from a completed [RunModel].
  static Map<String, dynamic> createRunningLogBody({
    required RunModel run,
    required String routeId,
  }) {
    final body = <String, dynamic>{
      'runningType': runningTypeFromActivity(run.activityType),
      'distance': run.distanceMeters.round(),
      'duration': run.duration.inSeconds,
      'startTime': run.startTime.toUtc().toIso8601String(),
      'endTime': run.endTime.toUtc().toIso8601String(),
      'route': routeId.trim(),
      'routePoints': run.routePoints?.length ?? 0,
      'elevationGain': elevationGainForApi(run.elevationGain),
    };

    if (run.caloriesBurned != null) {
      body['caloriesBurned'] = run.caloriesBurned;
    }

    return body;
  }

  /// Placeholder map points for manual runs (backend uses `estimatedDistance` / `estimatedTime`).
  static List<LatLng> manualRoutePlaceholderPoints() {
    const start = LatLng(51.5074, -0.1278);
    const end = LatLng(51.5074, -0.1270);
    return [start, end];
  }

  static int estimateCaloriesForManualRun({
    required String activityType,
    required double distanceKm,
  }) {
    final caloriesPerKm = switch (activityType.toLowerCase()) {
      'walk' => 40,
      'jog' => 55,
      'bike' => 30,
      _ => 70,
    };
    return (distanceKm * caloriesPerKm).round();
  }

  /// Creates a backend route + running log for a manually entered activity (no GPS track).
  Future<Map<String, dynamic>> saveManualRunningLog({
    required DateTime startTime,
    required DateTime endTime,
    required String activityType,
    required double distanceMeters,
    required Duration duration,
    int? caloriesBurned,
  }) async {
    if (distanceMeters <= 0) {
      throw Exception('Distance must be greater than zero');
    }
    if (duration.inSeconds <= 0) {
      throw Exception('Duration must be greater than zero');
    }

    final routeBody = createPlannedRouteBodyFromMapPoints(
      points: manualRoutePlaceholderPoints(),
      estimatedDistanceMeters: distanceMeters,
      estimatedTimeSeconds: duration.inSeconds,
      startName: 'Manual Entry',
      endName: 'Manual Entry',
    );
    logPlannedRouteSavePayload(routeBody);
    final routeResponse = await createPlannedRoute(routeBody);
    final routeId = plannedRouteIdFrom(routeResponse);
    if (routeId == null || routeId.isEmpty) {
      throw Exception('Could not create route for manual run');
    }

    final body = <String, dynamic>{
      'runningType': runningTypeFromActivity(activityType),
      'distance': distanceMeters.round(),
      'duration': duration.inSeconds,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'route': routeId,
      'routePoints': 0,
      'elevationGain': 0,
    };
    if (caloriesBurned != null && caloriesBurned > 0) {
      body['caloriesBurned'] = caloriesBurned;
    }

    return createRunningLog(body);
  }

  /// Creates backend route (if needed) then posts the running log.
  Future<Map<String, dynamic>> saveRunningLog({
    required RunModel run,
    String? existingRouteId,
  }) async {
    final points = run.routePoints ?? const <LocationPoint>[];
    final routeId = await ensureRouteId(points: points, existingRouteId: existingRouteId);
    final body = createRunningLogBody(run: run, routeId: routeId);
    return createRunningLog(body);
  }

  /// `POST /customer/running-logs` — persist a completed run on the server.
  Future<Map<String, dynamic>> createRunningLog(Map<String, dynamic> body) async {
    final payload = sanitizeRunningLogBody(body);
    logRunningLogSavePayload(payload);
    final raw = await _network.post(AppUrl.customerRunningLogs, payload);
    if (!_isOk(raw)) {
      throw Exception(_messageFrom(raw) ?? 'Could not save running log');
    }
    return Map<String, dynamic>.from(raw as Map);
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
      return message.map((e) {
        if (e is Map) {
          final field = e['field']?.toString();
          final msg = e['message']?.toString();
          if (field != null && msg != null) return '$field: $msg';
          return e.toString();
        }
        return e.toString();
      }).join(', ');
    }
    return null;
  }
}
