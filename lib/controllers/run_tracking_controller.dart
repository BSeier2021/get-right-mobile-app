import 'dart:async';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/repo/running_log_repo.dart';
import 'package:get_right/services/gps_service.dart';
import 'package:get_right/services/storage_service.dart';

/// Controller for managing run tracking state
class RunTrackingController extends GetxController {
  final GpsService _gpsService = GpsService.getInstance();
  final StorageService _storageService = Get.find<StorageService>();
  final RunningLogRepository _runningLogRepo = RunningLogRepository();

  /// Optional planned route MongoDB id (`route` field on running-logs API).
  String? plannedRouteId;

  // Observable state
  final RxBool isTracking = false.obs;
  final RxBool isPaused = false.obs;
  final Rx<Position?> currentPosition = Rx<Position?>(null);
  final RxList<LocationPoint> routePoints = <LocationPoint>[].obs;
  final RxDouble distanceMeters = 0.0.obs;
  final RxDouble elevationGain = 0.0.obs;
  final RxDouble currentPace = 0.0.obs;
  final RxDouble averagePace = 0.0.obs;
  final RxDouble maxPace = 0.0.obs;
  final Rx<Duration> elapsedTime = Duration.zero.obs;
  final RxString runStatus = 'Ready'.obs;
  final RxString activityType = 'Run'.obs;
  final RxInt caloriesBurned = 0.obs;

  // Private state
  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;
  DateTime? _startTime;
  DateTime? _pauseTime;
  Duration _pausedDuration = Duration.zero;
  Position? _lastPosition;

  @override
  void onInit() {
    super.onInit();
    _initializeLocation();
  }

  @override
  void onClose() {
    stopTracking();
    super.onClose();
  }

  /// Initialize location services
  Future<void> _initializeLocation() async {
    final position = await _gpsService.getCurrentLocation();
    if (position != null) {
      currentPosition.value = position;
    }
  }

