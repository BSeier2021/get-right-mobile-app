import 'package:flutter/material.dart';

/// One cardio workout type from the bundled GR `CardioList.json` catalog.
class GrCardioEntry {
  final String id;
  final String name;
  final String description;
  final String iconKey;
  final List<String> metrics;
  final String activityType;
  final String trackingMode;
  final List<String> tags;

  const GrCardioEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.iconKey,
    required this.metrics,
    required this.activityType,
    required this.trackingMode,
    required this.tags,
  });

  factory GrCardioEntry.fromJson(Map<String, dynamic> json) {
    final metricsRaw = json['metrics'];
    final tagsRaw = json['tags'];
    return GrCardioEntry(
      id: (json['id'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      description: (json['description'] ?? '').toString().trim(),
      iconKey: (json['icon'] ?? 'directions_run').toString().trim(),
      metrics: metricsRaw is List
          ? metricsRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : const [],
      activityType: (json['activityType'] ?? json['name'] ?? 'Run').toString().trim(),
      trackingMode: (json['trackingMode'] ?? 'gps').toString().trim().toLowerCase(),
      tags: tagsRaw is List
          ? tagsRaw.map((e) => e.toString().trim().toLowerCase()).where((e) => e.isNotEmpty).toList()
          : const [],
    );
  }

  IconData get iconData {
    switch (iconKey) {
      case 'directions_walk':
        return Icons.directions_walk;
      case 'directions_bike':
        return Icons.directions_bike;
      case 'pedal_bike':
        return Icons.pedal_bike;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'favorite_border':
        return Icons.favorite_border;
      case 'directions_run':
      default:
        return Icons.directions_run;
    }
  }
}
