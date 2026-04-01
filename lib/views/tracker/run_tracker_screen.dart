import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_right/controllers/run_tracking_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/gps_service.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/theme/text_styles.dart';

/// Run Tracker - GPS tracking and run history
class RunTrackerScreen extends StatefulWidget {
  const RunTrackerScreen({super.key});

  @override
  State<RunTrackerScreen> createState() => _RunTrackerScreenState();
}

class _RunTrackerScreenState extends State<RunTrackerScreen> {
  final RunTrackingController _trackingController = Get.put(RunTrackingController());
  GoogleMapController? _mapController;
  // ignore: unused_field
  int _totalRuns = 0;
  // ignore: unused_field
  double _totalDistance = 0.0;
  bool _mapLoadError = false;
  bool _isMapCreated = false;
  Widget? _cachedMapWidget;
  Position? _lastCameraPosition;
  DateTime? _lastCameraUpdate;
  String? _selectedActivity;

  // ignore: unused_field
  final List<Map<String, dynamic>> _activities = [
    {'type': 'Walk', 'icon': Icons.directions_walk, 'color': const Color(0xFF4CAF50), 'description': 'Low intensity cardio'},
    {'type': 'Jog', 'icon': Icons.directions_walk_outlined, 'color': const Color(0xFFFF9800), 'description': 'Moderate pace activity'},
    {'type': 'Run', 'icon': Icons.directions_run, 'color': const Color(0xFFF44336), 'description': 'High intensity running'},
    {'type': 'Bike', 'icon': Icons.directions_bike, 'color': const Color(0xFF2196F3), 'description': 'Cycling activity'},
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
    _initializeLocation();
    // Listen to position updates and update camera only (with debouncing)
    ever(_trackingController.currentPosition, (position) {
      if (position != null && _mapController != null && _isMapCreated && mounted) {
        final now = DateTime.now();
        // Debounce camera updates to prevent buffer overflow (max 1 update per 500ms)
        if (_lastCameraUpdate == null ||
            _lastCameraPosition == null ||
            now.difference(_lastCameraUpdate!) > const Duration(milliseconds: 500) ||
            _hasSignificantPositionChange(position, _lastCameraPosition!)) {
          _lastCameraPosition = position;
          _lastCameraUpdate = now;
          _updateCameraPosition(position);
        }
      }
    });
  }

