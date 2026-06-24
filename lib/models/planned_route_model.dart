import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Planned Route Model for pre-run route planning
class PlannedRouteModel {
  final String id;
  final String name;
  final List<LatLng> routePoints;
  final double estimatedDistance; // in meters
  final double? elevationGain;
  final DateTime? scheduledDate;
  final bool isSaved;
  final DateTime createdAt;
  final String? startPointName;
  final String? endPointName;

  PlannedRouteModel({
    required this.id,
    required this.name,
    required this.routePoints,
    required this.estimatedDistance,
    this.elevationGain,
    this.scheduledDate,
    this.isSaved = false,
    required this.createdAt,
    this.startPointName,
    this.endPointName,
  });

  /// From JSON
  factory PlannedRouteModel.fromJson(Map<String, dynamic> json) {
    return PlannedRouteModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Planned Route',
      routePoints: (json['routePoints'] as List?)?.map((point) => LatLng(point['latitude'], point['longitude'])).toList() ?? [],
      estimatedDistance: json['estimatedDistance']?.toDouble() ?? 0.0,
      elevationGain: json['elevationGain']?.toDouble(),
      scheduledDate: json['scheduledDate'] != null ? DateTime.parse(json['scheduledDate']) : null,
      isSaved: json['isSaved'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      startPointName: json['startPointName']?.toString(),
      endPointName: json['endPointName']?.toString(),
    );
  }

  /// To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'routePoints': routePoints.map((point) => {'latitude': point.latitude, 'longitude': point.longitude}).toList(),
      'estimatedDistance': estimatedDistance,
      'elevationGain': elevationGain,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'isSaved': isSaved,
      'createdAt': createdAt.toIso8601String(),
      if (startPointName != null) 'startPointName': startPointName,
      if (endPointName != null) 'endPointName': endPointName,
    };
  }

  /// Copy with
  PlannedRouteModel copyWith({
    String? id,
    String? name,
    List<LatLng>? routePoints,
    double? estimatedDistance,
    double? elevationGain,
    DateTime? scheduledDate,
    bool? isSaved,
    DateTime? createdAt,
    String? startPointName,
    String? endPointName,
  }) {
    return PlannedRouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      routePoints: routePoints ?? this.routePoints,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      elevationGain: elevationGain ?? this.elevationGain,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      isSaved: isSaved ?? this.isSaved,
      createdAt: createdAt ?? this.createdAt,
      startPointName: startPointName ?? this.startPointName,
      endPointName: endPointName ?? this.endPointName,
    );
  }
}
