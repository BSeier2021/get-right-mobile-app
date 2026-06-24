import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Helpers for route start/end labels from search text, API waypoints, or geocoding.
class RouteLocationHelper {
  RouteLocationHelper._();

  static bool isGenericLabel(String? name) {
    if (name == null || name.trim().isEmpty) return true;
    final normalized = name.trim().toLowerCase();
    if (normalized == 'start' || normalized == 'end') return true;
    if (normalized.startsWith('point ')) return true;
    return false;
  }

  static String formatPlacemark(Placemark placemark) {
    final parts = <String>[
      if ((placemark.street ?? '').trim().isNotEmpty) placemark.street!.trim(),
      if ((placemark.locality ?? '').trim().isNotEmpty) placemark.locality!.trim(),
      if ((placemark.administrativeArea ?? '').trim().isNotEmpty) placemark.administrativeArea!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(', ');
    if ((placemark.name ?? '').trim().isNotEmpty) return placemark.name!.trim();
    return 'Unknown location';
  }

  static String formatCoordinates(LatLng point) {
    return '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
  }

  static Future<String> resolveLabel(LatLng point, {String? cachedName}) async {
    if (!isGenericLabel(cachedName)) return cachedName!.trim();
    try {
      final placemarks = await placemarkFromCoordinates(point.latitude, point.longitude);
      if (placemarks.isNotEmpty) {
        return formatPlacemark(placemarks.first);
      }
    } catch (_) {
      /* fall through to coordinates */
    }
    return formatCoordinates(point);
  }

  static Future<({String start, String end})> resolveEndpointLabels({
    required LatLng start,
    required LatLng end,
    String? startName,
    String? endName,
  }) async {
    final resolvedStart = await resolveLabel(start, cachedName: startName);
    final resolvedEnd = await resolveLabel(end, cachedName: endName);
    return (start: resolvedStart, end: resolvedEnd);
  }

  static String? locationNameFromWaypoint(Map<String, dynamic> waypoint) {
    final name = waypoint['locationName']?.toString().trim();
    if (name == null || name.isEmpty) return null;
    return name;
  }

  static ({List<LatLng> points, String? startName, String? endName}) parseApiLocation(dynamic location) {
    if (location is! List) {
      return (points: const <LatLng>[], startName: null, endName: null);
    }

    final points = <LatLng>[];
    String? startName;
    String? endName;

    for (var i = 0; i < location.length; i++) {
      final item = location[i];
      if (item is! Map) continue;
      final waypoint = Map<String, dynamic>.from(item);
      final coords = _coordinatesFromWaypoint(waypoint);
      if (coords == null) continue;

      points.add(coords);
      final name = locationNameFromWaypoint(waypoint);
      if (i == 0) startName = name;
      if (i == location.length - 1) endName = name;
    }

    if (points.length == 1) {
      endName ??= startName;
    }

    return (points: points, startName: startName, endName: endName);
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
}