  /// Start tracking run
  Future<bool> startTracking({String? activity}) async {
    // Check location permission
    final serviceEnabled = await _gpsService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Get.snackbar('Location Disabled', 'Please enable location services', snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    var permission = await _gpsService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _gpsService.requestPermission();
      if (permission == LocationPermission.denied) {
        Get.snackbar('Permission Denied', 'Location permission is required', snackPosition: SnackPosition.BOTTOM);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      Get.snackbar('Permission Denied', 'Please enable location in app settings', snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    // Set activity type
    if (activity != null) {
      activityType.value = activity;
    }

    // Reset state
    plannedRouteId = null;
    routePoints.clear();
    distanceMeters.value = 0.0;
    elevationGain.value = 0.0;
    maxPace.value = 0.0;
    caloriesBurned.value = 0;
    elapsedTime.value = Duration.zero;
    _pausedDuration = Duration.zero;
    _startTime = DateTime.now();
    _lastPosition = null;

    // Start tracking
    isTracking.value = true;
    isPaused.value = false;
    runStatus.value = 'Running';

    // Start position tracking
    _positionSubscription = _gpsService.trackLocation().listen(
      (position) {
        if (!isPaused.value) {
          _updatePosition(position);
        }
        currentPosition.value = position;
      },
      onError: (error) {
        Get.snackbar('GPS Error', 'Failed to track location', snackPosition: SnackPosition.BOTTOM);
      },
    );

    // Start timer
    _startTimer();

    return true;
  }

  /// Update position and calculate metrics
  void _updatePosition(Position position) {
    final locationPoint = LocationPoint(latitude: position.latitude, longitude: position.longitude, altitude: position.altitude, timestamp: DateTime.now());

    routePoints.add(locationPoint);

    // Calculate distance
    if (_lastPosition != null) {
      final distance = _gpsService.calculateDistance(startLat: _lastPosition!.latitude, startLng: _lastPosition!.longitude, endLat: position.latitude, endLng: position.longitude);
      distanceMeters.value += distance;

      // Calculate current pace (min/km) based on last segment
      final segmentDuration = DateTime.now().difference(routePoints[routePoints.length - 2].timestamp);
      final segmentDistanceKm = distance / 1000;
      if (segmentDistanceKm > 0) {
        final pace = segmentDuration.inSeconds / 60 / segmentDistanceKm;
        currentPace.value = pace;

        // Update max pace
        if (maxPace.value == 0 || pace < maxPace.value) {
          maxPace.value = pace;
        }
      }
    }

    // Calculate elevation gain
    elevationGain.value = _gpsService.calculateElevationGain(routePoints);

    // Calculate average pace
    if (distanceMeters.value > 0) {
      averagePace.value = _gpsService.calculateAveragePace(elapsedTime.value - _pausedDuration, distanceMeters.value);
    }

    // Calculate calories burned
    _updateCaloriesBurned();

    _lastPosition = position;
  }

  /// Start timer
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!isPaused.value && _startTime != null) {
        elapsedTime.value = DateTime.now().difference(_startTime!) - _pausedDuration;
      }
    });
  }

  /// Calculate calories burned based on activity type, distance, and duration
  void _updateCaloriesBurned() {
    // Simplified calorie calculation (In real app, would use user weight, age, etc.)
    final distanceKm = distanceMeters.value / 1000;
    final durationHours = elapsedTime.value.inSeconds / 3600;

    double caloriesPerKm = 60; // Default for running

    switch (activityType.value.toLowerCase()) {
      case 'walk':
        caloriesPerKm = 40;
        break;
      case 'jog':
        caloriesPerKm = 55;
        break;
      case 'run':
        caloriesPerKm = 70;
        break;
      case 'bike':
        caloriesPerKm = 30;
        break;
    }

    caloriesBurned.value = (distanceKm * caloriesPerKm).round();
  }

  /// Pause tracking
  void pauseTracking() {
    if (!isTracking.value || isPaused.value) return;

    isPaused.value = true;
    runStatus.value = 'Paused';
    _pauseTime = DateTime.now();
  }

  /// Resume tracking
  void resumeTracking() {
    if (!isTracking.value || !isPaused.value) return;

    isPaused.value = false;
    runStatus.value = 'Running';

    if (_pauseTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseTime!);
      _pauseTime = null;
    }
  }

  /// Stop tracking and save run
  Future<RunModel?> stopTracking() async {
    if (!isTracking.value) return null;

    _timer?.cancel();
    _positionSubscription?.cancel();

    final endTime = DateTime.now();
    final duration = elapsedTime.value;

    isTracking.value = false;
    isPaused.value = false;
    runStatus.value = 'Completed';

    // Create run model
    if (routePoints.isEmpty || _startTime == null) {
      return null;
    }

    final run = RunModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: _storageService.getUserId() ?? 'anonymous',
      activityType: activityType.value,
      distanceMeters: distanceMeters.value,
      duration: duration,
      startTime: _startTime!,
      endTime: endTime,
      routePoints: routePoints.toList(),
      elevationGain: elevationGain.value,
      averagePace: averagePace.value,
      maxPace: maxPace.value > 0 ? maxPace.value : null,
      maxSpeed: null,
      caloriesBurned: caloriesBurned.value > 0 ? caloriesBurned.value : null,
      createdAt: DateTime.now(),
    );

    // Save run to storage
    await _saveRun(run);

    return run;
  }

  /// Save run to local storage, backend, and auto-sync to journal/calendar.
  Future<void> _saveRun(RunModel run) async {
    try {
      final runs = await _storageService.getRuns();
      runs.add(run);
      await _storageService.saveRuns(runs);

      var backendSynced = false;
      try {
        await _runningLogRepo.saveRunningLog(
          run: run,
          existingRouteId: plannedRouteId,
        );
        backendSynced = true;
      } catch (e) {
        // Local save succeeded; backend sync is best-effort.
      }

      // Auto-sync to journal and calendar
      final localSyncSuccess = await _storageService.autoSyncRun(run);
      if (localSyncSuccess || backendSynced) {
        // Defer so navigation off active run does not dispose snackbar before Get closes it.
        Future.delayed(const Duration(milliseconds: 400), () {
          if (Get.isSnackbarOpen == true) return;
          final message = backendSynced && localSyncSuccess
              ? 'Your run has been saved and synced to Journal and Calendar'
              : backendSynced
                  ? 'Your run has been saved to your account'
                  : 'Your run has been synced to Journal and Calendar';
          Get.snackbar(
            'Run Saved',
            message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Get.theme.colorScheme.primary,
            colorText: Get.theme.colorScheme.onPrimary,
            duration: const Duration(seconds: 2),
          );
        });
      }
    } catch (e) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (Get.isSnackbarOpen == true) return;
        Get.snackbar('Save Error', 'Failed to save run data', snackPosition: SnackPosition.BOTTOM);
      });
    }
  }

  /// Cancel tracking without saving
  void cancelTracking() {
    _timer?.cancel();
    _positionSubscription?.cancel();

    isTracking.value = false;
    isPaused.value = false;
    runStatus.value = 'Ready';

    routePoints.clear();
    distanceMeters.value = 0.0;
    elevationGain.value = 0.0;
    maxPace.value = 0.0;
    caloriesBurned.value = 0;
    elapsedTime.value = Duration.zero;
  }

  /// Format pace as MM:SS
  String formatPace(double paceMinPerKm) {
    if (paceMinPerKm == 0 || paceMinPerKm.isInfinite || paceMinPerKm.isNaN) {
      return '--:--';
    }
    final minutes = paceMinPerKm.floor();
    final seconds = ((paceMinPerKm - minutes) * 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format distance
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  /// Format duration as HH:MM:SS
  String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format elevation
  String formatElevation(double meters) {
    return '${meters.toStringAsFixed(0)} m';
  }
}
