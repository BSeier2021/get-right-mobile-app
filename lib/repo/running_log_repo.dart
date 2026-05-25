import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get_right/app_url.dart';
import 'package:get_right/models/planned_route_model.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/repo/workout_repo.dart';

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
        return 'Bike';
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
        final route = Map<String, dynamic>.from(data)['route'];
        if (route is Map) {
          return plannedRouteFromApi(Map<String, dynamic>.from(route));
        }
      }
    }
    throw Exception('Could not load route details');
  }

  /// Maps one route from `GET /customer/planned-routes`.
  static PlannedRouteModel plannedRouteFromApi(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now();
    final points = latLngFromApiLocation(json['location']);
    final distance = _estimatedDistanceMeters(points);

    return PlannedRouteModel(
      id: id,
      name: 'Saved Route',
      routePoints: points,
      estimatedDistance: distance,
      createdAt: createdAt,
      isSaved: true,
    );
  }

  /// Maps one log from `GET /customer/running-logs`.
  static RunModel runModelFromApiLog(Map<String, dynamic> json) {
    final id = json['_id']?.toString() ?? '';
    final userId = json['user']?.toString() ?? '';
    final activityType = json['runningType']?.toString() ?? 'Run';
    final distanceMeters = (json['distance'] as num?)?.toDouble() ?? 0.0;
    final durationSeconds = (json['duration'] as num?)?.toInt() ?? 0;
    final startTime = DateTime.tryParse(json['startTime']?.toString() ?? '') ?? DateTime.now();
    final endTime = DateTime.tryParse(json['endTime']?.toString() ?? '') ?? startTime;
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? startTime;

    List<LocationPoint>? routePoints;
    final route = json['route'];
    if (route is Map) {
      routePoints = locationPointsFromApi(Map<String, dynamic>.from(route)['location']);
    }
    if (routePoints != null && routePoints.isEmpty) routePoints = null;

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
      averagePace: (json['averagePace'] as num?)?.toDouble(),
      maxPace: null,
      maxSpeed: (json['averageSpeed'] as num?)?.toDouble(),
      caloriesBurned: (json['caloriesBurned'] as num?)?.toInt(),
      createdAt: createdAt,
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
      return existingRouteId!.trim();
    }
    if (points.isEmpty) {
      throw Exception('No GPS points available to create route');
    }

    final response = await createPlannedRoute(createPlannedRouteBody(points));
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
    };

    if (run.elevationGain != null) {
      body['elevationGain'] = run.elevationGain!.round();
    }
    if (run.caloriesBurned != null) {
      body['caloriesBurned'] = run.caloriesBurned;
    }

    return body;
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
    final raw = await _network.post(AppUrl.customerRunningLogs, body);
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
