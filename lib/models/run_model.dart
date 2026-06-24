/// Run tracking model
class RunModel {
  final String id;
  final String userId;
  final String activityType; // walk, jog, run, bike
  final double distanceMeters;
  final Duration duration;
  final DateTime startTime;
  final DateTime endTime;
  final List<LocationPoint>? routePoints;
  final double? elevationGain;
  final double? averagePace;
  final double? maxPace;
  final double? maxSpeed;
  final int? caloriesBurned;
  final String? notes;
  final List<Split>? splits;
  final DateTime createdAt;
  final String? startPointName;
  final String? endPointName;

  RunModel({
    required this.id,
    required this.userId,
    required this.activityType,
    required this.distanceMeters,
    required this.duration,
    required this.startTime,
    required this.endTime,
    this.routePoints,
    this.elevationGain,
    this.averagePace,
    this.maxPace,
    this.maxSpeed,
    this.caloriesBurned,
    this.notes,
    this.splits,
    required this.createdAt,
    this.startPointName,
    this.endPointName,
  });

  /// Calculate average speed in m/s
  double get averageSpeed => distanceMeters / duration.inSeconds;

  /// From JSON
  factory RunModel.fromJson(Map<String, dynamic> json) {
    return RunModel(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      activityType: json['activityType'] ?? 'Run',
      distanceMeters: json['distanceMeters']?.toDouble() ?? 0.0,
      duration: Duration(seconds: json['durationSeconds'] ?? 0),
      startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : DateTime.now(),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : DateTime.now(),
      routePoints: json['routePoints'] != null ? (json['routePoints'] as List).map((point) => LocationPoint.fromJson(point)).toList() : null,
      elevationGain: json['elevationGain']?.toDouble(),
      averagePace: json['averagePace']?.toDouble(),
      maxPace: json['maxPace']?.toDouble(),
      maxSpeed: json['maxSpeed']?.toDouble(),
      caloriesBurned: json['caloriesBurned']?.toInt(),
      notes: json['notes'],
      splits: json['splits'] != null ? (json['splits'] as List).map((split) => Split.fromJson(split)).toList() : null,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      startPointName: json['startPointName']?.toString(),
      endPointName: json['endPointName']?.toString(),
    );
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'activityType': activityType,
      'distanceMeters': distanceMeters,
      'durationSeconds': duration.inSeconds,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'routePoints': routePoints?.map((point) => point.toJson()).toList(),
      'elevationGain': elevationGain,
      'averagePace': averagePace,
      'maxPace': maxPace,
      'maxSpeed': maxSpeed,
      'caloriesBurned': caloriesBurned,
      'notes': notes,
      'splits': splits?.map((split) => split.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      if (startPointName != null) 'startPointName': startPointName,
      if (endPointName != null) 'endPointName': endPointName,
    };
  }
}

/// Location point for route tracking
class LocationPoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final DateTime timestamp;

  LocationPoint({required this.latitude, required this.longitude, this.altitude, required this.timestamp});

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      altitude: json['altitude']?.toDouble(),
      timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude, 'altitude': altitude, 'timestamp': timestamp.toIso8601String()};
  }
}

/// Split data for per-mile or per-km breakdown
class Split {
  final int splitNumber;
  final double distanceMeters;
  final Duration duration;
  final double pace; // min/km

  Split({required this.splitNumber, required this.distanceMeters, required this.duration, required this.pace});

  factory Split.fromJson(Map<String, dynamic> json) {
    return Split(
      splitNumber: json['splitNumber'] ?? 0,
      distanceMeters: json['distanceMeters']?.toDouble() ?? 0.0,
      duration: Duration(seconds: json['durationSeconds'] ?? 0),
      pace: json['pace']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'splitNumber': splitNumber, 'distanceMeters': distanceMeters, 'durationSeconds': duration.inSeconds, 'pace': pace};
  }
}
