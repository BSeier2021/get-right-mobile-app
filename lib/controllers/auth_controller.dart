import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:get_right/Local%20Storage/local_storage.dart';
import 'package:get_right/models/customer_profile_dto.dart';
import 'package:get_right/models/exercise_plan_option.dart';
import 'package:get_right/models/fitness_level_option.dart';
import 'package:get_right/models/user_goal_option.dart';
import 'package:get_right/models/user_preference_option.dart';
import 'package:get_right/models/food_item.dart';
import 'package:get_right/models/food_log_detail.dart';
import 'package:get_right/models/nutrition_custom_foods_page.dart';
import 'package:get_right/models/nutrition_meal_type_option.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/repo/auth_repo.dart';
import 'package:get_right/repo/marketplace_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/services/chat_socket_service.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/utils/bundle_card_mapper.dart';
import 'package:get_right/utils/customer_profile_enums.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

/// Routes after async work + [GetxController.update] in the same frame can hit
/// `Navigator._debugLocked`; scheduling avoids that.
void _scheduleGetNavigation(void Function() action) {
  WidgetsBinding.instance.addPostFrameCallback((_) => action());
}

/// Backend envelopes vary: some send only `status` / `statusCode` with HTTP 200-style bodies.
bool _apiEnvelopeSuccess(Map<String, dynamic> root) {
  final s = root['success'];
  if (s == true || s == 1) return true;
  if (s is String && s.toLowerCase() == 'true') return true;
  final st = root['status'];
  if (st == 200 || st == '200') return true;
  final sc = root['statusCode'];
  if (sc == 200 || sc == '200') return true;
  return false;
}

/// Auth controller: signup, OTP, and login flows (signup uses live API).
class AuthController extends GetxController {
  static const _deviceTokenStorageKey = 'app_install_device_token';

  final StorageService _storageService;
  final AuthRepository _authRepo = AuthRepository();

  AuthController(this._storageService);

  @override
  void onInit() {
    super.onInit();
    _syncNetworkBearerFromStorage();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<UserPreferenceOption> _preferences = [];
  List<UserPreferenceOption> get preferences => List.unmodifiable(_preferences);

  bool _preferencesLoading = false;
  bool get preferencesLoading => _preferencesLoading;

  String? _preferencesError;
  String? get preferencesError => _preferencesError;

  List<UserGoalOption> _goals = [];
  List<UserGoalOption> get goals => List.unmodifiable(_goals);

  bool _goalsLoading = false;
  bool get goalsLoading => _goalsLoading;

  String? _goalsError;
  String? get goalsError => _goalsError;

  List<FitnessLevelOption> _fitnessLevels = [];
  List<FitnessLevelOption> get fitnessLevels => List.unmodifiable(_fitnessLevels);

  bool _fitnessLevelsLoading = false;
  bool get fitnessLevelsLoading => _fitnessLevelsLoading;

  String? _fitnessLevelsError;
  String? get fitnessLevelsError => _fitnessLevelsError;

  List<ExercisePlanOption> _exercisePlans = [];
  List<ExercisePlanOption> get exercisePlans => List.unmodifiable(_exercisePlans);

  bool _exercisePlansLoading = false;
  bool get exercisePlansLoading => _exercisePlansLoading;

  String? _exercisePlansError;
  String? get exercisePlansError => _exercisePlansError;

  CustomerProfileDto? _customerProfile;
  CustomerProfileDto? get customerProfile => _customerProfile;

  bool _customerProfileLoading = false;
  bool get customerProfileLoading => _customerProfileLoading;

  String? _customerProfileError;
  String? get customerProfileError => _customerProfileError;

  List<NutritionMealTypeOption> _nutritionMealTypes = [];
  List<NutritionMealTypeOption> get nutritionMealTypes => List.unmodifiable(_nutritionMealTypes);

  bool _nutritionMealTypesLoading = false;
  bool get nutritionMealTypesLoading => _nutritionMealTypesLoading;

  String? _nutritionMealTypesError;
  String? get nutritionMealTypesError => _nutritionMealTypesError;

  String? _tempEmail;
  String? _pendingSignupUserId;

  /// Set after successful forgot-password API; used when navigating to OTP / reset.
  String? _forgotPasswordUserId;
  String? get forgotPasswordUserId => _forgotPasswordUserId;

  /// Set after successful signup; pass to OTP route for verify-OTP API.
  String? get pendingSignupUserId => _pendingSignupUserId;

  String _deviceTypeLabel() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'IOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  Future<String> _ensureDeviceToken() async {
    var token = _storageService.getString(_deviceTokenStorageKey);
    if (token == null || token.isEmpty) {
      token = 'getright-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
      await _storageService.saveString(_deviceTokenStorageKey, token);
    }
    return token;
  }

  void _snackError(String title, Object e) {
    final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
    Get.snackbar(title, msg, snackPosition: SnackPosition.BOTTOM);
  }

