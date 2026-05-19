import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/models/run_model.dart';
import 'package:get_right/models/workout_model.dart';
import 'package:get_right/models/planned_route_model.dart';

/// Local storage service using SharedPreferences
class StorageService {
  static StorageService? _instance;
  static SharedPreferences? _preferences;

  StorageService._();

  /// Get singleton instance
  static Future<StorageService> getInstance() async {
    _instance ??= StorageService._();
    _preferences ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  /// Save string value
  Future<bool> saveString(String key, String value) async {
    return await _preferences!.setString(key, value);
  }

  /// Get string value
  String? getString(String key) {
    return _preferences!.getString(key);
  }

  /// Save int value
  Future<bool> saveInt(String key, int value) async {
    return await _preferences!.setInt(key, value);
  }

  /// Get int value
  int? getInt(String key) {
    return _preferences!.getInt(key);
  }

  /// Save bool value
  Future<bool> saveBool(String key, bool value) async {
    return await _preferences!.setBool(key, value);
  }

  /// Get bool value
  bool? getBool(String key) {
    return _preferences!.getBool(key);
  }

  /// Save double value
  Future<bool> saveDouble(String key, double value) async {
    return await _preferences!.setDouble(key, value);
  }

  /// Get double value
  double? getDouble(String key) {
    return _preferences!.getDouble(key);
  }

  /// Save list of strings
  Future<bool> saveStringList(String key, List<String> value) async {
    return await _preferences!.setStringList(key, value);
  }

  /// Get list of strings
  List<String>? getStringList(String key) {
    return _preferences!.getStringList(key);
  }

  /// Remove value
  Future<bool> remove(String key) async {
    return await _preferences!.remove(key);
  }

  /// Clear all values
  Future<bool> clear() async {
    return await _preferences!.clear();
  }

  /// Check if key exists
  bool containsKey(String key) {
    return _preferences!.containsKey(key);
  }

  // Auth-specific methods

  /// Save user token
  Future<bool> saveToken(String token) async {
    return await saveString(AppConstants.keyUserToken, token);
  }

  /// Get user token
  String? getToken() {
    return getString(AppConstants.keyUserToken);
  }

  /// Save user ID
  Future<bool> saveUserId(String userId) async {
    return await saveString(AppConstants.keyUserId, userId);
  }

  /// Get user ID
  String? getUserId() {
    return getString(AppConstants.keyUserId);
  }

  /// Save login status
  Future<bool> saveLoginStatus(bool isLoggedIn) async {
    return await saveBool(AppConstants.keyIsLoggedIn, isLoggedIn);
  }

  /// Get login status
  bool isLoggedIn() {
    return getBool(AppConstants.keyIsLoggedIn) ?? false;
  }

  /// Save user email
  Future<bool> saveEmail(String email) async {
    return await saveString(AppConstants.keyUserEmail, email);
  }

  /// Get user email
  String? getEmail() {
    return getString(AppConstants.keyUserEmail);
  }

  /// Save user name
  Future<bool> saveName(String name) async {
    return await saveString(AppConstants.keyUserName, name);
  }

  /// Get user name
  String? getName() {
    return getString(AppConstants.keyUserName);
  }

  /// Save profile picture URL (from login / profile API).
  Future<bool> saveProfilePictureUrl(String url) async {
    return await saveString(AppConstants.keyUserPhotoUrl, url);
  }

  /// Get profile picture URL
  String? getProfilePictureUrl() {
    return getString(AppConstants.keyUserPhotoUrl);
  }

  /// Check if onboarding is complete
  bool isOnboardingComplete() {
    return getBool(AppConstants.keyOnboardingComplete) ?? false;
  }

  /// Mark onboarding as complete
  Future<bool> completeOnboarding() async {
    return await saveBool(AppConstants.keyOnboardingComplete, true);
  }

  /// Logout - clear all auth data
  Future<bool> logout() async {
    await remove(AppConstants.keyUserToken);
    await remove(AppConstants.keyUserId);
    await remove(AppConstants.keyUserEmail);
    await remove(AppConstants.keyUserName);
    await remove(AppConstants.keyUserPhotoUrl);
    return await saveBool(AppConstants.keyIsLoggedIn, false);
  }

  // Run tracking methods

  /// Save runs list
  Future<bool> saveRuns(List<RunModel> runs) async {
    final jsonList = runs.map((run) => json.encode(run.toJson())).toList();
    return await saveStringList('user_runs', jsonList);
  }

  /// Get runs list
  Future<List<RunModel>> getRuns() async {
    final jsonList = getStringList('user_runs') ?? [];
    return jsonList
        .map((jsonStr) => RunModel.fromJson(json.decode(jsonStr)))
        .toList();
  }

  /// Get runs for specific date
  Future<List<RunModel>> getRunsForDate(DateTime date) async {
    final allRuns = await getRuns();
    return allRuns.where((run) {
      return run.startTime.year == date.year &&
          run.startTime.month == date.month &&
          run.startTime.day == date.day;
    }).toList();
  }

  /// Get total runs count
  Future<int> getTotalRunsCount() async {
    final runs = await getRuns();
    return runs.length;
  }

  /// Get total distance in meters
  Future<double> getTotalDistance() async {
    final runs = await getRuns();
    double total = 0.0;
    for (final run in runs) {
      total += run.distanceMeters;
    }
    return total;
  }

  // Journal sync methods

  /// Sync run to journal as a workout activity
  Future<bool> syncRunToJournal(RunModel run) async {
    try {
      // Store run ID in synced runs list
      final syncedRuns = getStringList('synced_runs_to_journal') ?? [];
      if (!syncedRuns.contains(run.id)) {
        syncedRuns.add(run.id);
        await saveStringList('synced_runs_to_journal', syncedRuns);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if run is synced to journal
  bool isRunSyncedToJournal(String runId) {
    final syncedRuns = getStringList('synced_runs_to_journal') ?? [];
    return syncedRuns.contains(runId);
  }

  // Calendar sync methods

  /// Sync run to calendar
  Future<bool> syncRunToCalendar(RunModel run) async {
    try {
      // Store run ID in synced runs list for calendar
      final syncedRuns = getStringList('synced_runs_to_calendar') ?? [];
      if (!syncedRuns.contains(run.id)) {
        syncedRuns.add(run.id);
        await saveStringList('synced_runs_to_calendar', syncedRuns);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Check if run is synced to calendar
  bool isRunSyncedToCalendar(String runId) {
    final syncedRuns = getStringList('synced_runs_to_calendar') ?? [];
    return syncedRuns.contains(runId);
  }

  /// Auto-sync run to both journal and calendar
  Future<bool> autoSyncRun(RunModel run) async {
    final journalSync = await syncRunToJournal(run);
    final calendarSync = await syncRunToCalendar(run);
    return journalSync && calendarSync;
  }

  // Workout storage methods

  /// Save workouts list
  Future<bool> saveWorkouts(List<WorkoutModel> workouts) async {
    final jsonList = workouts
        .map((workout) => json.encode(workout.toJson()))
        .toList();
    return await saveStringList('user_workouts', jsonList);
  }

  /// Get workouts list
  Future<List<WorkoutModel>> getWorkouts() async {
    final jsonList = getStringList('user_workouts') ?? [];
    return jsonList
        .map((jsonStr) => WorkoutModel.fromJson(json.decode(jsonStr)))
        .toList();
  }

  /// Add a single workout
  Future<bool> addWorkout(WorkoutModel workout) async {
    final workouts = await getWorkouts();
    workouts.add(workout);
    return await saveWorkouts(workouts);
  }

  /// Get workouts for specific date
  Future<List<WorkoutModel>> getWorkoutsForDate(DateTime date) async {
    final allWorkouts = await getWorkouts();
    return allWorkouts.where((workout) {
      return workout.date.year == date.year &&
          workout.date.month == date.month &&
          workout.date.day == date.day;
    }).toList();
  }

  /// Delete workout by ID
  Future<bool> deleteWorkout(String workoutId) async {
    final workouts = await getWorkouts();
    workouts.removeWhere((workout) => workout.id == workoutId);
    return await saveWorkouts(workouts);
  }

  /// Update workout
  Future<bool> updateWorkout(WorkoutModel updatedWorkout) async {
    final workouts = await getWorkouts();
    final index = workouts.indexWhere(
      (workout) => workout.id == updatedWorkout.id,
    );
    if (index != -1) {
      workouts[index] = updatedWorkout;
      return await saveWorkouts(workouts);
    }
    return false;
  }

  // Planned Route storage methods

  /// Save planned routes list
  Future<bool> savePlannedRoutes(List<PlannedRouteModel> routes) async {
    final jsonList = routes
        .map((route) => json.encode(route.toJson()))
        .toList();
    return await saveStringList('user_planned_routes', jsonList);
  }

  /// Get planned routes list
  Future<List<PlannedRouteModel>> getPlannedRoutes() async {
    final jsonList = getStringList('user_planned_routes') ?? [];
    return jsonList
        .map((jsonStr) => PlannedRouteModel.fromJson(json.decode(jsonStr)))
        .toList();
  }

  /// Add a single planned route
  Future<bool> addPlannedRoute(PlannedRouteModel route) async {
    final routes = await getPlannedRoutes();
    routes.add(route);
    return await savePlannedRoutes(routes);
  }

  /// Delete planned route by ID
  Future<bool> deletePlannedRoute(String routeId) async {
    final routes = await getPlannedRoutes();
    routes.removeWhere((route) => route.id == routeId);
    return await savePlannedRoutes(routes);
  }

  /// Update planned route
  Future<bool> updatePlannedRoute(PlannedRouteModel updatedRoute) async {
    final routes = await getPlannedRoutes();
    final index = routes.indexWhere((route) => route.id == updatedRoute.id);
    if (index != -1) {
      routes[index] = updatedRoute;
      return await savePlannedRoutes(routes);
    }
    return false;
  }

  // Onboarding Preferences methods

  /// Save user preference (Strength Training or Running & Cardio)
  Future<bool> saveUserPreference(String preference) async {
    return await saveString(AppConstants.keyUserPreference, preference);
  }

  /// Get user preference
  String? getUserPreference() {
    return getString(AppConstants.keyUserPreference);
  }

  /// Save user goals (list of selected goals)
  Future<bool> saveUserGoals(List<String> goals) async {
    return await saveStringList(AppConstants.keyUserGoals, goals);
  }

  /// Get user goals
  List<String> getUserGoals() {
    return getStringList(AppConstants.keyUserGoals) ?? [];
  }

  /// Save fitness level
  Future<bool> saveFitnessLevel(String level) async {
    return await saveString(AppConstants.keyFitnessLevel, level);
  }

  /// Get fitness level
  String? getFitnessLevel() {
    return getString(AppConstants.keyFitnessLevel);
  }

  /// Save exercise frequency
  Future<bool> saveExerciseFrequency(String frequency) async {
    return await saveString(AppConstants.keyExerciseFrequency, frequency);
  }

  /// Get exercise frequency
  String? getExerciseFrequency() {
    return getString(AppConstants.keyExerciseFrequency);
  }

  // Saved Posts Methods

  /// Save bookmarked posts
  Future<bool> saveSavedPosts(List<Map<String, dynamic>> posts) async {
    final List<String> postsJson = posts
        .map((post) => jsonEncode(post))
        .toList();
    return await saveStringList(AppConstants.keySavedPosts, postsJson);
  }

  /// Get saved posts
  List<Map<String, dynamic>> getSavedPosts() {
    final List<String>? postsJson = getStringList(AppConstants.keySavedPosts);
    if (postsJson == null || postsJson.isEmpty) {
      return [];
    }
    return postsJson
        .map((postJson) => jsonDecode(postJson) as Map<String, dynamic>)
        .toList();
  }

  /// Add a saved post
  Future<bool> addSavedPost(Map<String, dynamic> post) async {
    final savedPosts = getSavedPosts();
    // Check if post already exists
    if (!savedPosts.any((p) => p['id'] == post['id'])) {
      savedPosts.add(post);
      return await saveSavedPosts(savedPosts);
    }
    return true;
  }

  /// Remove a saved post
  Future<bool> removeSavedPost(String postId) async {
    final savedPosts = getSavedPosts();
    savedPosts.removeWhere((p) => p['id'] == postId);
    return await saveSavedPosts(savedPosts);
  }

  /// Check if post is saved
  bool isPostSaved(String postId) {
    final savedPosts = getSavedPosts();
    return savedPosts.any((p) => p['id'] == postId);
  }

  /// Feed post ids stored locally after save API success.
  Set<String> getSavedFeedPostIds() {
    return getSavedPosts().map((p) => (p['id'] ?? '').toString().trim()).where((id) => id.isNotEmpty).toSet();
  }

  // Subscription methods

  /// Check if user has active subscription
  bool hasActiveSubscription() {
    final hasSubscription = getBool(AppConstants.keyHasSubscription) ?? false;
    if (!hasSubscription) return false;

    // Check if subscription has expired
    final expiryDateStr = getString(AppConstants.keySubscriptionExpiryDate);
    if (expiryDateStr == null) return false;

    try {
      final expiryDate = DateTime.parse(expiryDateStr);
      return DateTime.now().isBefore(expiryDate);
    } catch (e) {
      return false;
    }
  }

  /// Save subscription status
  Future<bool> saveSubscription(
    bool hasSubscription, {
    DateTime? expiryDate,
    String? subscriptionType,
  }) async {
    await saveBool(AppConstants.keyHasSubscription, hasSubscription);
    if (expiryDate != null) {
      await saveString(
        AppConstants.keySubscriptionExpiryDate,
        expiryDate.toIso8601String(),
      );
    }
    if (subscriptionType != null) {
      await saveString(AppConstants.keySubscriptionType, subscriptionType);
    }
    return true;
  }

  /// Get subscription expiry date
  DateTime? getSubscriptionExpiryDate() {
    final expiryDateStr = getString(AppConstants.keySubscriptionExpiryDate);
    if (expiryDateStr == null) return null;
    try {
      return DateTime.parse(expiryDateStr);
    } catch (e) {
      return null;
    }
  }

  /// Get subscription type
  String? getSubscriptionType() {
    return getString(AppConstants.keySubscriptionType);
  }

  /// Cancel subscription
  Future<bool> cancelSubscription() async {
    await saveBool(AppConstants.keyHasSubscription, false);
    await remove(AppConstants.keySubscriptionExpiryDate);
    await remove(AppConstants.keySubscriptionType);
    return true;
  }
}
