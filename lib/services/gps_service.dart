import 'package:geolocator/geolocator.dart';
import 'package:get_right/models/run_model.dart';

/// GPS Service for location tracking
class GpsService {
  static GpsService? _instance;

  GpsService._();

  /// Get singleton instance
  static GpsService getInstance() {
    _instance ??= GpsService._();
    return _instance!;
  }

  /// Prevents concurrent permission / position requests (iOS/Android reject parallel prompts).
  Future<LocationPermission>? _permissionRequest;
  Future<Position?>? _locationRequest;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    if (_permissionRequest != null) return _permissionRequest!;
    _permissionRequest = Geolocator.requestPermission().whenComplete(() {
      _permissionRequest = null;
    });
    return _permissionRequest!;
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    if (_locationRequest != null) return _locationRequest!;
    _locationRequest = _resolveCurrentLocation().whenComplete(() {
      _locationRequest = null;
    });
    return _locationRequest!;
  }

  Future<Position?> _resolveCurrentLocation() async {
    // Check if location services are enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    // Check permission
    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    // Get current position
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  /// Start tracking location (returns a stream)
  Stream<Position> trackLocation() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Calculate distance between two positions (in meters)
  double calculateDistance({required double startLat, required double startLng, required double endLat, required double endLng}) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Calculate total distance from list of positions
  double calculateTotalDistance(List<LocationPoint> points) {
    if (points.length < 2) return 0;

    double totalDistance = 0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += calculateDistance(
        startLat: points[i].latitude,
        startLng: points[i].longitude,
        endLat: points[i + 1].latitude,
        endLng: points[i + 1].longitude,
      );
    }
    return totalDistance;
  }

  /// Calculate elevation gain
  double calculateElevationGain(List<LocationPoint> points) {
    if (points.length < 2) return 0;

    double elevationGain = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i].altitude ?? 0;
      final next = points[i + 1].altitude ?? 0;
      final diff = next - current;
      if (diff > 0) {
        elevationGain += diff;
      }
    }
    return elevationGain;
  }

  /// Calculate average pace (minutes per km)
  double calculateAveragePace(Duration duration, double distanceMeters) {
    if (distanceMeters == 0) return 0;
    final distanceKm = distanceMeters / 1000;
    final minutes = duration.inSeconds / 60;
    return minutes / distanceKm;
  }

  /// Open app settings (for enabling location)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