  /// Login / profile flags: only [bool] false or string "false"/"0" count as false; null or missing → not false.
  bool _isExplicitlyFalse(dynamic v) {
    if (v == false) return true;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'false' || s == '0';
    }
    return false;
  }

  /// Customer app must not sign in trainer accounts (`role`: `Trainer` on login/auto-login payloads).
  bool _loginDataIsTrainerRole(Map<String, dynamic> data) {
    final role = data['role']?.toString().trim();
    if (role != null && role.isNotEmpty && role.toLowerCase() == 'trainer') return true;
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      final userRole = user['role']?.toString().trim();
      if (userRole != null && userRole.isNotEmpty && userRole.toLowerCase() == 'trainer') return true;
    }
    return false;
  }

  void _persistRememberMeCredentials(bool rememberMe, String email, String password) {
    final ls = Get.isRegistered<LocalStorage>() ? Get.find<LocalStorage>() : Get.put(LocalStorage());
    if (rememberMe) {
      ls.saveCredentials(email: email.trim(), password: password);
    } else {
      ls.clearSavedCredentials();
      ls.setRememberMe(false);
    }
  }

  /// SharedPreferences + GetStorage token so [NetworkApiService] sends `Bearer` on API calls.
  Future<void> _persistAccessToken(String token) async {
    var cleaned = token.trim();
    if (cleaned.toLowerCase().startsWith('bearer ')) {
      cleaned = cleaned.substring(7).trim();
    }
    if (cleaned.isEmpty) return;
    await _storageService.saveToken(cleaned);
    await _storageService.saveLoginStatus(true);
    final ls = Get.isRegistered<LocalStorage>() ? Get.find<LocalStorage>() : Get.put(LocalStorage());
    ls.saveAccessToken(cleaned);
    _syncNetworkBearerFromStorage();
    unawaited(_connectChatSocketAfterAuth());
  }

  /// Opens the chat socket once a JWT is available (login, OTP, auto-login, create profile).
  Future<void> _connectChatSocketAfterAuth() async {
    try {
      await ChatSocketService.instance.connectAfterAuth();
    } catch (e) {
      debugPrint('[Auth] chat socket connect failed: $e');
    }
  }

  void _disconnectChatSocket() {
    ChatSocketService.instance.disconnect();
  }

  /// Removes only JWT storage so a stale token cannot be sent after OTP until a new token is saved.
  Future<void> _clearStaleJwtOnly() async {
    await _storageService.remove(AppConstants.keyUserToken);
    await _storageService.saveLoginStatus(false);
    if (Get.isRegistered<LocalStorage>()) {
      Get.find<LocalStorage>().deleteAccessToken();
    }
  }

  /// [NetworkApiService] reads JWT from [LocalStorage]; [StorageService] also stores it. Sync avoids 410 when GetStorage was empty or stale.
  void _syncNetworkBearerFromStorage() {
    final t = _storageService.getToken();
    if (t == null || t.isEmpty) return;
    final ls = Get.isRegistered<LocalStorage>() ? Get.find<LocalStorage>() : Get.put(LocalStorage());
    ls.saveAccessToken(t);
  }

  // Note: Removed onInit auto-navigation - Splash screen handles initial routing

  /// Check if onboarding has been completed
  bool isOnboardingComplete() {
    return _storageService.isOnboardingComplete();
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    await _storageService.completeOnboarding();
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _storageService.isLoggedIn();
  }

  /// Loads `GET /user/preferences` → `data.preferences` for onboarding preference step.
  Future<void> fetchPreferences() async {
    try {
      _preferencesLoading = true;
      _preferencesError = null;
      update();

      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getPreferencesRepo();

      if (response is! Map<String, dynamic>) {
        _preferences = [];
        _preferencesError = 'Unexpected response from server';
        return;
      }

      if (response['success'] != true) {
        _preferences = [];
        _preferencesError = response['message']?.toString() ?? 'Could not load preferences';
        return;
      }

      final data = response['data'];
      final raw = data is Map<String, dynamic> ? data['preferences'] : null;
      final list = <UserPreferenceOption>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            final p = UserPreferenceOption.fromJson(e);
            if (p.id.isNotEmpty && p.name.isNotEmpty) {
              list.add(p);
            }
          } else if (e is Map) {
            final p = UserPreferenceOption.fromJson(Map<String, dynamic>.from(e));
            if (p.id.isNotEmpty && p.name.isNotEmpty) {
              list.add(p);
            }
          }
        }
      }

      _preferences = list;
      if (list.isEmpty) {
        _preferencesError = 'No preferences available';
      }
    } on BadRequestException catch (e) {
      _preferences = [];
      _preferencesError = e.message;
    } on UnauthorizedException catch (e) {
      _preferences = [];
      _preferencesError = e.message;
    } on ForbiddenException catch (e) {
      _preferences = [];
      _preferencesError = e.message;
    } on NoInternetException catch (e) {
      _preferences = [];
      _preferencesError = e.message;
    } on RequestTimeoutException catch (e) {
      _preferences = [];
      _preferencesError = e.message;
    } on ServerException catch (e) {
      _preferences = [];
      _preferencesError = e.message;
    } catch (e) {
      _preferences = [];
      _preferencesError = e.toString();
    } finally {
      _preferencesLoading = false;
      update();
    }
  }

  /// Loads `GET /user/goals` → `data.goals` for onboarding goal step.
  Future<void> fetchGoals() async {
    try {
      _goalsLoading = true;
      _goalsError = null;
      update();

      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getGoalsRepo();

      if (response is! Map<String, dynamic>) {
        _goals = [];
        _goalsError = 'Unexpected response from server';
        return;
      }

      if (response['success'] != true) {
        _goals = [];
        _goalsError = response['message']?.toString() ?? 'Could not load goals';
        return;
      }

      final data = response['data'];
      final raw = data is Map<String, dynamic> ? data['goals'] : null;
      final list = <UserGoalOption>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            final g = UserGoalOption.fromJson(e);
            if (g.id.isNotEmpty && g.name.isNotEmpty) {
              list.add(g);
            }
          } else if (e is Map) {
            final g = UserGoalOption.fromJson(Map<String, dynamic>.from(e));
            if (g.id.isNotEmpty && g.name.isNotEmpty) {
              list.add(g);
            }
          }
        }
      }

      _goals = list;
      if (list.isEmpty) {
        _goalsError = 'No goals available';
      }
    } on BadRequestException catch (e) {
      _goals = [];
      _goalsError = e.message;
    } on UnauthorizedException catch (e) {
      _goals = [];
      _goalsError = e.message;
    } on ForbiddenException catch (e) {
      _goals = [];
      _goalsError = e.message;
    } on NoInternetException catch (e) {
      _goals = [];
      _goalsError = e.message;
    } on RequestTimeoutException catch (e) {
      _goals = [];
      _goalsError = e.message;
    } on ServerException catch (e) {
      _goals = [];
      _goalsError = e.message;
    } catch (e) {
      _goals = [];
      _goalsError = e.toString();
    } finally {
      _goalsLoading = false;
      update();
    }
  }

  /// Loads `GET /user/fitness-level` → `data.fitnessLevels` for onboarding.
  Future<void> fetchFitnessLevels() async {
    try {
      _fitnessLevelsLoading = true;
      _fitnessLevelsError = null;
      update();

      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getFitnessLevelsRepo();

      if (response is! Map<String, dynamic>) {
        _fitnessLevels = [];
        _fitnessLevelsError = 'Unexpected response from server';
        return;
      }

      if (response['success'] != true) {
        _fitnessLevels = [];
        _fitnessLevelsError = response['message']?.toString() ?? 'Could not load fitness levels';
        return;
      }

      final data = response['data'];
      final raw = data is Map<String, dynamic> ? data['fitnessLevels'] : null;
      final list = <FitnessLevelOption>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            final f = FitnessLevelOption.fromJson(e);
            if (f.value.isNotEmpty) {
              list.add(f);
            }
          } else if (e is Map) {
            final f = FitnessLevelOption.fromJson(Map<String, dynamic>.from(e));
            if (f.value.isNotEmpty) {
              list.add(f);
            }
          }
        }
      }

      _fitnessLevels = list;
      if (list.isEmpty) {
        _fitnessLevelsError = 'No fitness levels available';
      }
    } on BadRequestException catch (e) {
      _fitnessLevels = [];
      _fitnessLevelsError = e.message;
    } on UnauthorizedException catch (e) {
      _fitnessLevels = [];
      _fitnessLevelsError = e.message;
    } on ForbiddenException catch (e) {
      _fitnessLevels = [];
      _fitnessLevelsError = e.message;
    } on NoInternetException catch (e) {
      _fitnessLevels = [];
      _fitnessLevelsError = e.message;
    } on RequestTimeoutException catch (e) {
      _fitnessLevels = [];
      _fitnessLevelsError = e.message;
    } on ServerException catch (e) {
      _fitnessLevels = [];
      _fitnessLevelsError = e.message;
    } catch (e) {
      _fitnessLevels = [];
      _fitnessLevelsError = e.toString();
    } finally {
      _fitnessLevelsLoading = false;
      update();
    }
  }

  /// Loads `GET /user/exercise-plan` → `data.exercisePlans` for onboarding.
  Future<void> fetchExercisePlans() async {
    try {
      _exercisePlansLoading = true;
      _exercisePlansError = null;
      update();

      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getExercisePlansRepo();

      if (response is! Map<String, dynamic>) {
        _exercisePlans = [];
        _exercisePlansError = 'Unexpected response from server';
        return;
      }

      if (response['success'] != true) {
        _exercisePlans = [];
        _exercisePlansError = response['message']?.toString() ?? 'Could not load exercise plans';
        return;
      }

      final data = response['data'];
      final raw = data is Map<String, dynamic> ? data['exercisePlans'] : null;
      final list = <ExercisePlanOption>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            final p = ExercisePlanOption.fromJson(e);
            if (p.value.isNotEmpty) {
              list.add(p);
            }
          } else if (e is Map) {
            final p = ExercisePlanOption.fromJson(Map<String, dynamic>.from(e));
            if (p.value.isNotEmpty) {
              list.add(p);
            }
          }
        }
      }

      _exercisePlans = list;
      if (list.isEmpty) {
        _exercisePlansError = 'No exercise plans available';
      }
    } on BadRequestException catch (e) {
      _exercisePlans = [];
      _exercisePlansError = e.message;
    } on UnauthorizedException catch (e) {
      _exercisePlans = [];
      _exercisePlansError = e.message;
    } on ForbiddenException catch (e) {
      _exercisePlans = [];
      _exercisePlansError = e.message;
    } on NoInternetException catch (e) {
      _exercisePlans = [];
      _exercisePlansError = e.message;
    } on RequestTimeoutException catch (e) {
      _exercisePlans = [];
      _exercisePlansError = e.message;
    } on ServerException catch (e) {
      _exercisePlans = [];
      _exercisePlansError = e.message;
    } catch (e) {
      _exercisePlans = [];
      _exercisePlansError = e.toString();
    } finally {
      _exercisePlansLoading = false;
      update();
    }
  }

  String _slugToReadable(String slug) {
    return slug.split('_').where((s) => s.isNotEmpty).map((s) => '${s[0].toUpperCase()}${s.length > 1 ? s.substring(1).toLowerCase() : ''}').join(' ');
  }

  Future<void> _persistCustomerProfileLocal(CustomerProfileDto dto) async {
    if (dto.fullName != null && dto.fullName!.trim().isNotEmpty) {
      await _storageService.saveName(dto.fullName!.trim());
    }
    if (dto.email.trim().isNotEmpty) {
      await _storageService.saveEmail(dto.email.trim());
    }
    await _storageService.saveUserId(dto.userId);
    final ls = Get.isRegistered<LocalStorage>() ? Get.find<LocalStorage>() : Get.put(LocalStorage());
    ls.saveuserid(dto.userId);

    if (dto.dateofbirth != null && dto.dateofbirth!.trim().isNotEmpty) {
      await _storageService.saveString('user_date_of_birth', dto.dateofbirth!.trim());
    }
    if (dto.gender != null && dto.gender!.trim().isNotEmpty) {
      await _storageService.saveString('user_gender', dto.gender!.trim());
    }
    if (dto.phoneNumber != null && dto.phoneNumber!.trim().isNotEmpty) {
      await _storageService.saveString('user_phone', dto.phoneNumber!.trim());
    }
    if (dto.bio != null && dto.bio!.trim().isNotEmpty) {
      await _storageService.saveString('user_bio', dto.bio!.trim());
    }
    if (dto.primaryFocus != null && dto.primaryFocus!.trim().isNotEmpty) {
      await _storageService.saveUserPreference(_slugToReadable(dto.primaryFocus!.trim()));
    }
    if (dto.mainGoals.isNotEmpty) {
      await _storageService.saveUserGoals(dto.mainGoals.map(_slugToReadable).toList());
    }
    if (dto.fitnessLevel != null && dto.fitnessLevel!.trim().isNotEmpty) {
      await _storageService.saveFitnessLevel(dto.fitnessLevel!.trim());
    }
    if (dto.exerciseFrequency != null && dto.exerciseFrequency!.trim().isNotEmpty) {
      await _storageService.saveExerciseFrequency(dto.exerciseFrequency!.trim());
    }
    if (dto.profilePictureUrl != null && dto.profilePictureUrl!.trim().isNotEmpty) {
      await _storageService.saveProfilePictureUrl(dto.profilePictureUrl!.trim());
    }
  }

  /// Persists login/auto-login `data` into [customerProfile] + [StorageService] for drawer/header UI.
  Future<void> _applyLoginSessionFromData(Map<String, dynamic> data) async {
    final dto = CustomerProfileDto.fromLoginData(data);
    if (dto != null) {
      _customerProfile = dto;
      await _persistCustomerProfileLocal(dto);
      update();
      return;
    }

    final user = data['user'];
    if (user is! Map<String, dynamic>) return;

    final id = user['_id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      await _storageService.saveUserId(id);
    }
    final email = user['email']?.toString().trim();
    if (email != null && email.isNotEmpty) {
      await _storageService.saveEmail(email);
    }
    final profile = user['profile'];
    if (profile is Map<String, dynamic>) {
      final name = profile['fullName']?.toString().trim();
      if (name != null && name.isNotEmpty) {
        await _storageService.saveName(name);
      }
      final pic = CustomerProfileDto.tryParse(<String, dynamic>{
        'success': true,
        'data': data,
      })?.profilePictureUrl;
      if (pic != null && pic.isNotEmpty) {
        await _storageService.saveProfilePictureUrl(pic);
      }
    }
    update();
  }

  /// Loads `GET /customer/profile` and parses into [customerProfile]; syncs key fields to [StorageService].
  Future<void> fetchCustomerProfile() async {
    try {
      _customerProfileLoading = true;
      _customerProfileError = null;
      update();

      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getProfileRepo();

      if (response is! Map<String, dynamic>) {
        _customerProfileError = 'Unexpected response from server';
        return;
      }

      if (response['success'] != true) {
        final msg = response['message'];
        if (msg is List && msg.isNotEmpty) {
          _customerProfileError = msg.map((e) => e is Map ? (e['message'] ?? e).toString() : e.toString()).join('; ');
        } else {
          _customerProfileError = msg?.toString() ?? 'Could not load profile';
        }
        return;
      }

      final dto = CustomerProfileDto.tryParse(response);
      if (dto == null) {
        _customerProfileError = 'Invalid profile data';
        return;
      }

      _customerProfile = dto;
      await _persistCustomerProfileLocal(dto);
    } on BadRequestException catch (e) {
      _customerProfileError = e.message;
    } on UnauthorizedException catch (e) {
      _customerProfileError = e.message;
    } on ForbiddenException catch (e) {
      _customerProfileError = e.message;
    } on NotFoundException catch (e) {
      // Common when the account exists but customer profile hasn't been created yet.
      // Keep the app usable and show a clear CTA on Profile screen.
      _customerProfileError = e.message.isNotEmpty ? e.message : 'Profile not found. Please create your profile.';
    } on NoInternetException catch (e) {
      _customerProfileError = e.message;
    } on RequestTimeoutException catch (e) {
      _customerProfileError = e.message;
    } on ServerException catch (e) {
      _customerProfileError = e.message;
    } catch (e) {
      _customerProfileError = e.toString();
    } finally {
      _customerProfileLoading = false;
      update();
    }
  }

  /// Raw JSON from `GET /marketplace/programs` (paginated). The marketplace screen uses [MarketplaceRepository.fetchBrowsePrograms] to parse; this is available for other callers.
  Future<dynamic> getMarketplaceProgramsRaw({int page = 1, int perPage = 20}) {
    return _authRepo.getMarketplaceProgramsRepo(page: page, perPage: perPage);
  }

  /// Raw JSON from `GET /customer/bundle`. Prefer [MarketplaceRepository.fetchBrowseBundles] for parsed cards.
  Future<dynamic> getMarketplaceBundlesRaw({int page = 1, int perPage = 10}) {
    return _authRepo.getMarketplaceBundlesRepo(page: page, perPage: perPage);
  }

  /// `GET /customer/program/enrolled` — [status]: active | scheduled | completed | cancelled.
  Future<CustomerEnrolledProgramsPage?> fetchCustomerEnrolledPrograms({
    int page = 1,
    int limit = 10,
    required String status,
  }) async {
    final st = status.trim().toLowerCase();
    if (st.isEmpty) return null;
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getCustomerEnrolledProgramsRepo(page: page, limit: limit, status: st);
      if (response is! Map<String, dynamic>) {
        _snackError('My programs', 'Unexpected response from server');
        return null;
      }
      if (response['success'] != true) {
        _snackError('My programs', response['message']?.toString() ?? 'Could not load programs');
        return null;
      }
      final data = response['data'];
      if (data is! Map) {
        return CustomerEnrolledProgramsPage(enrollments: const [], hasNextPage: false, currentPage: page, totalDocs: 0);
      }
      final dm = Map<String, dynamic>.from(data);
      final raw = dm['enrollments'];
      final out = <Map<String, dynamic>>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map) out.add(Map<String, dynamic>.from(e));
        }
      }
      final hasNext = dm['hasNextPage'] == true;
      final curPage = (dm['currentPage'] as num?)?.toInt() ?? page;
      final total = (dm['totalDocs'] as num?)?.toInt() ?? out.length;
      return CustomerEnrolledProgramsPage(
        enrollments: out,
        hasNextPage: hasNext,
        currentPage: curPage,
        totalDocs: total,
      );
    } on BadRequestException catch (e) {
      _snackError('My programs', e.message);
      return null;
    } on UnauthorizedException catch (e) {
      _snackError('My programs', e.message);
      return null;
    } on ForbiddenException catch (e) {
      _snackError('My programs', e.message);
      return null;
    } on NoInternetException catch (e) {
      _snackError('My programs', e.message);
      return null;
    } on RequestTimeoutException catch (e) {
      _snackError('My programs', e.message);
      return null;
    } on ServerException catch (e) {
      _snackError('My programs', e.message);
      return null;
    } on NotFoundException catch (e) {
      _snackError('My programs', e.message);
      return null;
    } catch (e) {
      _snackError('My programs', e);
      return null;
    }
  }

  /// `GET /customer/bundle/:id` — returns a map aligned with bundle detail UI, or null.
  Future<Map<String, dynamic>?> fetchMarketplaceBundleDetail(String bundleId) async {
    final id = bundleId.trim();
    if (id.isEmpty) return null;
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getMarketplaceBundleDetailRepo(id);
      debugPrint('========== [BundleDetail API] GET /customer/bundle/$id ==========');
      try {
        debugPrint(const JsonEncoder.withIndent('  ').convert(response));
      } catch (_) {
        debugPrint(response.toString());
      }
      debugPrint('================================================================');
      if (response is! Map<String, dynamic>) {
        _snackError('Bundle', 'Unexpected response from server');
        return null;
      }
      if (response['success'] != true) {
        _snackError('Bundle', response['message']?.toString() ?? 'Could not load bundle');
        return null;
      }
      return _parseMarketplaceBundleDetailResponse(response);
    } on BadRequestException catch (e) {
      _snackError('Bundle', e.message);
      return null;
    } on UnauthorizedException catch (e) {
      _snackError('Bundle', e.message);
      return null;
    } on ForbiddenException catch (e) {
      _snackError('Bundle', e.message);
      return null;
    } on NoInternetException catch (e) {
      _snackError('Bundle', e.message);
      return null;
    } on RequestTimeoutException catch (e) {
      _snackError('Bundle', e.message);
      return null;
    } on ServerException catch (e) {
      _snackError('Bundle', e.message);
      return null;
    } on NotFoundException catch (e) {
      _snackError('Bundle', e.message);
      return null;
    } catch (e) {
      _snackError('Bundle', e);
      return null;
    }
  }

  Map<String, dynamic>? _parseMarketplaceBundleDetailResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) return null;
    final dm = Map<String, dynamic>.from(data);
    Map<String, dynamic>? inner;
    if (dm['bundle'] is Map) {
      inner = Map<String, dynamic>.from(dm['bundle'] as Map);
    } else if (dm['data'] is Map) {
      inner = Map<String, dynamic>.from(dm['data'] as Map);
    } else {
      inner = Map<String, dynamic>.from(dm);
    }

    final pricingResolved = resolveBundlePricingFromApi(inner);
    final bundlePrice = (pricingResolved['bundlePrice'] as num?)?.toDouble() ?? 0.0;
    final totalValue = (pricingResolved['totalValue'] as num?)?.toDouble() ?? bundlePrice;
    final discount = (pricingResolved['discount'] as num?)?.toInt() ?? 0;

    final programsRaw = inner['programs'];
    final programs = <Map<String, dynamic>>[];
    if (programsRaw is List) {
      for (final e in programsRaw) {
        if (e is! Map) continue;
        final p = Map<String, dynamic>.from(e);
        final row = p['display'] is Map ? _bundleDetailProgramRowMarketplace(p) : _bundleDetailProgramRowCustomer(p);
        programs.add(row);
      }
    }

    var imageUrl = ImageUrlSanitizer.asHttpUrlOrNull(inner['coverImageUrl']?.toString()) ?? '';
    if (imageUrl.isEmpty) {
      final th = inner['thumbnail'];
      if (th is Map) {
        imageUrl = ImageUrlSanitizer.asHttpUrlOrNull(th['url']?.toString()) ?? '';
      }
    }

    var trainerName = 'Trainer';
    var trainerInitials = 'T';
    String? trainerId;
    String? trainerAvatarUrl;
    final tr = inner['trainer'];
    if (tr is Map) {
      final tm = Map<String, dynamic>.from(tr);
      trainerId = tm['_id']?.toString().trim();
      if (trainerId != null && trainerId.isEmpty) trainerId = null;
      final prof = tm['profile'];
      if (prof is Map) {
        final fn = prof['fullName']?.toString().trim();
        if (fn != null && fn.isNotEmpty) trainerName = fn;
        final pic = prof['profilePicture'];
        if (pic is Map) {
          trainerAvatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
        }
      }
      trainerAvatarUrl ??= ImageUrlSanitizer.asHttpUrlOrNull(tm['profilePictureUrl']?.toString());
    }
    if (trainerName.isNotEmpty) {
      trainerInitials = trainerName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
      if (trainerInitials.isEmpty) trainerInitials = trainerName.substring(0, 1).toUpperCase();
    }

    return {
      'id': inner['_id']?.toString() ?? '',
      'title': inner['title']?.toString() ?? '',
      'subtitle': inner['subtitle'],
      'description': inner['description']?.toString() ?? '',
      'bundlePrice': bundlePrice,
      'totalValue': totalValue,
      'discount': discount,
      'imageUrl': imageUrl,
      'programs': programs,
      'whatsIncluded': inner['whatsIncluded'],
      'marketplace_detail': inner['marketplace_detail'],
      if (trainerId != null) 'trainerId': trainerId,
      'trainer': trainerName,
      'trainerImage': trainerInitials,
      if (trainerAvatarUrl != null) 'trainerImageUrl': trainerAvatarUrl,
      'isCertified': inner['isCertified'] == true,
      '_apiBundle': inner,
    };
  }

  /// Program document from `GET /marketplace/bundles/:id` (has `display`).
  Map<String, dynamic> _bundleDetailProgramRowMarketplace(Map<String, dynamic> p) {
    final disp = p['display'] is Map ? Map<String, dynamic>.from(p['display'] as Map) : <String, dynamic>{};
    final instructor = (disp['instructor_name'] ?? 'Trainer').toString().trim();
    final weeks = disp['duration_weeks'] ?? p['durationWeeks'];
    final rating = (disp['average_rating'] as num?)?.toDouble() ?? 0.0;
    final price = (p['price'] as num?)?.toDouble() ?? 0.0;
    final initial = instructor.isNotEmpty ? instructor.substring(0, 1).toUpperCase() : 'T';
    return {
      ...p,
      'id': p['_id']?.toString() ?? '',
      'title': p['title']?.toString() ?? 'Program',
      'trainer': instructor,
      'trainerImage': initial,
      'trainerImageUrl': disp['instructor_avatar_url']?.toString(),
      'price': price,
      'duration': weeks != null ? '${weeks} weeks' : '—',
      'rating': rating,
      'category': p['focus']?.toString() ?? 'Program',
      'goal': p['level']?.toString() ?? '—',
      'imageUrl': ImageUrlSanitizer.asHttpUrlOrNull(p['coverImageUrl']?.toString()),
      'certified': p['isCertified'] == true,
    };
  }

  /// Program document from `GET /customer/bundle/:id` (nested `trainer`, `category`, `promoMedia`).
  Map<String, dynamic> _bundleDetailProgramRowCustomer(Map<String, dynamic> p) {
    var instructor = 'Trainer';
    String? trainerAvatarUrl;
    final tr = p['trainer'];
    if (tr is Map) {
      final prof = tr['profile'];
      if (prof is Map) {
        final fn = prof['fullName']?.toString().trim();
        if (fn != null && fn.isNotEmpty) instructor = fn;
        final pic = prof['profilePicture'];
        if (pic is Map && pic['url'] != null) {
          trainerAvatarUrl = ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
        }
      }
    }
    final weeks = p['durationWeeks'] ?? p['duration'];
    final durationStr = weeks != null ? '${weeks is num ? weeks.toInt() : weeks} weeks' : '—';
    final price = (p['price'] as num?)?.toDouble() ?? 0.0;
    String? imageUrl = ImageUrlSanitizer.asHttpUrlOrNull(p['coverImageUrl']?.toString());
    imageUrl ??= () {
      final pm = p['promoMedia'];
      if (pm is Map) return ImageUrlSanitizer.asHttpUrlOrNull(pm['url']?.toString());
      return null;
    }();
    final cat = p['category'];
    final categoryStr = cat is Map ? (cat['name']?.toString() ?? 'Program') : (p['focus']?.toString() ?? 'Program');
    final initial = instructor.isNotEmpty ? instructor.substring(0, 1).toUpperCase() : 'T';

    return {
      ...p,
      'id': p['_id']?.toString() ?? '',
      'title': p['title']?.toString() ?? 'Program',
      'trainer': instructor,
      'trainerImage': initial,
      if (trainerAvatarUrl != null) 'trainerImageUrl': trainerAvatarUrl,
      'price': price,
      'duration': durationStr,
      'rating': 0.0,
      'category': categoryStr,
      'goal': p['difficultyLevel']?.toString() ?? p['level']?.toString() ?? '—',
      'imageUrl': imageUrl,
      'certified': p['isCertified'] == true,
    };
  }

  /// `GET /customer/program/:id` — map shaped for [ProgramDetailScreen] / marketplace program cards.
  Future<Map<String, dynamic>?> fetchMarketplaceProgramDetail(String programId) async {
    final id = programId.trim();
    if (id.isEmpty) return null;
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getMarketplaceProgramDetailRepo(id);
      if (response is! Map<String, dynamic>) {
        _snackError('Program', 'Unexpected response from server');
        return null;
      }
      if (response['success'] != true) {
        _snackError('Program', response['message']?.toString() ?? 'Could not load program');
        return null;
      }
      return _parseMarketplaceProgramDetailResponse(response);
    } on BadRequestException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on UnauthorizedException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on ForbiddenException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on NoInternetException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on RequestTimeoutException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on ServerException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on NotFoundException catch (e) {
      _snackError('Program', e.message);
      return null;
    } catch (e) {
      _snackError('Program', e);
      return null;
    }
  }

  /// `GET /customer/program/enrolled/:enrollmentId` — nested `program` + enrollment dates/progress for [ProgramDetailScreen].
  Future<Map<String, dynamic>?> fetchEnrolledProgramDetail(String enrollmentId) async {
    final id = enrollmentId.trim();
    if (id.isEmpty) return null;
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getEnrolledProgramDetailRepo(id);
      if (response is! Map<String, dynamic>) {
        _snackError('Program', 'Unexpected response from server');
        return null;
      }
      if (response['success'] != true) {
        _snackError('Program', response['message']?.toString() ?? 'Could not load enrollment');
        return null;
      }
      return _parseEnrolledProgramDetailResponse(response);
    } on BadRequestException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on UnauthorizedException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on ForbiddenException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on NoInternetException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on RequestTimeoutException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on ServerException catch (e) {
      _snackError('Program', e.message);
      return null;
    } on NotFoundException catch (e) {
      _snackError('Program', e.message);
      return null;
    } catch (e) {
      _snackError('Program', e);
      return null;
    }
  }

  Map<String, dynamic>? _parseEnrolledProgramDetailResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map) return null;
    final enrollmentRaw = data['enrollment'];
    if (enrollmentRaw is! Map) return null;
    final enrollment = Map<String, dynamic>.from(enrollmentRaw);
    final progRaw = enrollment['program'];
    if (progRaw is! Map) return null;
    final inner = Map<String, dynamic>.from(progRaw);

    final trainerRef = enrollment['trainer'] ?? inner['trainer'];
    final trainerId = trainerRef is Map ? (trainerRef['_id'] ?? trainerRef['id'])?.toString().trim() ?? '' : trainerRef?.toString().trim() ?? '';
    final display = inner['display'] is Map ? Map<String, dynamic>.from(inner['display'] as Map) : null;
    final trainerName = MarketplaceRepository.trainerDisplayName(trainer: trainerRef, display: display);

    final durationWeeks = MarketplaceRepository.durationWeeksFrom(inner['durationWeeks'] ?? inner['duration']);
    final duration = durationWeeks > 0 ? '$durationWeeks weeks' : '—';

    String? img = ImageUrlSanitizer.asHttpUrlOrNull(inner['coverImageUrl']?.toString());
    final promoMedia = inner['promoMedia'];
    if (img == null && promoMedia is Map) {
      img = ImageUrlSanitizer.asHttpUrlOrNull(promoMedia['url']?.toString());
    }

    final demoVideo = inner['demoVideo'];
    final video = inner['video'];
    final resources = inner['resources'];
    final demoVideoUrl = demoVideo is Map ? demoVideo['url']?.toString() : null;
    final programVideoUrl = video is Map ? video['url']?.toString() : null;
    final resourcesUrl = resources is Map ? resources['url']?.toString() : null;

    final bundlePrograms = enrollment['bundlePrograms'];
    final bundleRaw = enrollment['bundle'];
    final exercisesRaw = inner['exercise'];
    List<Map<String, dynamic>> exercises = [];
    if (exercisesRaw is List) {
      for (final e in exercisesRaw) {
        if (e is Map) exercises.add(Map<String, dynamic>.from(e));
      }
    }

    final price = (inner['price'] as num?)?.toDouble() ?? 0.0;
    final discount = (inner['discount'] as num?)?.toDouble();
    final progressPct = (enrollment['progress'] as num?)?.toDouble();
    final enrollmentStatus = enrollment['status']?.toString();

    return {
      'id': inner['_id']?.toString() ?? '',
      '_id': inner['_id']?.toString() ?? '',
      'enrollmentId': enrollment['_id']?.toString(),
      'trainerId': trainerId.isNotEmpty ? trainerId : inner['trainerId']?.toString(),
      'title': inner['title']?.toString() ?? 'Program',
      'subtitle': inner['subtitle']?.toString(),
      'trainer': trainerName,
      'trainerImage': MarketplaceRepository.initialsFromName(trainerName),
      'trainerAvatarUrl': MarketplaceRepository.trainerAvatarUrlFromApiNode(trainerRef is Map ? trainerRef : inner['trainer']),
      'price': price,
      if (discount != null) 'discount': discount,
      'duration': duration,
      'category': (() {
        final cat = inner['category'];
        if (cat is Map && cat['name'] != null) return cat['name'].toString();
        if (cat != null) return cat.toString();
        return 'Program';
      })(),
      'goal': (inner['difficultyLevel'] ?? inner['level'])?.toString() ?? 'Fitness',
      'certified': inner['isCertified'] == true,
      'rating': 0.0,
      'students': 0,
      'reviews': 0,
      'description': inner['description']?.toString() ?? '',
      'status': enrollmentStatus ?? inner['status']?.toString(),
      'purchased': true,
      'isEnrolled': true,
      'imageUrl': img,
      'demoVideoUrl': demoVideoUrl,
      'demoVideo': demoVideo,
      'programVideoUrl': programVideoUrl,
      'video': video,
      'resourcesUrl': resourcesUrl,
      'resources': resources,
      'whatsIncluded': inner['whatsIncluded'],
      'weeks': inner['weeks'],
      '_apiProgram': inner,
      'enrollment': enrollment,
      'enrollmentProgress': progressPct ?? 0,
      'enrollmentStartDate': enrollment['startDate'],
      'enrollmentEndDate': enrollment['endDate'],
      'exercises': exercises,
      if (bundlePrograms is List) 'bundlePrograms': bundlePrograms,
      if (bundleRaw is Map) ...{
        'enrolledBundle': Map<String, dynamic>.from(bundleRaw),
        'bundleId': (bundleRaw['_id'] ?? bundleRaw['id'])?.toString(),
        'bundleTitle': bundleRaw['title']?.toString(),
        'bundlePrice': (bundleRaw['bundlePrice'] as num?)?.toDouble() ?? (bundleRaw['price'] as num?)?.toDouble(),
      },
    };
  }

  /// `POST /customer/program/enroll` — enroll in a program or bundle; shows success snackbar from API when applicable.
  Future<Map<String, dynamic>?> enrollProgram({required String programOrBundleId, required bool isBundle}) async {
    final id = programOrBundleId.trim();
    if (id.isEmpty) {
      _snackError('Enroll', 'Missing program id');
      return null;
    }
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.enrollProgramRepo(id: id, isBundle: isBundle);
      if (response is! Map<String, dynamic>) {
        _snackError('Enroll', 'Unexpected response from server');
        return null;
      }
      if (response['success'] != true) {
        final message = response['message']?.toString() ?? 'Enrollment failed';
        if (message.toLowerCase().contains('already enrolled')) {
          Get.snackbar('Enroll', 'You are already enrolled in this program', snackPosition: SnackPosition.BOTTOM);
          return <String, dynamic>{};
        }
        _snackError('Enroll', message);
        return null;
      }
      final msg = response['message']?.toString() ?? 'Enrolled successfully';
      Get.snackbar('Success', msg, snackPosition: SnackPosition.BOTTOM);
      final data = response['data'];
      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        final single = dm['enrollment'];
        if (single is Map) {
          return Map<String, dynamic>.from(single);
        }
        // Bundle enroll returns `data.enrollments` (one row per program in the bundle).
        final rawList = dm['enrollments'];
        if (rawList is List) {
          final enrollments = <Map<String, dynamic>>[];
          for (final e in rawList) {
            if (e is Map) enrollments.add(Map<String, dynamic>.from(e));
          }
          if (enrollments.isEmpty) return <String, dynamic>{};
          final first = enrollments.first;
          return <String, dynamic>{
            'enrollments': enrollments,
            'startDate': first['startDate'],
            'endDate': first['endDate'],
          };
        }
      }
      return <String, dynamic>{};
    } on BadRequestException catch (e) {
      if (e.message.toLowerCase().contains('already enrolled')) {
        Get.snackbar('Enroll', 'You are already enrolled in this program', snackPosition: SnackPosition.BOTTOM);
        return <String, dynamic>{};
      }
      _snackError('Enroll', e.message);
      return null;
    } on UnauthorizedException catch (e) {
      _snackError('Enroll', e.message);
      return null;
    } on ForbiddenException catch (e) {
      _snackError('Enroll', e.message);
      return null;
    } on ConflictException catch (e) {
      if (e.message.toLowerCase().contains('already enrolled')) {
        Get.snackbar('Enroll', 'You are already enrolled in this program', snackPosition: SnackPosition.BOTTOM);
        return <String, dynamic>{};
      }
      _snackError('Enroll', e.message);
      return null;
    } on NoInternetException catch (e) {
      _snackError('Enroll', e.message);
      return null;
    } on RequestTimeoutException catch (e) {
      _snackError('Enroll', e.message);
      return null;
    } on ServerException catch (e) {
      _snackError('Enroll', e.message);
      return null;
    } on NotFoundException catch (e) {
      _snackError('Enroll', e.message);
      return null;
    } catch (e) {
      _snackError('Enroll', e);
      return null;
    }
  }

  Map<String, dynamic>? _parseMarketplaceProgramDetailResponse(Map<String, dynamic> response) {
    final data = response['data'];
    Map<String, dynamic>? inner;
    if (data is Map && data['program'] is Map) {
      inner = Map<String, dynamic>.from(data['program'] as Map);
    } else if (data is Map && data['data'] is Map) {
      inner = Map<String, dynamic>.from(data['data'] as Map);
    } else if (data is Map) {
      inner = Map<String, dynamic>.from(data);
    }
    if (inner == null) return null;
    final program = inner;

    final md = inner['marketplace_detail'] is Map ? Map<String, dynamic>.from(inner['marketplace_detail'] as Map) : <String, dynamic>{};
    final trainer = md['trainer'] is Map ? Map<String, dynamic>.from(md['trainer'] as Map) : <String, dynamic>{};
    final trainerRaw = inner['trainer'] is Map ? Map<String, dynamic>.from(inner['trainer'] as Map) : <String, dynamic>{};
    final trainerProfile = trainerRaw['profile'] is Map ? Map<String, dynamic>.from(trainerRaw['profile'] as Map) : <String, dynamic>{};
    final stats = md['stats'] is Map ? Map<String, dynamic>.from(md['stats'] as Map) : <String, dynamic>{};
    final ext = inner['catalog_extensions'] is Map ? Map<String, dynamic>.from(inner['catalog_extensions'] as Map) : <String, dynamic>{};
    final attrs = ext['attributes'] is Map ? Map<String, dynamic>.from(ext['attributes'] as Map) : <String, dynamic>{};
    final hero = ext['hero_media'] is Map ? Map<String, dynamic>.from(ext['hero_media'] as Map) : <String, dynamic>{};
    final prSum = ext['program_rating_summary'] is Map ? Map<String, dynamic>.from(ext['program_rating_summary'] as Map) : <String, dynamic>{};

    final displayName =
        (trainer['display_name'] ??
                trainerProfile['fullName'] ??
                'Trainer')
            .toString()
            .trim();
    final initial = displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'T';

    final durationLabel = attrs['duration_label']?.toString();
    final weeks = attrs['duration_weeks'] ?? inner['durationWeeks'] ?? inner['duration'];
    final duration = (durationLabel != null && durationLabel.isNotEmpty) ? durationLabel : (weeks != null ? '$weeks weeks' : '—');

    var rating = (stats['average_rating'] as num?)?.toDouble() ?? (inner['ratingAvg'] as num?)?.toDouble() ?? 0.0;
    if (rating == 0.0 && prSum['average_rating'] != null) {
      rating = (prSum['average_rating'] as num).toDouble();
    }
    final reviewCount =
        (stats['review_count'] as num?)?.toInt() ?? (inner['ratingCount'] as num?)?.toInt() ?? (prSum['review_count'] as num?)?.toInt() ?? 0;
    final students = (stats['enrollment_count'] as num?)?.toInt() ?? (ext['student_count'] as num?)?.toInt() ?? 0;

    String? img = ImageUrlSanitizer.asHttpUrlOrNull(inner['coverImageUrl']?.toString());
    img ??= ImageUrlSanitizer.asHttpUrlOrNull(hero['thumbnail_url']?.toString());
    img ??= ImageUrlSanitizer.asHttpUrlOrNull(hero['stream_url']?.toString());
    final promoMedia = inner['promoMedia'];
    if (img == null && promoMedia is Map) {
      img = ImageUrlSanitizer.asHttpUrlOrNull(promoMedia['url']?.toString());
    }

    final purchased = ext['purchased'] == true || inner['isEnrolled'] == true;
    final price = (inner['price'] as num?)?.toDouble() ?? (ext['price'] as num?)?.toDouble() ?? 0.0;
    final demoVideo = inner['demoVideo'];
    final video = inner['video'];
    final resources = inner['resources'];
    final demoVideoUrl = demoVideo is Map ? demoVideo['url']?.toString() : null;
    final programVideoUrl = video is Map ? video['url']?.toString() : null;
    final resourcesUrl = resources is Map ? resources['url']?.toString() : null;

    return {
      'id': inner['_id']?.toString() ?? '',
      'trainerId': inner['trainerId']?.toString() ?? trainerRaw['_id']?.toString(),
      'title': inner['title']?.toString() ?? 'Program',
      'subtitle': inner['subtitle']?.toString(),
      'trainer': displayName,
      'trainerImage': initial,
      'trainerImageUrl':
          ImageUrlSanitizer.asHttpUrlOrNull(trainer['avatar_url']?.toString()) ??
          (() {
            final pic = trainerProfile['profilePicture'];
            if (pic is Map) return ImageUrlSanitizer.asHttpUrlOrNull(pic['url']?.toString());
            return null;
          })(),
      'price': price,
      'duration': duration,
      'category': (() {
        if (attrs['focus'] != null) return attrs['focus'].toString();
        if (program['focus'] != null) return program['focus'].toString();
        final cat = program['category'];
        if (cat is Map && cat['name'] != null) return cat['name'].toString();
        return 'General';
      })(),
      'goal': (attrs['level'] ?? inner['difficultyLevel'] ?? inner['level'])?.toString() ?? 'Fitness',
      'certified': inner['isCertified'] == true || trainer['is_certified'] == true,
      'rating': rating,
      'students': students,
      'reviews': reviewCount,
      'description': inner['description']?.toString() ?? '',
      'status': inner['status']?.toString(),
      'purchased': purchased,
      'isEnrolled': inner['isEnrolled'] == true || purchased,
      'imageUrl': img,
      'demoVideoUrl': demoVideoUrl,
      'programVideoUrl': programVideoUrl,
      'resourcesUrl': resourcesUrl,
      'weeks': inner['weeks'],
      'whatsIncluded': inner['whatsIncluded'],
      'whats_included': ext['whats_included'],
      'catalog_extensions': ext,
      'marketplace_detail': md,
      '_apiProgram': inner,
    };
  }

  /// Login via `POST /user/auth/login` with email, password, deviceType, deviceToken.
  /// When [rememberMe] is true, email and password are stored in [LocalStorage] for the next visit.
  Future<void> login({required String email, required String password, bool rememberMe = false}) async {
    try {
      _isLoading = true;
      update();

      final deviceToken = await _ensureDeviceToken();
      final response = await _authRepo.loginRepo(email: email, password: password, deviceType: _deviceTypeLabel(), deviceToken: deviceToken);

      if (response is! Map<String, dynamic>) {
        _snackError('Login', 'Unexpected response from server');
        return;
      }

      if (response['success'] != true) {
        final message = response['message']?.toString() ?? 'Login failed';
        _snackError('Login', message);
        return;
      }

      final data = response['data'];
      if (data is Map<String, dynamic> && _loginDataIsTrainerRole(data)) {
        _snackError('Login', 'Trainer accounts cannot sign in here. Please use a customer account.');
        return;
      }

      String? emailToStore;
      var needsEmailVerification = false;
      var needsProfileSetup = false;
      if (data is Map<String, dynamic>) {
        await _applyLoginSessionFromData(data);

        needsEmailVerification = _isExplicitlyFalse(data['isVerified']) || _isExplicitlyFalse(data['is_verified']);
        if (!needsEmailVerification) {
          needsProfileSetup = _isExplicitlyFalse(data['isProfileCompleted']) || _isExplicitlyFalse(data['is_profile_completed']);
        }

        final user = data['user'];
        if (user is Map<String, dynamic>) {
          final id = user['_id']?.toString();
          if (id != null && id.isNotEmpty) {
            final ls = Get.isRegistered<LocalStorage>() ? Get.find<LocalStorage>() : Get.put(LocalStorage());
            ls.saveuserid(id);
          }
          emailToStore = user['email']?.toString();

          needsEmailVerification = needsEmailVerification || _isExplicitlyFalse(user['isVerified']) || _isExplicitlyFalse(user['is_verified']);
          if (!needsEmailVerification) {
            needsProfileSetup = needsProfileSetup || _isExplicitlyFalse(user['isProfileCompleted']) || _isExplicitlyFalse(user['is_profile_completed']);
            final profile = user['profile'];
            if (profile is Map<String, dynamic>) {
              needsProfileSetup = needsProfileSetup || _isExplicitlyFalse(profile['isProfileCompleted']) || _isExplicitlyFalse(profile['is_profile_completed']);
            }
          }
        }
      }
      final resolvedEmail = emailToStore?.trim();
      await _storageService.saveEmail((resolvedEmail != null && resolvedEmail.isNotEmpty) ? resolvedEmail : email);

      if (needsEmailVerification) {
        final uid = _storageService.getUserId();
        if (uid == null || uid.isEmpty) {
          _snackError('Login', 'This account needs email verification, but user id is missing. Please try again.');
          Get.offAllNamed(AppRoutes.home);
          return;
        }
        final em = (resolvedEmail != null && resolvedEmail.isNotEmpty) ? resolvedEmail : email.trim();
        _tempEmail = em;
        _pendingSignupUserId = uid;
        _persistRememberMeCredentials(rememberMe, em, password);
        Get.offAllNamed(AppRoutes.otp, arguments: {'email': em, 'userId': uid, 'fromSignup': false});
        return;
      }

      final token = _tokenFromVerifyResponse(response);
      if (token == null || token.isEmpty) {
        _snackError('Login', 'No access token in response');
        return;
      }
      await _persistAccessToken(token);
      _persistRememberMeCredentials(rememberMe, (resolvedEmail != null && resolvedEmail.isNotEmpty) ? resolvedEmail : email.trim(), password);

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Welcome', message, snackPosition: SnackPosition.BOTTOM);
      }

      if (needsProfileSetup) {
        Get.offAllNamed(AppRoutes.profileSetup);
        return;
      }
      Get.offAllNamed(AppRoutes.home);
    } on BadRequestException catch (e) {
      _snackError('Login', e.message);
    } on UnauthorizedException catch (e) {
      _snackError('Login', e.message);
    } on ForbiddenException catch (e) {
      _snackError('Login', e.message);
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
    } on RequestTimeoutException catch (e) {
      _snackError('Login', e.message);
    } on ServerException catch (e) {
      _snackError('Login', e.message);
    } catch (e) {
      _snackError('Login', e);
    } finally {
      _isLoading = false;
      update();
    }
  }

  Future<void> _clearLocalAuthSession() async {
    _disconnectChatSocket();
    await _storageService.logout();
    if (Get.isRegistered<LocalStorage>()) {
      Get.find<LocalStorage>().deleteAccessToken();
    }
  }

  /// Ensures [NetworkApiService] Bearer matches JWT in [StorageService], with [LocalStorage] fallback after cold start quirks.
  Future<void> _ensurePersistedJwtSyncedForBearer() async {
    _syncNetworkBearerFromStorage();
    final prefsToken = _storageService.getToken();
    if (prefsToken != null && prefsToken.isNotEmpty) return;
    if (!Get.isRegistered<LocalStorage>()) return;
    final g = Get.find<LocalStorage>().getAccessToken();
    if (g is! String || g.isEmpty) return;
    await _storageService.saveToken(g);
    await _storageService.saveLoginStatus(true);
  }

  bool _hasStoredJwtForAutoLogin() {
    final t = _storageService.getToken();
    if (t != null && t.isNotEmpty) return true;
    if (!Get.isRegistered<LocalStorage>()) return false;
    final g = Get.find<LocalStorage>().getAccessToken();
    return g is String && g.isNotEmpty;
  }

  /// Pure outcome of [tryAutoLoginAndRouteFromSplash] — splash decides when/how to navigate.
  /// Each value carries its target [AppRoutes] route name and any [arguments] needed (used by [autoLoginOtp]).
  Map<String, dynamic>? _autoLoginOtpArgs;
  Map<String, dynamic>? get autoLoginOtpArgs => _autoLoginOtpArgs;

  /// Applies `data.user`-shaped payloads and returns the next route; never calls navigation itself.
  /// Mirrors [login]'s branching, minus snackbars / remember-me.
  Future<String> _routeFromPersistedLoginResponse(Map<String, dynamic> response) async {
    final data = response['data'];
    String? emailToStore;
    var needsEmailVerification = false;
    var needsProfileSetup = false;
    if (data is Map<String, dynamic>) {
      if (_loginDataIsTrainerRole(data)) {
        await _clearLocalAuthSession();
        return AppRoutes.onboarding;
      }

      await _applyLoginSessionFromData(data);

      needsEmailVerification = _isExplicitlyFalse(data['isVerified']) || _isExplicitlyFalse(data['is_verified']);
      if (!needsEmailVerification) {
        needsProfileSetup = _isExplicitlyFalse(data['isProfileCompleted']) || _isExplicitlyFalse(data['is_profile_completed']);
      }

      final user = data['user'];
      if (user is Map<String, dynamic>) {
        final id = user['_id']?.toString();
        if (id != null && id.isNotEmpty) {
          final ls = Get.isRegistered<LocalStorage>() ? Get.find<LocalStorage>() : Get.put(LocalStorage());
          ls.saveuserid(id);
        }
        emailToStore = user['email']?.toString();

        needsEmailVerification = needsEmailVerification || _isExplicitlyFalse(user['isVerified']) || _isExplicitlyFalse(user['is_verified']);
        if (!needsEmailVerification) {
          needsProfileSetup = needsProfileSetup || _isExplicitlyFalse(user['isProfileCompleted']) || _isExplicitlyFalse(user['is_profile_completed']);
          final profile = user['profile'];
          if (profile is Map<String, dynamic>) {
            needsProfileSetup = needsProfileSetup || _isExplicitlyFalse(profile['isProfileCompleted']) || _isExplicitlyFalse(profile['is_profile_completed']);
          }
        }
      }
    }
    final resolvedEmail = emailToStore?.trim();
    if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
      await _storageService.saveEmail(resolvedEmail);
    }

    if (needsEmailVerification) {
      final uid = _storageService.getUserId();
      final em = resolvedEmail;
      if (uid == null || uid.isEmpty || em == null || em.isEmpty) {
        await _clearLocalAuthSession();
      }
      // Auto-login: stay on onboarding when user is not verified — do not route to OTP/home.
      _autoLoginOtpArgs = null;
      return AppRoutes.onboarding;
    }

    final token = _tokenFromVerifyResponse(response);
    if (token == null || token.isEmpty) {
      await _clearLocalAuthSession();
      return AppRoutes.onboarding;
    }
    await _persistAccessToken(token);

    if (needsProfileSetup) return AppRoutes.profileSetup;
    return AppRoutes.home;
  }

  /// Resolves the next route after `GET /user/auth/auto-login`. Splash performs the actual `Get.offAllNamed`,
  /// so we never push a route while the splash is mid-transition (which causes
  /// `Navigator !_debugLocked` assertion failures).
  ///
  /// Returns `null` when there's no stored JWT (or the API explicitly invalidated it) — caller should
  /// treat that as "go to onboarding". On transient network/server errors we keep the user signed-in
  /// and route to [AppRoutes.home] using the stored Bearer.
  Future<String?> tryAutoLoginAndRouteFromSplash() async {
    _autoLoginOtpArgs = null;
    await _ensurePersistedJwtSyncedForBearer();
    if (!_hasStoredJwtForAutoLogin()) return null;

    try {
      final response = await _authRepo.autoLoginRepo();
      if (response is! Map<String, dynamic>) {
        _syncNetworkBearerFromStorage();
        unawaited(_connectChatSocketAfterAuth());
        return AppRoutes.home;
      }
      if (response['success'] != true) {
        await _clearLocalAuthSession();
        return null;
      }
      return await _routeFromPersistedLoginResponse(response);
    } on UnauthorizedException catch (_) {
      await _clearLocalAuthSession();
      return null;
    } on ForbiddenException catch (_) {
      await _clearLocalAuthSession();
      return null;
    } on NotFoundException catch (_) {
      // Stale JWT or account removed; must not treat as logged-in or route to home.
      await _clearLocalAuthSession();
      return null;
    } on BadRequestException catch (_) {
      await _clearLocalAuthSession();
      return null;
    } on NoInternetException catch (_) {
      _syncNetworkBearerFromStorage();
      unawaited(_connectChatSocketAfterAuth());
      return AppRoutes.home;
    } on RequestTimeoutException catch (_) {
      _syncNetworkBearerFromStorage();
      unawaited(_connectChatSocketAfterAuth());
      return AppRoutes.home;
    } on ServerException catch (_) {
      _syncNetworkBearerFromStorage();
      unawaited(_connectChatSocketAfterAuth());
      return AppRoutes.home;
    } catch (_) {
      _syncNetworkBearerFromStorage();
      unawaited(_connectChatSocketAfterAuth());
      return AppRoutes.home;
    }
  }

  /// Signup via `/user/auth/signup`. On success, OTP is sent to email; stores user id for verify-OTP.
  Future<bool> signup({required String email, required String password, String role = 'Customer'}) async {
    try {
      _isLoading = true;
      update();

      final deviceToken = await _ensureDeviceToken();
      final response = await _authRepo.signUp(email: email, password: password, deviceType: _deviceTypeLabel(), deviceToken: deviceToken, role: role);

      if (response is! Map<String, dynamic>) {
        _snackError('Sign up', 'Unexpected response from server');
        return false;
      }

      final success = response['success'] == true;
      if (!success) {
        final message = response['message']?.toString() ?? 'Sign up failed';
        _snackError('Sign up', message);
        return false;
      }

      // Any prior JWT would make splash auto-login hit the wrong account until OTP saves the new token.
      await _clearLocalAuthSession();

      final data = response['data'];
      final user = data is Map<String, dynamic> ? data['user'] : null;
      final userId = user is Map<String, dynamic> ? user['_id']?.toString() : null;

      _tempEmail = email;
      _pendingSignupUserId = userId;

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      }

      return true;
    } on BadRequestException catch (e) {
      _snackError('Sign up', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Sign up', e.message);
      return false;
    } on ConflictException catch (e) {
      _snackError('Sign up', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Sign up', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Sign up', e.message);
      return false;
    } catch (e) {
      _snackError('Sign up', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  String? _normalizeJwtString(dynamic raw) {
    if (raw == null) return null;
    var s = raw.toString().trim();
    if (s.isEmpty) return null;
    if (s.toLowerCase().startsWith('bearer ')) {
      s = s.substring(7).trim();
    }
    return s.isEmpty ? null : s;
  }

  Map<String, dynamic>? _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  bool _looksLikeCompactJwt(String s) {
    final parts = s.split('.');
    return parts.length >= 3 && parts.every((p) => p.isNotEmpty);
  }

  /// Picks JWT-like strings from arbitrarily nested maps when keys hint at auth (backend variance).
  String? _tokenFromNestedMaps(dynamic node, {required int maxDepth}) {
    if (maxDepth <= 0) return null;
    final m = _asStringKeyedMap(node);
    if (m == null) return null;
    for (final e in m.entries) {
      final k = e.key.toString().toLowerCase();
      if (k.contains('token') || k.contains('jwt') || k.contains('bearer') || k == 'access' || k == 'authorization') {
        final t = _normalizeJwtString(e.value);
        if (t != null && _looksLikeCompactJwt(t)) return t;
      }
    }
    for (final e in m.entries) {
      final nested = _tokenFromNestedMaps(e.value, maxDepth: maxDepth - 1);
      if (nested != null) return nested;
    }
    return null;
  }

  /// Extracts JWT from login / verify-otp style payloads (nested shapes vary by backend).
  String? _tokenFromVerifyResponse(Map<String, dynamic> json) {
    String? fromMap(Map<String, dynamic> m) {
      const keys = [
        'token',
        'accessToken',
        'access_token',
        'authToken',
        'auth_token',
        'jwt',
        'idToken',
        'bearerToken',
        'access',
        'authorization',
        'Authorization',
        'userToken',
        'user_token',
        'bearer',
      ];
      for (final k in keys) {
        final out = _normalizeJwtString(m[k]);
        if (out != null) return out;
      }
      return null;
    }

    final data = _asStringKeyedMap(json['data']);
    if (data != null) {
      final direct = fromMap(data);
      if (direct != null) return direct;

      final tokens = _asStringKeyedMap(data['tokens']);
      if (tokens != null) {
        final t = fromMap(tokens);
        if (t != null) return t;
      }

      for (final key in ['user', 'session', 'auth', 'payload', 'result', 'customer', 'credentials', 'authentication']) {
        final nested = _asStringKeyedMap(data[key]);
        if (nested != null) {
          final t = fromMap(nested);
          if (t != null) return t;
        }
      }

      final deepData = _tokenFromNestedMaps(data, maxDepth: 5);
      if (deepData != null) return deepData;
    }

    final deepRoot = _tokenFromNestedMaps(json, maxDepth: 3);
    if (deepRoot != null) return deepRoot;

    return fromMap(json);
  }

  /// Verify OTP via `/user/auth/verify-otp` with `userId` + `otp`.
  /// Signup: persists token when present, then [AppRoutes.profileSetup].
  /// Forgot password ([forgotPasswordFlow]): persists token when present (for `POST /user/auth/forget-password` Bearer), then [AppRoutes.resetPassword].
  Future<bool> verifyOTP({required String userId, required String otp, bool forgotPasswordFlow = false}) async {
    try {
      _isLoading = true;
      update();

      final response = await _authRepo.verifyOTPRepo(userId: userId, otp: otp);

      if (response is! Map<String, dynamic>) {
        _snackError('Verification', 'Unexpected response from server');
        return false;
      }

      final success = response['success'] == true;
      if (!success) {
        final message = response['message']?.toString() ?? 'Verification failed';
        _snackError('Verification', message);
        return false;
      }

      final message = response['message']?.toString();

      if (forgotPasswordFlow) {
        final token = _tokenFromVerifyResponse(response);
        if (token == null || token.isEmpty) {
          await _clearStaleJwtOnly();
          _snackError('Verification', 'Could not save reset session. Please request the code again.');
          _scheduleGetNavigation(() => Get.offNamed(AppRoutes.forgotPassword));
          return false;
        }
        await _persistAccessToken(token);
        if (message != null && message.isNotEmpty) {
          Get.snackbar('Verified', message, snackPosition: SnackPosition.BOTTOM);
        }
        _tempEmail = null;
        _forgotPasswordUserId = null;
        _scheduleGetNavigation(() => Get.offNamed(AppRoutes.resetPassword));
        return true;
      }

      await _clearStaleJwtOnly();
      final token = _tokenFromVerifyResponse(response);
      if (token == null || token.isEmpty) {
        await _clearStaleJwtOnly();
        _snackError('Verification', 'Email verified, but session token was missing. Please sign in.');
        _scheduleGetNavigation(() => Get.offAllNamed(AppRoutes.login));
        return false;
      }
      await _persistAccessToken(token);

      await _storageService.saveUserId(userId);
      if (_tempEmail != null) {
        await _storageService.saveEmail(_tempEmail!);
      }

      final data = response['data'];
      final user = data is Map<String, dynamic> ? data['user'] : null;
      if (user is Map<String, dynamic>) {
        final id = user['_id']?.toString();
        if (id != null && id.isNotEmpty) {
          await _storageService.saveUserId(id);
        }
        final email = user['email']?.toString();
        if (email != null && email.isNotEmpty) {
          await _storageService.saveEmail(email);
        }
      }

      if (message != null && message.isNotEmpty) {
        Get.snackbar('Verified', message, snackPosition: SnackPosition.BOTTOM);
      }

      _tempEmail = null;
      _pendingSignupUserId = null;

      _scheduleGetNavigation(() => Get.offNamed(AppRoutes.profileSetup));
      return true;
    } on BadRequestException catch (e) {
      _snackError('Verification', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Verification', e.message);
      return false;
    } on ConflictException catch (e) {
      _snackError('Verification', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Verification', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Verification', e.message);
      return false;
    } catch (e) {
      _snackError('Verification', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Resend OTP — signup: `POST /user/auth/send-otp`. Forgot password: `POST /user/auth/forget` again.
  /// Pass [email] from the OTP screen when available; otherwise uses email from signup (`_tempEmail`).
  Future<void> resendOTP({String? email, bool forgotPasswordFlow = false}) async {
    try {
      _isLoading = true;
      update();

      final resolved = (email != null && email.trim().isNotEmpty) ? email.trim() : _tempEmail;
      if (resolved == null || resolved.isEmpty) {
        Get.snackbar(
          'Resend OTP',
          forgotPasswordFlow ? 'No email found. Go back and try again.' : 'No email found. Go back and sign up again.',
          snackPosition: SnackPosition.BOTTOM,
        );
        if (forgotPasswordFlow) {
          _scheduleGetNavigation(() => Get.back<void>());
        } else {
          _scheduleGetNavigation(() => Get.offAllNamed(AppRoutes.signup));
        }
        return;
      }

      final response = forgotPasswordFlow ? await _authRepo.forgotPasswordRepo(email: resolved) : await _authRepo.sendOtpRepo(email: resolved);
      if (response is! Map<String, dynamic>) {
        _snackError('Resend OTP', 'Unexpected response from server');
        return;
      }

      if (response['success'] == true) {
        final message = response['message']?.toString() ?? 'OTP sent';
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      } else {
        final message = response['message']?.toString() ?? 'Could not resend code';
        _snackError('Resend OTP', message);
      }
    } on BadRequestException catch (e) {
      _snackError('Resend OTP', e.message);
    } on UnauthorizedException catch (e) {
      _snackError('Resend OTP', e.message);
    } on ConflictException catch (e) {
      _snackError('Resend OTP', e.message);
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
    } on RequestTimeoutException catch (e) {
      _snackError('Resend OTP', e.message);
    } on ServerException catch (e) {
      _snackError('Resend OTP', e.message);
    } catch (e) {
      _snackError('Resend OTP', e);
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Create customer profile — `POST /customer/profile/create` (multipart). Saves returned token and user ids.
  Future<bool> createProfile({required String fullName, required String dateofbirth, required String gender, required String phoneNumber, File? profilePicture}) async {
    try {
      _isLoading = true;
      update();

      final response = await _authRepo.createProfileRepo(fullName: fullName, dateofbirth: dateofbirth, gender: gender, phoneNumber: phoneNumber, profilePicture: profilePicture);

      if (response is! Map<String, dynamic>) {
        _snackError('Profile', 'Unexpected response from server');
        return false;
      }

      if (response['success'] != true) {
        final message = response['message']?.toString() ?? 'Could not create profile';
        _snackError('Profile', message);
        return false;
      }

      final token = _tokenFromVerifyResponse(response);
      if (token != null && token.isNotEmpty) {
        await _persistAccessToken(token);
      }

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final user = data['user'];
        if (user is Map<String, dynamic>) {
          final id = user['_id']?.toString();
          if (id != null && id.isNotEmpty) {
            await _storageService.saveUserId(id);
          }
          final email = user['email']?.toString();
          if (email != null && email.isNotEmpty) {
            await _storageService.saveEmail(email);
          }
          final profile = user['profile'];
          if (profile is Map<String, dynamic>) {
            final name = profile['fullName']?.toString();
            if (name != null && name.isNotEmpty) {
              await _storageService.saveName(name);
            }
          }
        }
      }

      await _storageService.saveName(fullName.trim());
      await _storageService.saveString('user_date_of_birth', dateofbirth);
      await _storageService.saveString('user_gender', gender);
      await _storageService.saveString('user_phone', phoneNumber.trim());

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      }

      await _connectChatSocketAfterAuth();
      Get.offNamed(AppRoutes.preferenceSelection);
      return true;
    } on BadRequestException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } catch (e) {
      _snackError('Profile', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// `POST /customer/profile/update` — merges locally stored profile fields with onboarding [routeArgs]
  /// (`primaryFocus` slug, `mainGoals` slugs, `fitnessLevel`, optional [exerciseFrequency]).
  Future<bool> updateCustomerOnboardingProfile({Map<String, dynamic>? routeArgs, String? exerciseFrequency}) async {
    try {
      _isLoading = true;
      update();
      _syncNetworkBearerFromStorage();

      final args = routeArgs ?? <String, dynamic>{};
      String? preferenceId = args['preferenceId']?.toString().trim();
      if (preferenceId != null && preferenceId.isEmpty) {
        preferenceId = null;
      }

      String? primaryFocus = CustomerProfileEnums.normalizePrimaryFocus(args['primaryFocus']?.toString());
      if (!CustomerProfileEnums.isValidPrimaryFocus(primaryFocus)) {
        primaryFocus = null;
      }
      if (primaryFocus == null) {
        final pid = args['preferenceId']?.toString();
        if (pid != null && pid.isNotEmpty) {
          for (final p in _preferences) {
            if (p.id == pid) {
              primaryFocus = CustomerProfileEnums.normalizePrimaryFocus(p.value);
              break;
            }
          }
        }
      }
      if (!CustomerProfileEnums.isValidPrimaryFocus(primaryFocus)) {
        primaryFocus = CustomerProfileEnums.primaryFocusFromDisplayName(args['preference']?.toString());
      }
      if (!CustomerProfileEnums.isValidPrimaryFocus(primaryFocus)) {
        primaryFocus = null;
      }

      List<String>? mainGoals;
      List<String>? goalIds;
      final rawIds = args['goalIds'];
      if (rawIds is List && rawIds.isNotEmpty) {
        final ids = rawIds.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        if (ids.isNotEmpty) {
          goalIds = ids;
        }
      }
      final rawMain = args['mainGoals'];
      if (rawMain is List && rawMain.isNotEmpty) {
        mainGoals = CustomerProfileEnums.filterMainGoals(rawMain.map((e) => e.toString()));
        if (mainGoals.isEmpty) mainGoals = null;
      }
      if (mainGoals == null || mainGoals.isEmpty) {
        if (rawIds is List && rawIds.isNotEmpty) {
          final resolved = <String>[];
          for (final id in rawIds) {
            final sid = id.toString();
            for (final g in _goals) {
              if (g.id == sid) {
                final v = CustomerProfileEnums.normalizeMainGoal(g.value);
                if (v != null) resolved.add(v);
                break;
              }
            }
          }
          mainGoals = CustomerProfileEnums.filterMainGoals(resolved);
          if (mainGoals.isEmpty) mainGoals = null;
        }
      }
      if (mainGoals == null || mainGoals.isEmpty) {
        final rawNames = args['goals'];
        if (rawNames is List && rawNames.isNotEmpty) {
          mainGoals = CustomerProfileEnums.filterMainGoals(rawNames.map((e) => CustomerProfileEnums.mainGoalFromDisplayName(e.toString())));
          if (mainGoals.isEmpty) mainGoals = null;
        }
      }

      final fitnessLevelRaw = args['fitnessLevel']?.toString();
      final fitnessLevel = (fitnessLevelRaw != null && fitnessLevelRaw.trim().isNotEmpty) ? fitnessLevelRaw.trim() : null;

      final freqRaw = exerciseFrequency?.trim();
      final freq = (freqRaw != null && freqRaw.isNotEmpty) ? freqRaw : null;

      final response = await _authRepo.updateProfileRepo(
        fullName: _storageService.getName(),
        dateofbirth: _storageService.getString('user_date_of_birth'),
        gender: _storageService.getString('user_gender'),
        phoneNumber: _storageService.getString('user_phone'),
        bio: _storageService.getString('user_bio'),
        primaryFocus: primaryFocus,
        preferenceId: preferenceId,
        mainGoals: mainGoals,
        goalIds: goalIds,
        fitnessLevel: fitnessLevel,
        exerciseFrequency: freq,
      );

      if (response is! Map<String, dynamic>) {
        _snackError('Profile', 'Unexpected response from server');
        return false;
      }
      if (response['success'] != true) {
        final message = response['message']?.toString() ?? 'Could not update profile';
        _snackError('Profile', message);
        return false;
      }

      final prefName = args['preference']?.toString();
      if (prefName != null && prefName.trim().isNotEmpty) {
        await _storageService.saveUserPreference(prefName.trim());
      }
      final goalNames = args['goals'];
      if (goalNames is List && goalNames.isNotEmpty) {
        await _storageService.saveUserGoals(goalNames.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList());
      }
      if (fitnessLevel != null) {
        await _storageService.saveFitnessLevel(fitnessLevel);
      }
      if (freq != null) {
        await _storageService.saveExerciseFrequency(freq);
      }

      return true;
    } on BadRequestException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } catch (e) {
      _snackError('Profile', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// `POST /customer/profile/update` from the edit-profile form (JSON, or multipart when [profilePicturePath] is set).
  /// Refreshes [customerProfile] via [fetchCustomerProfile] on success.
  Future<bool> updateCustomerProfileFromEdit({
    required String fullName,
    String? dateofbirth,
    String? gender,
    String? phoneNumber,
    String? bio,
    String? primaryFocus,
    String? preferenceId,
    List<String>? mainGoals,
    List<String>? goalIds,
    String? fitnessLevel,
    String? exerciseFrequency,
    String? profilePicturePath,
  }) async {
    try {
      _isLoading = true;
      update();
      _syncNetworkBearerFromStorage();

      final response = await _authRepo.updateProfileRepo(
        fullName: fullName.trim(),
        dateofbirth: (dateofbirth != null && dateofbirth.trim().isNotEmpty) ? dateofbirth.trim() : null,
        gender: (gender != null && gender.trim().isNotEmpty) ? gender.trim() : null,
        phoneNumber: (phoneNumber != null && phoneNumber.trim().isNotEmpty) ? phoneNumber.trim() : null,
        bio: (bio != null && bio.trim().isNotEmpty) ? bio.trim() : null,
        primaryFocus: (primaryFocus != null && primaryFocus.trim().isNotEmpty) ? primaryFocus.trim() : null,
        preferenceId: (preferenceId != null && preferenceId.trim().isNotEmpty) ? preferenceId.trim() : null,

        goalIds: goalIds,
        fitnessLevel: (fitnessLevel != null && fitnessLevel.trim().isNotEmpty) ? fitnessLevel.trim() : null,
        exerciseFrequency: (exerciseFrequency != null && exerciseFrequency.trim().isNotEmpty) ? exerciseFrequency.trim() : null,
        profilePicturePath: (profilePicturePath != null && profilePicturePath.trim().isNotEmpty) ? profilePicturePath.trim() : null,
      );

      if (response is! Map<String, dynamic>) {
        _snackError('Profile', 'Unexpected response from server');
        return false;
      }
      if (!_apiEnvelopeSuccess(response)) {
        final msg = response['message'];
        final message = msg is List && msg.isNotEmpty
            ? msg.map((e) => e is Map ? (e['message'] ?? e).toString() : e.toString()).join('; ')
            : (msg?.toString() ?? 'Could not update profile');
        _snackError('Profile', message);
        return false;
      }

      await fetchCustomerProfile();
      return true;
    } on BadRequestException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } catch (e) {
      _snackError('Profile', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// `POST /customer/profile/update` — body: `dailyCalorieGoal`.
  Future<bool> updateDailyCalorieGoal(num dailyCalorieGoal) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.updateDailyCalorieGoalRepo(dailyCalorieGoal);
      if (response is! Map<String, dynamic>) {
        _snackError('Calorie goal', 'Unexpected response from server');
        return false;
      }
      if (!_apiEnvelopeSuccess(response)) {
        _snackError('Calorie goal', response['message']?.toString() ?? 'Could not update calorie goal');
        return false;
      }
      return true;
    } on BadRequestException catch (e) {
      _snackError('Calorie goal', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Calorie goal', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Calorie goal', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('Calorie goal', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Calorie goal', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Calorie goal', e.message);
      return false;
    } catch (e) {
      _snackError('Calorie goal', e);
      return false;
    }
  }

  /// Forgot password — `POST /user/auth/forget` with `{ "email": "..." }`. Stores user id for reset when present.
  Future<bool> forgotPassword(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      Get.snackbar('Forgot password', 'Please enter your email', snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    try {
      _isLoading = true;
      update();

      final response = await _authRepo.forgotPasswordRepo(email: trimmed);

      if (response is! Map<String, dynamic>) {
        _snackError('Forgot password', 'Unexpected response from server');
        return false;
      }

      if (response['success'] != true) {
        final message = response['message']?.toString() ?? 'Could not send reset code';
        _snackError('Forgot password', message);
        return false;
      }

      _tempEmail = trimmed;
      _forgotPasswordUserId = null;
      final data = response['data'];
      final user = data is Map<String, dynamic> ? data['user'] : null;
      if (user is Map<String, dynamic>) {
        final id = user['_id']?.toString();
        if (id != null && id.isNotEmpty) {
          _forgotPasswordUserId = id;
        }
      }

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      }

      return true;
    } on BadRequestException catch (e) {
      _snackError('Forgot password', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Forgot password', e.message);
      return false;
    } on ConflictException catch (e) {
      _snackError('Forgot password', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Forgot password', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Forgot password', e.message);
      return false;
    } catch (e) {
      _snackError('Forgot password', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Reset password — `POST /user/auth/forget-password` with `{ "password": "..." }` (Bearer from verify-otp).
  Future<bool> resetPassword({required String newPassword}) async {
    final trimmed = newPassword.trim();
    if (trimmed.isEmpty) {
      Get.snackbar('Reset password', 'Please enter a new password', snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    final session = _storageService.getToken();
    if (session == null || session.isEmpty) {
      _snackError('Reset password', 'Session expired. Start again from forgot password.');
      _scheduleGetNavigation(() => Get.offAllNamed(AppRoutes.forgotPassword));
      return false;
    }

    try {
      _isLoading = true;
      update();

      _syncNetworkBearerFromStorage();
      final response = await _authRepo.resetPasswordRepo(password: trimmed);

      if (response is! Map<String, dynamic>) {
        _snackError('Reset password', 'Unexpected response from server');
        return false;
      }

      if (response['success'] != true) {
        final msg = response['message']?.toString() ?? 'Could not reset password';
        _snackError('Reset password', msg);
        return false;
      }

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('Success', 'Password updated. Please sign in.', snackPosition: SnackPosition.BOTTOM);
      }

      await _storageService.logout();
      if (Get.isRegistered<LocalStorage>()) {
        Get.find<LocalStorage>().deleteAccessToken();
      }

      _scheduleGetNavigation(() => Get.offAllNamed(AppRoutes.login));
      return true;
    } on BadRequestException catch (e) {
      _snackError('Reset password', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Reset password', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Reset password', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Reset password', e.message);
      return false;
    } catch (e) {
      _snackError('Reset password', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Change password — `POST /user/auth/change-password` with old + new password (authenticated).
  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    final oldPw = currentPassword.trim();
    final newPw = newPassword.trim();
    if (oldPw.isEmpty || newPw.isEmpty) {
      Get.snackbar('Change password', 'Please fill in all fields', snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (oldPw == newPw) {
      Get.snackbar('Change password', 'New password must be different from current password', snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    try {
      _isLoading = true;
      update();

      _syncNetworkBearerFromStorage();
      final response = await _authRepo.changePasswordRepo(oldPassword: oldPw, newPassword: newPw);

      if (response is! Map<String, dynamic>) {
        _snackError('Change password', 'Unexpected response from server');
        return false;
      }

      if (response['success'] != true) {
        final msg = response['message']?.toString() ?? 'Could not update password';
        _snackError('Change password', msg);
        return false;
      }

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar('Success', 'Password updated successfully', snackPosition: SnackPosition.BOTTOM);
      }

      return true;
    } on BadRequestException catch (e) {
      _snackError('Change password', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Change password', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Change password', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Change password', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Change password', e.message);
      return false;
    } catch (e) {
      _snackError('Change password', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// `POST /user/auth/logout` with [deviceToken], then clear local session and go to login.
  Future<void> logout() async {
    try {
      _syncNetworkBearerFromStorage();
      final deviceToken = await _ensureDeviceToken();
      await _authRepo.logoutRepo(deviceToken: deviceToken);
    } on BadRequestException catch (e) {
      debugPrint('Logout API: ${e.message}');
    } on UnauthorizedException catch (e) {
      debugPrint('Logout API: ${e.message}');
    } on NoInternetException catch (e) {
      debugPrint('Logout API: ${e.message}');
    } on RequestTimeoutException catch (e) {
      debugPrint('Logout API: ${e.message}');
    } on ServerException catch (e) {
      debugPrint('Logout API: ${e.message}');
    } catch (e) {
      debugPrint('Logout API: $e');
    } finally {
      _customerProfile = null;
      _customerProfileError = null;
      _disconnectChatSocket();
      await _storageService.logout();
      if (Get.isRegistered<LocalStorage>()) {
        Get.find<LocalStorage>().deleteAccessToken();
      }
      update();
      _scheduleGetNavigation(() => Get.offAllNamed(AppRoutes.login));
    }
  }

  /// Sign in with Apple - DEMO VERSION
  /// Works for both login and signup (Apple handles both cases)
  Future<void> signInWithApple() async {
    try {
      // Check if Apple Sign-In is available (iOS 13+ or macOS 10.15+)
      if (!Platform.isIOS && !Platform.isMacOS) {
        Get.snackbar('Not Available', 'Apple Sign-In is only available on iOS and macOS devices', snackPosition: SnackPosition.BOTTOM);
        return;
      }

      _isLoading = true;
      update();

      // Check if Apple Sign-In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        _isLoading = false;
        update();
        Get.snackbar('Not Available', 'Apple Sign-In is not available on this device', snackPosition: SnackPosition.BOTTOM);
        return;
      }

      // Request Apple Sign-In
      final credential = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName]);

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Extract user information
      final email = credential.email ?? credential.userIdentifier;
      final firstName = credential.givenName ?? '';
      final lastName = credential.familyName ?? '';
      final displayName = '${firstName} ${lastName}'.trim();
      final userName = displayName.isNotEmpty ? displayName : 'Apple User';

      // Save demo user data locally
      await _storageService.saveToken('apple_token_${DateTime.now().millisecondsSinceEpoch}');
      await _storageService.saveUserId('apple_user_${credential.userIdentifier}');
      await _storageService.saveEmail(email ?? 'apple_user@example.com');
      await _storageService.saveName(userName);
      await _storageService.saveLoginStatus(true);

      _isLoading = false;
      update();

      // Navigate to home
      Get.offAllNamed(AppRoutes.home);
    } on SignInWithAppleAuthorizationException catch (e) {
      _isLoading = false;
      update();

      // Handle user cancellation
      if (e.code == AuthorizationErrorCode.canceled) {
        // User canceled, do nothing
        return;
      }

      // Handle other errors
      Get.snackbar('Sign-In Failed', e.message.isNotEmpty ? e.message : 'An error occurred during Apple Sign-In', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      _isLoading = false;
      update();
      Get.snackbar('Error', 'Failed to sign in with Apple: ${e.toString()}', snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// `GET /nutrition/tracker` — returns inner `data` on success (see [NutritionController.fetchNutritionTracker]).
  Future<Map<String, dynamic>?> fetchNutritionTracker({String? date}) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getNutritionTrackerRepo(date: date);
      if (response is! Map<String, dynamic>) return null;
      if (response['success'] != true) return null;
      final data = response['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// `GET /customer/food-logs/analytics` — returns inner `data` on success.
  Future<Map<String, dynamic>?> fetchFoodLogAnalytics({required String date, int dailyGoal = 2000}) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getFoodLogAnalyticsRepo(date: date, dailyGoal: dailyGoal);
      if (response is! Map<String, dynamic>) return null;
      if (!_apiEnvelopeSuccess(response)) return null;
      final data = response['data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Loads `GET /nutrition/meal-types` → `data.mealTypes` for [AddFoodGatewayScreen].
  Future<void> fetchNutritionMealTypes() async {
    try {
      _nutritionMealTypesLoading = true;
      _nutritionMealTypesError = null;
      update();

      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getNutritionMealTypesRepo();

      if (response is! Map<String, dynamic>) {
        _nutritionMealTypes = [];
        _nutritionMealTypesError = 'Unexpected response from server';
        return;
      }

      if (response['success'] != true) {
        _nutritionMealTypes = [];
        _nutritionMealTypesError = response['message']?.toString() ?? 'Could not load meal types';
        return;
      }

      final data = response['data'];
      final raw = data is Map<String, dynamic> ? data['mealTypes'] : null;
      final list = <NutritionMealTypeOption>[];
      if (raw is List) {
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            final o = NutritionMealTypeOption.fromJson(e);
            if (o.value.isNotEmpty) list.add(o);
          } else if (e is Map) {
            final o = NutritionMealTypeOption.fromJson(Map<String, dynamic>.from(e));
            if (o.value.isNotEmpty) list.add(o);
          }
        }
      }

      _nutritionMealTypes = list;
    } on BadRequestException catch (e) {
      _nutritionMealTypes = [];
      _nutritionMealTypesError = e.message;
    } on UnauthorizedException catch (e) {
      _nutritionMealTypes = [];
      _nutritionMealTypesError = e.message;
    } on ForbiddenException catch (e) {
      _nutritionMealTypes = [];
      _nutritionMealTypesError = e.message;
    } on NoInternetException catch (e) {
      _nutritionMealTypes = [];
      _nutritionMealTypesError = e.message;
    } on RequestTimeoutException catch (e) {
      _nutritionMealTypes = [];
      _nutritionMealTypesError = e.message;
    } on ServerException catch (e) {
      _nutritionMealTypes = [];
      _nutritionMealTypesError = e.message;
    } catch (e) {
      _nutritionMealTypes = [];
      _nutritionMealTypesError = e.toString();
    } finally {
      _nutritionMealTypesLoading = false;
      update();
    }
  }

  /// `GET /nutrition/foods/custom` — returns parsed page or null on failure.
  Future<NutritionCustomFoodsPage?> fetchNutritionCustomFoods({required String mealId, int page = 1, int perPage = 20}) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getNutritionCustomFoodsRepo(mealId: mealId, page: page, perPage: perPage);
      if (response is! Map<String, dynamic>) return null;
      if (response['success'] != true) return null;

      final data = response['data'];
      final list = <FoodItem>[];
      List<dynamic>? rawRows;
      if (data is List) {
        rawRows = data;
      } else if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        for (final key in ['foods', 'items', 'customFoods', 'results', 'rows', 'list', 'data']) {
          final v = dm[key];
          if (v is List) {
            rawRows = v;
            break;
          }
        }
      }
      if (rawRows != null) {
        for (final e in rawRows) {
          if (e is Map<String, dynamic>) {
            list.add(FoodItem.fromNutritionCustomFoodApi(e));
          } else if (e is Map) {
            list.add(FoodItem.fromNutritionCustomFoodApi(Map<String, dynamic>.from(e)));
          }
        }
      }

      final meta = response['meta'];
      var total = list.length;
      var p = page;
      var pp = perPage;
      if (meta is Map) {
        total = int.tryParse(meta['total']?.toString() ?? '') ?? total;
        p = int.tryParse(meta['page']?.toString() ?? '') ?? p;
        pp = int.tryParse(meta['per_page']?.toString() ?? '') ?? pp;
      }

      return NutritionCustomFoodsPage(items: list, total: total, page: p, perPage: pp);
    } catch (_) {
      return null;
    }
  }

  /// `POST /nutrition/foods/custom` — [mealType] must be slug: `breakfast` | `lunch` | `dinner` | `snacks`.
  Future<FoodItem?> createNutritionCustomFood({
    required String name,
    required String mealType,
    required double servingSize,
    required String servingUnit,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.createNutritionCustomFoodRepo({
        'name': name.trim(),
        'mealType': mealType.trim(),
        'servingSize': servingSize,
        'servingUnit': servingUnit.trim(),
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
      });

      if (response is! Map<String, dynamic>) {
        _snackError('Custom food', 'Unexpected response from server');
        return null;
      }
      if (response['success'] != true) {
        _snackError('Custom food', response['message']?.toString() ?? 'Could not create food');
        return null;
      }

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return FoodItem.fromNutritionCustomFoodApi(data);
      }
      if (data is Map) {
        return FoodItem.fromNutritionCustomFoodApi(Map<String, dynamic>.from(data));
      }
      return null;
    } on BadRequestException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } on UnauthorizedException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } on ForbiddenException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } on NoInternetException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } on RequestTimeoutException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } on ServerException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } catch (e) {
      _snackError('Custom food', e);
      return null;
    }
  }

  /// `PUT /nutrition/foods/custom/:id` — body: name, servingSize, servingUnit, calories, proteinG, carbsG, fatG (no mealType).
  /// Pass [mealId] (meal-type document id) when the API scopes updates with `?mealId=`.
  Future<FoodItem?> updateNutritionCustomFood({
    required String id,
    required String name,
    required double servingSize,
    required String servingUnit,
    required double calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    String? mealId,
  }) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.updateNutritionCustomFoodRepo(
        id.trim(),
        {'name': name.trim(), 'servingSize': servingSize, 'servingUnit': servingUnit.trim(), 'calories': calories, 'proteinG': proteinG, 'carbsG': carbsG, 'fatG': fatG},
        mealId: () {
          final m = mealId?.trim();
          return (m == null || m.isEmpty) ? null : m;
        }(),
      );

      if (response is! Map<String, dynamic>) {
        _snackError('Custom food', 'Unexpected response from server');
        return null;
      }
      if (response['success'] != true) {
        _snackError('Custom food', response['message']?.toString() ?? 'Could not update food');
        return null;
      }

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return FoodItem.fromNutritionCustomFoodApi(data);
      }
      if (data is Map) {
        return FoodItem.fromNutritionCustomFoodApi(Map<String, dynamic>.from(data));
      }
      return null;
    } on BadRequestException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } on UnauthorizedException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } on ForbiddenException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } on NoInternetException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } on RequestTimeoutException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } on ServerException catch (e) {
      _snackError('Custom food', e.message);
      return null;
    } catch (e) {
      _snackError('Custom food', e);
      return null;
    }
  }

  /// `PATCH /nutrition/foods/custom/:id` — soft-delete style endpoint on this API.
  Future<bool> deleteNutritionCustomFood(String id, {String? mealId}) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.deleteNutritionCustomFoodRepo(
        id.trim(),
        mealId: () {
          final m = mealId?.trim();
          return (m == null || m.isEmpty) ? null : m;
        }(),
      );
      if (response is! Map<String, dynamic>) {
        _snackError('Custom food', 'Unexpected response from server');
        return false;
      }
      if (response['success'] != true) {
        _snackError('Custom food', response['message']?.toString() ?? 'Could not delete food');
        return false;
      }
      return true;
    } on BadRequestException catch (e) {
      _snackError('Custom food', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Custom food', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Custom food', e.message);
      return false;
    } on NotFoundException catch (e) {
      _snackError('Custom food', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('Custom food', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Custom food', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Custom food', e.message);
      return false;
    } catch (e) {
      _snackError('Custom food', e);
      return false;
    }
  }

  /// `GET /customer/food-saves` — returns parsed page or null on failure.
  Future<NutritionCustomFoodsPage?> fetchFoodSaves({int page = 1, int limit = 10}) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getFoodSavesRepo(page: page, limit: limit);
      if (response is! Map<String, dynamic>) return null;
      if (response['success'] != true) return null;

      final data = response['data'];
      final list = <FoodItem>[];
      List<dynamic>? rawRows;
      var totalDocs = 0;
      var currentPage = page;
      var hasNextPage = false;

      if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        totalDocs = int.tryParse(dm['totalDocs']?.toString() ?? '') ?? 0;
        currentPage = int.tryParse(dm['currentPage']?.toString() ?? '') ?? page;
        hasNextPage = dm['hasNextPage'] == true;
        for (final key in ['foods', 'items', 'results', 'rows', 'list', 'data']) {
          final v = dm[key];
          if (v is List) {
            rawRows = v;
            break;
          }
        }
      } else if (data is List) {
        rawRows = data;
        totalDocs = data.length;
      }

      if (rawRows != null) {
        for (final e in rawRows) {
          if (e is Map<String, dynamic>) {
            list.add(FoodItem.fromFoodSaveApi(e));
          } else if (e is Map) {
            list.add(FoodItem.fromFoodSaveApi(Map<String, dynamic>.from(e)));
          }
        }
      }

      if (totalDocs == 0 && list.isNotEmpty) totalDocs = list.length;

      return NutritionCustomFoodsPage(
        items: list,
        total: totalDocs,
        page: currentPage,
        perPage: limit,
        hasNextPage: hasNextPage,
      );
    } catch (_) {
      return null;
    }
  }

  /// `POST /customer/food-saves` — body: name, servingSize, unit, calories, macronutrients.
  Future<FoodItem?> createFoodSave({
    required String name,
    required double servingSize,
    required String unit,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
  }) async {
    try {
      _syncNetworkBearerFromStorage();
      final trimmedName = name.trim();
      final trimmedUnit = unit.trim();
      final response = await _authRepo.createFoodSaveRepo({
        'name': trimmedName,
        'servingSize': servingSize,
        'unit': trimmedUnit,
        'calories': calories,
        'macronutrients': {'protein': protein, 'carbs': carbs, 'fats': fats},
      });

      if (response is! Map<String, dynamic>) {
        _snackError('Saved food', 'Unexpected response from server');
        return null;
      }
      if (response['success'] != true) {
        _snackError('Saved food', response['message']?.toString() ?? 'Could not create food');
        return null;
      }

      FoodItem? parsed;
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        parsed = FoodItem.fromFoodSaveApi(data);
      } else if (data is Map) {
        parsed = FoodItem.fromFoodSaveApi(Map<String, dynamic>.from(data));
      }

      final draft = FoodItem(
        id: '',
        name: trimmedName,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fats: fats,
        servingUnit: '$servingSize $trimmedUnit'.trim(),
        nutritionApiServingSize: servingSize,
        nutritionApiServingUnit: trimmedUnit,
        isNutritionApiCustom: true,
        isSaved: true,
      );

      return draft.mergeFoodSaveUpdate(name: trimmedName, calories: calories, protein: protein, carbs: carbs, fats: fats, fromApi: parsed);
    } on BadRequestException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } on UnauthorizedException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } on ForbiddenException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } on NoInternetException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } on RequestTimeoutException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } on ServerException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } catch (e) {
      _snackError('Saved food', e);
      return null;
    }
  }

  /// `POST /customer/food-logs` — body: mealType, meal (foodSaveId), loggedAt, servings, optional notes.
  Future<bool> createFoodLog({
    required String mealType,
    required String foodSaveId,
    required DateTime loggedAt,
    required double servings,
    String? notes,
  }) async {
    try {
      _syncNetworkBearerFromStorage();
      final body = <String, dynamic>{
        'mealType': mealType.trim(),
        'meal': foodSaveId.trim(),
        'loggedAt': loggedAt.toUtc().toIso8601String(),
        'servings': servings,
      };
      final trimmedNotes = notes?.trim();
      if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
        body['notes'] = trimmedNotes;
      }

      final response = await _authRepo.createFoodLogRepo(body);
      if (response is! Map<String, dynamic>) {
        _snackError('Food log', 'Unexpected response from server');
        return false;
      }
      if (!_apiEnvelopeSuccess(response)) {
        _snackError('Food log', response['message']?.toString() ?? 'Could not log food');
        return false;
      }
      return true;
    } on BadRequestException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } catch (e) {
      _snackError('Food log', e);
      return false;
    }
  }

  /// `PUT /customer/food-logs/:foodLogId` — body: mealType, servings, notes.
  Future<bool> updateFoodLog({
    required String id,
    required String mealType,
    required double servings,
    String? notes,
  }) async {
    try {
      _syncNetworkBearerFromStorage();
      final body = <String, dynamic>{
        'mealType': mealType.trim(),
        'servings': servings,
        'notes': notes?.trim() ?? '',
      };
      final response = await _authRepo.updateFoodLogRepo(id.trim(), body);
      if (response is! Map<String, dynamic>) {
        _snackError('Food log', 'Unexpected response from server');
        return false;
      }
      if (!_apiEnvelopeSuccess(response)) {
        _snackError('Food log', response['message']?.toString() ?? 'Could not update food log');
        return false;
      }
      return true;
    } on BadRequestException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } catch (e) {
      _snackError('Food log', e);
      return false;
    }
  }

  /// `GET /customer/food-logs/:foodLogId` — returns parsed [FoodLogDetail] on success.
  Future<FoodLogDetail?> fetchFoodLogDetail(String foodLogId) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getFoodLogDetailRepo(foodLogId.trim());
      if (response is! Map<String, dynamic>) {
        _snackError('Food log', 'Unexpected response from server');
        return null;
      }
      if (!_apiEnvelopeSuccess(response)) {
        _snackError('Food log', response['message']?.toString() ?? 'Could not load food log');
        return null;
      }
      final data = response['data'];
      if (data is! Map) return null;
      final log = data['log'];
      if (log is Map<String, dynamic>) return FoodLogDetail.fromApi(log);
      if (log is Map) return FoodLogDetail.fromApi(Map<String, dynamic>.from(log));
      return null;
    } on BadRequestException catch (e) {
      _snackError('Food log', e.message);
      return null;
    } on UnauthorizedException catch (e) {
      _snackError('Food log', e.message);
      return null;
    } on ForbiddenException catch (e) {
      _snackError('Food log', e.message);
      return null;
    } on NotFoundException catch (e) {
      _snackError('Food log', e.message);
      return null;
    } on NoInternetException catch (e) {
      _snackError('Food log', e.message);
      return null;
    } on RequestTimeoutException catch (e) {
      _snackError('Food log', e.message);
      return null;
    } on ServerException catch (e) {
      _snackError('Food log', e.message);
      return null;
    } catch (e) {
      _snackError('Food log', e);
      return null;
    }
  }

  /// `DELETE /customer/food-logs/:foodLogId`.
  Future<bool> deleteFoodLog(String id) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.deleteFoodLogRepo(id.trim());
      if (response is! Map<String, dynamic>) {
        _snackError('Food log', 'Unexpected response from server');
        return false;
      }
      if (!_apiEnvelopeSuccess(response)) {
        _snackError('Food log', response['message']?.toString() ?? 'Could not delete food log');
        return false;
      }
      return true;
    } on BadRequestException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on NotFoundException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Food log', e.message);
      return false;
    } catch (e) {
      _snackError('Food log', e);
      return false;
    }
  }

  /// `PUT /customer/food-saves/:id` — body: name, calories, macronutrients.
  Future<FoodItem?> updateFoodSave({
    required String id,
    required String name,
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
  }) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.updateFoodSaveRepo(id.trim(), {
        'name': name.trim(),
        'calories': calories,
        'macronutrients': {'protein': protein, 'carbs': carbs, 'fats': fats},
      });

      if (response is! Map<String, dynamic>) {
        _snackError('Saved food', 'Unexpected response from server');
        return null;
      }
      if (response['success'] != true) {
        _snackError('Saved food', response['message']?.toString() ?? 'Could not update food');
        return null;
      }

      final data = response['data'];
      FoodItem? parsed;
      if (data is Map<String, dynamic>) {
        parsed = FoodItem.fromFoodSaveApi(data);
      } else if (data is Map) {
        parsed = FoodItem.fromFoodSaveApi(Map<String, dynamic>.from(data));
      }

      return FoodItem(
        id: id.trim(),
        name: name.trim(),
        calories: calories,
        protein: protein,
        carbs: carbs,
        fats: fats,
        isNutritionApiCustom: true,
        isSaved: true,
      ).mergeFoodSaveUpdate(name: name, calories: calories, protein: protein, carbs: carbs, fats: fats, fromApi: parsed);
    } on BadRequestException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } on UnauthorizedException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } on ForbiddenException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } on NoInternetException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } on RequestTimeoutException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } on ServerException catch (e) {
      _snackError('Saved food', e.message);
      return null;
    } catch (e) {
      _snackError('Saved food', e);
      return null;
    }
  }

  /// `DELETE /customer/food-saves/:id`.
  Future<bool> deleteFoodSave(String id) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.deleteFoodSaveRepo(id.trim());
      if (response is! Map<String, dynamic>) {
        _snackError('Saved food', 'Unexpected response from server');
        return false;
      }
      if (response['success'] != true) {
        _snackError('Saved food', response['message']?.toString() ?? 'Could not delete food');
        return false;
      }
      return true;
    } on BadRequestException catch (e) {
      _snackError('Saved food', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Saved food', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Saved food', e.message);
      return false;
    } on NotFoundException catch (e) {
      _snackError('Saved food', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('Saved food', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Saved food', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Saved food', e.message);
      return false;
    } catch (e) {
      _snackError('Saved food', e);
      return false;
    }
  }
}

/// One page from `GET /customer/program/enrolled`.
class CustomerEnrolledProgramsPage {
  final List<Map<String, dynamic>> enrollments;
  final bool hasNextPage;
  final int currentPage;
  final int totalDocs;

  const CustomerEnrolledProgramsPage({
    required this.enrollments,
    required this.hasNextPage,
    required this.currentPage,
    required this.totalDocs,
  });
}