  /// Initialize location with proper error handling
  Future<void> _initializeLocation() async {
    try {
      final gpsService = GpsService.getInstance();

      // Check if location services are enabled
      final serviceEnabled = await gpsService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          Get.snackbar(
            'Location Disabled',
            'Please enable location services to use the Run Tracker',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 5),
            mainButton: TextButton(onPressed: () => gpsService.openLocationSettings(), child: const Text('Open Settings')),
          );
        }
        return;
      }

      // Check and request permission if needed
      var permission = await gpsService.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await gpsService.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            Get.snackbar('Permission Required', 'Location permission is required to track your runs', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 5));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          Get.snackbar(
            'Permission Denied',
            'Please enable location permission in app settings',
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 5),
            mainButton: TextButton(onPressed: () => gpsService.openAppSettings(), child: const Text('Open Settings')),
          );
        }
        return;
      }

      // Get current location
      final position = await gpsService.getCurrentLocation();
      if (position != null && mounted) {
        _trackingController.currentPosition.value = position;
        debugPrint('✅ Location initialized: ${position.latitude}, ${position.longitude}');
      } else {
        debugPrint('❌ Failed to get location');
      }
    } catch (e) {
      debugPrint('❌ Location initialization error: $e');
      if (mounted) {
        Get.snackbar('Location Error', 'Failed to initialize location: $e', snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 3));
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _mapController = null;
    _isMapCreated = false;
    _cachedMapWidget = null;
    _lastCameraPosition = null;
    _lastCameraUpdate = null;
    super.dispose();
  }

  /// Check if position change is significant enough to update camera
  bool _hasSignificantPositionChange(Position newPos, Position oldPos) {
    // Update if moved more than ~10 meters
    const threshold = 0.0001; // approximately 10 meters
    return (newPos.latitude - oldPos.latitude).abs() > threshold || (newPos.longitude - oldPos.longitude).abs() > threshold;
  }

  /// Update camera position without rebuilding the map (with error handling)
  void _updateCameraPosition(position) {
    if (_mapController != null && _isMapCreated && mounted) {
      try {
        _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)));
      } catch (e) {
        debugPrint('⚠️ Camera update error: $e');
        // Don't throw, just log the error to prevent crashes
      }
    }
  }

  Future<void> _loadStats() async {
    final storageService = Get.find<StorageService>();
    final runsCount = await storageService.getTotalRunsCount();
    final distance = await storageService.getTotalDistance();
    setState(() {
      _totalRuns = runsCount;
      _totalDistance = distance;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Preview - Full Screen
          _buildMapPreview(),

          // Draggable Bottom Sheet with Activity Selection
          DraggableScrollableSheet(
            initialChildSize: 0.20,
            minChildSize: 0.20,
            maxChildSize: 0.38,
            snap: true,
            snapSizes: const [0.12, 0.30],
            builder: (context, scrollController) => _buildDraggableBottomSheet(scrollController),
          ),

          // Plan Route Button - Top Right
        ],
      ),
    );
  }

  /// Build map preview with Google Maps - Full Screen
  Widget _buildMapPreview() {
    return Obx(() {
      final position = _trackingController.currentPosition.value;
      final hasPosition = position != null;

      // Build the map widget separately - it should never rebuild once created
      Widget mapContent;
      if (_isMapCreated && _cachedMapWidget != null) {
        // Map is already created - use cached widget and NEVER rebuild it
        mapContent = _cachedMapWidget!;
      } else if (!hasPosition) {
        mapContent = Container(
          color: AppColors.surface,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.location_searching, size: 40, color: AppColors.accent),
                ),
                const SizedBox(height: 16),
                Text(
                  'Finding your location...',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGray, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3)),
              ],
            ),
          ),
        );
      } else if (_mapLoadError) {
        mapContent = _buildMapErrorState(position);
      } else {
        // Build map only once - this should only happen once
        mapContent = _buildGoogleMapWidgetOnce(position);
      }

      return SizedBox(
        height: double.infinity,
        width: double.infinity,
        child: Stack(
          children: [
            mapContent,

            // Top overlay with gradient
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.black.withOpacity(0.6), AppColors.black.withOpacity(0)]),
                ),
              ),
            ),

            // Map info badge
            if (hasPosition)
              Positioned(
                top: MediaQuery.of(Get.context!).padding.top + 125,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accent.withOpacity(0.5), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.gps_fixed, color: AppColors.accent, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'GPS Ready',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  /// Build Google Map widget once and cache it to prevent buffer overflow
  Widget _buildGoogleMapWidgetOnce(position) {
    // CRITICAL: Return cached widget immediately if map is already created
    // This prevents ANY rebuilds that cause buffer overflow
    if (_isMapCreated && _cachedMapWidget != null) {
      // Don't even check _mapController here to avoid any overhead
      return _cachedMapWidget!;
    }

    // Only build if not already created
    if (_isMapCreated && _cachedMapWidget == null) {
      // Map is being created but widget not cached yet, return loading state
      return Container(
        color: AppColors.surface,
        child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    debugPrint('🗺️ Building GoogleMap widget - Position: ${position.latitude}, ${position.longitude}');

    try {
      final mapWidget = GoogleMap(
        key: const ValueKey('static_google_map'), // Static key prevents rebuilds
        initialCameraPosition: CameraPosition(target: LatLng(position.latitude, position.longitude), zoom: 15),
        onMapCreated: (controller) {
          debugPrint('✅ Map created successfully');
          if (!_isMapCreated || _mapController == null) {
            _mapController = controller;
            _isMapCreated = true;
            _lastCameraPosition = position;
            if (mounted) {
              setState(() {
                _mapLoadError = false;
              });
            }
            try {
              _setMapStyle(controller);
              debugPrint('✅ Map style applied');
            } catch (e) {
              debugPrint('⚠️ Map style error: $e');
              // Style error doesn't prevent map from working
            }
          }
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        liteModeEnabled: false, // Disable lite mode to prevent buffer issues
        buildingsEnabled: true,
        indoorViewEnabled: false,
        trafficEnabled: false,
      );

      // Cache the widget immediately (before onMapCreated fires)
      _cachedMapWidget = mapWidget;
      return mapWidget;
    } catch (e) {
      debugPrint('❌ Error building map: $e');
      // Schedule error state update for next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _mapLoadError = true;
          });
        }
      });
      // Return loading state while error is being set
      return Container(
        color: AppColors.surface,
        child: const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
  }

  /// Build map error state with location info
  Widget _buildMapErrorState(position) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: AppColors.upcoming.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.map_outlined, size: 40, color: AppColors.upcoming),
              ),
              const SizedBox(height: 16),
              Text(
                'Map Unavailable',
                style: AppTextStyles.titleMedium.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Please add your Google Maps API key to enable maps',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryGray),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, color: AppColors.accent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'GPS Location Ready',
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lat: ${position.latitude.toStringAsFixed(6)}\nLng: ${position.longitude.toStringAsFixed(6)}',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.primaryGray),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _mapLoadError = false;
                      });
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () {
                      Get.snackbar(
                        'Setup Required',
                        'Please check GET_GOOGLE_MAPS_API_KEY.md for instructions',
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 5),
                      );
                    },
                    icon: const Icon(Icons.help_outline, size: 18),
                    label: const Text('How to fix?'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Set custom map style for dark theme
  void _setMapStyle(GoogleMapController controller) {
    // "Light" map - essentially disables custom styling so Google's normal light map shows.
    // If you want a pure white background, use below (but it will hide features).
    // To closely resemble Google Maps "default" light mode, just set to null or empty.
    controller.setMapStyle(null);
  }

  /// Build draggable bottom sheet with activity selection
  Widget _buildDraggableBottomSheet(ScrollController scrollController) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: ListView(
        controller: scrollController,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          8.h.verticalSpace,
          // Plan Route - full width primary CTA
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: () => Get.toNamed(AppRoutes.routePlanning),

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentVariant,
                  foregroundColor: AppColors.onAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.route, size: 20),
                    const SizedBox(width: 8),
                    Text('Plan Route', style: AppTextStyles.labelLarge.copyWith(color: AppColors.onAccent)),
                  ],
                ),
              ),
            ),
          ),
          // Action Buttons - Non-scrollable section
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                // Start Tracking Button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _startActivity,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.accentVariant,
                        side: BorderSide(color: AppColors.accent.withOpacity(0.5), width: 2),
                        foregroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset('assets/icons/play.svg', width: 20, height: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Start Activity',
                              style: AppTextStyles.labelLarge.copyWith(color: AppColors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // View History Button
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Get.toNamed(AppRoutes.runHistory);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.accentVariant.withOpacity(0.5), width: 2),
                        foregroundColor: AppColors.onSurface,
                        backgroundColor: AppColors.accentVariant,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.history_rounded, size: 20, color: AppColors.white),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'View History',
                              style: AppTextStyles.labelLarge.copyWith(color: AppColors.white),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Activity Type Icons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Activity Type',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryGrayDark, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActivityOption(type: 'walk', label: 'Walk', asset: 'assets/images/run111.png', bgColor: const Color(0xFFE4F3E9)),
                    _buildActivityOption(type: 'jog', label: 'Jog', asset: 'assets/images/jog.png', bgColor: const Color(0xFFFEEFDA)),
                    _buildActivityOption(type: 'run', label: 'Run', asset: 'assets/images/runing.png', bgColor: const Color(0xFFF3E7F6)),
                    _buildActivityOption(type: 'bike', label: 'Bike', asset: 'assets/images/byke.png', bgColor: const Color(0xFFE3F0FF)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityOption({required String type, required String label, required String asset, required Color bgColor}) {
    final bool isSelected = _selectedActivity == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedActivity = type),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? const Color(0xFF5BA3FF) : Colors.transparent, width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Image.asset(asset, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.onSurface)),
        ],
      ),
    );
  }

  /// Build activity type icon button
  // ignore: unused_element
  Widget _buildActivityIcon({required String type, required IconData icon, required Color color, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : AppColors.backgroundColor,
              shape: BoxShape.circle,
              border: Border.all(color: isSelected ? color : AppColors.primaryGray.withOpacity(0.3), width: isSelected ? 3 : 2),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                  : [BoxShadow(color: AppColors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            type,
            style: AppTextStyles.labelSmall.copyWith(color: isSelected ? color : AppColors.onSurface, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
          ),
        ],
      ),
    );
  }

  /// Start activity with selected type
  void _startActivity() {
    if (_selectedActivity == null) {
      Get.snackbar('Select Activity', 'Please choose an activity type', backgroundColor: AppColors.error, colorText: AppColors.onError);
      return;
    }

    // Navigate to live run tracking with activity type
    Get.toNamed(AppRoutes.runTracking, arguments: {'activityType': _selectedActivity});
  }
}
