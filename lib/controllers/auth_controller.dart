import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:get_right/Local%20Storage/local_storage.dart';
import 'package:get_right/models/customer_profile_dto.dart';
import 'package:get_right/models/exercise_plan_option.dart';
import 'package:get_right/models/fitness_level_option.dart';
import 'package:get_right/models/user_goal_option.dart';
import 'package:get_right/models/user_preference_option.dart';
import 'package:get_right/models/food_item.dart';
import 'package:get_right/models/nutrition_custom_foods_page.dart';
import 'package:get_right/models/nutrition_meal_type_option.dart';
import 'package:get_right/repo/auth_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/utils/customer_profile_enums.dart';
import 'package:get_right/utils/image_url_sanitizer.dart';

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
  List<FitnessLevelOption> get fitnessLevels =>
      List.unmodifiable(_fitnessLevels);

  bool _fitnessLevelsLoading = false;
  bool get fitnessLevelsLoading => _fitnessLevelsLoading;

  String? _fitnessLevelsError;
  String? get fitnessLevelsError => _fitnessLevelsError;

  List<ExercisePlanOption> _exercisePlans = [];
  List<ExercisePlanOption> get exercisePlans =>
      List.unmodifiable(_exercisePlans);

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
  List<NutritionMealTypeOption> get nutritionMealTypes =>
      List.unmodifiable(_nutritionMealTypes);

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
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  Future<String> _ensureDeviceToken() async {
    var token = _storageService.getString(_deviceTokenStorageKey);
    if (token == null || token.isEmpty) {
      token =
          'getright-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
      await _storageService.saveString(_deviceTokenStorageKey, token);
    }
    return token;
  }

  void _snackError(String title, Object e) {
    final msg = e is Exception
        ? e.toString().replaceFirst('Exception: ', '')
        : e.toString();
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

  /// SharedPreferences + GetStorage token so [NetworkApiService] sends `Bearer` on API calls.
  Future<void> _persistAccessToken(String token) async {
    await _storageService.saveToken(token);
    await _storageService.saveLoginStatus(true);
    final ls = Get.isRegistered<LocalStorage>()
        ? Get.find<LocalStorage>()
        : Get.put(LocalStorage());
    ls.saveAccessToken(token);
  }

  /// [NetworkApiService] reads JWT from [LocalStorage]; [StorageService] also stores it. Sync avoids 410 when GetStorage was empty or stale.
  void _syncNetworkBearerFromStorage() {
    final t = _storageService.getToken();
    if (t == null || t.isEmpty) return;
    final ls = Get.isRegistered<LocalStorage>()
        ? Get.find<LocalStorage>()
        : Get.put(LocalStorage());
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
        _preferencesError =
            response['message']?.toString() ?? 'Could not load preferences';
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
            final p = UserPreferenceOption.fromJson(
              Map<String, dynamic>.from(e),
            );
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
        _fitnessLevelsError =
            response['message']?.toString() ?? 'Could not load fitness levels';
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
        _exercisePlansError =
            response['message']?.toString() ?? 'Could not load exercise plans';
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
    return slug
        .split('_')
        .where((s) => s.isNotEmpty)
        .map(
          (s) =>
              '${s[0].toUpperCase()}${s.length > 1 ? s.substring(1).toLowerCase() : ''}',
        )
        .join(' ');
  }

  Future<void> _persistCustomerProfileLocal(CustomerProfileDto dto) async {
    if (dto.fullName != null && dto.fullName!.trim().isNotEmpty) {
      await _storageService.saveName(dto.fullName!.trim());
    }
    if (dto.email.trim().isNotEmpty) {
      await _storageService.saveEmail(dto.email.trim());
    }
    await _storageService.saveUserId(dto.userId);
    final ls = Get.isRegistered<LocalStorage>()
        ? Get.find<LocalStorage>()
        : Get.put(LocalStorage());
    ls.saveuserid(dto.userId);

    if (dto.dateofbirth != null && dto.dateofbirth!.trim().isNotEmpty) {
      await _storageService.saveString(
        'user_date_of_birth',
        dto.dateofbirth!.trim(),
      );
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
      await _storageService.saveUserPreference(
        _slugToReadable(dto.primaryFocus!.trim()),
      );
    }
    if (dto.mainGoals.isNotEmpty) {
      await _storageService.saveUserGoals(
        dto.mainGoals.map(_slugToReadable).toList(),
      );
    }
    if (dto.fitnessLevel != null && dto.fitnessLevel!.trim().isNotEmpty) {
      await _storageService.saveFitnessLevel(dto.fitnessLevel!.trim());
    }
    if (dto.exerciseFrequency != null &&
        dto.exerciseFrequency!.trim().isNotEmpty) {
      await _storageService.saveExerciseFrequency(
        dto.exerciseFrequency!.trim(),
      );
    }
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
          _customerProfileError = msg
              .map(
                (e) => e is Map ? (e['message'] ?? e).toString() : e.toString(),
              )
              .join('; ');
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

  /// Raw JSON from `GET /marketplace/bundles`. Prefer [MarketplaceRepository.fetchBrowseBundles] for parsed cards.
  Future<dynamic> getMarketplaceBundlesRaw({int page = 1, int perPage = 20}) {
    return _authRepo.getMarketplaceBundlesRepo(page: page, perPage: perPage);
  }

  /// `GET /marketplace/bundles/:id` — returns a map aligned with marketplace bundle cards + detail fields, or null.
  Future<Map<String, dynamic>?> fetchMarketplaceBundleDetail(
    String bundleId,
  ) async {
    final id = bundleId.trim();
    if (id.isEmpty) return null;
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getMarketplaceBundleDetailRepo(id);
      if (response is! Map<String, dynamic>) {
        _snackError('Bundle', 'Unexpected response from server');
        return null;
      }
      if (response['success'] != true) {
        _snackError(
          'Bundle',
          response['message']?.toString() ?? 'Could not load bundle',
        );
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

  Map<String, dynamic>? _parseMarketplaceBundleDetailResponse(
    Map<String, dynamic> response,
  ) {
    final data = response['data'];
    Map<String, dynamic>? inner;
    if (data is Map && data['data'] is Map) {
      inner = Map<String, dynamic>.from(data['data'] as Map);
    } else if (data is Map) {
      inner = Map<String, dynamic>.from(data);
    }
    if (inner == null) return null;

    final pricing = inner['pricing_summary'];
    double bundlePrice = (inner['bundlePrice'] as num?)?.toDouble() ?? 0.0;
    double? originalList;
    double? savingsPercent;
    if (pricing is Map) {
      final pm = Map<String, dynamic>.from(pricing);
      originalList = (pm['original_list_price'] as num?)?.toDouble();
      bundlePrice = (pm['bundle_price'] as num?)?.toDouble() ?? bundlePrice;
      savingsPercent = (pm['savings_percent'] as num?)?.toDouble();
    }

    final programsRaw = inner['programs'];
    var sumProgramPrices = 0.0;
    final programs = <Map<String, dynamic>>[];
    if (programsRaw is List) {
      for (final e in programsRaw) {
        if (e is! Map) continue;
        final p = Map<String, dynamic>.from(e);
        final disp = p['display'] is Map
            ? Map<String, dynamic>.from(p['display'] as Map)
            : <String, dynamic>{};
        final instructor = (disp['instructor_name'] ?? 'Trainer')
            .toString()
            .trim();
        final weeks = disp['duration_weeks'] ?? p['durationWeeks'];
        final rating = (disp['average_rating'] as num?)?.toDouble() ?? 0.0;
        final price = (p['price'] as num?)?.toDouble() ?? 0.0;
        sumProgramPrices += price;
        final initial = instructor.isNotEmpty
            ? instructor.substring(0, 1).toUpperCase()
            : 'T';
        programs.add({
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
          'imageUrl': ImageUrlSanitizer.asHttpUrlOrNull(
            p['coverImageUrl']?.toString(),
          ),
          'certified': p['isCertified'] == true,
        });
      }
    }

    var totalValue = originalList ?? 0.0;
    if (totalValue <= 0 && sumProgramPrices > 0) {
      totalValue = sumProgramPrices;
    }
    if (totalValue <= bundlePrice && bundlePrice > 0) {
      totalValue = bundlePrice * 1.12;
    }

    final discount = savingsPercent != null
        ? savingsPercent.round().clamp(0, 95)
        : (totalValue > 0
              ? (((totalValue - bundlePrice) / totalValue) * 100).round().clamp(
                  0,
                  95,
                )
              : 0);

    return {
      'id': inner['_id']?.toString() ?? '',
      'title': inner['title']?.toString() ?? '',
      'subtitle': inner['subtitle'],
      'description': inner['description']?.toString() ?? '',
      'bundlePrice': bundlePrice,
      'totalValue': totalValue,
      'discount': discount,
      'imageUrl':
          ImageUrlSanitizer.asHttpUrlOrNull(
            inner['coverImageUrl']?.toString(),
          ) ??
          '',
      'programs': programs,
      'whatsIncluded': inner['whatsIncluded'],
      'marketplace_detail': inner['marketplace_detail'],
      '_apiBundle': inner,
    };
  }

  /// `GET /marketplace/programs/:id` — map shaped for [ProgramDetailScreen] / marketplace program cards.
  Future<Map<String, dynamic>?> fetchMarketplaceProgramDetail(
    String programId,
  ) async {
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
        _snackError(
          'Program',
          response['message']?.toString() ?? 'Could not load program',
        );
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

  Map<String, dynamic>? _parseMarketplaceProgramDetailResponse(
    Map<String, dynamic> response,
  ) {
    final data = response['data'];
    Map<String, dynamic>? inner;
    if (data is Map && data['data'] is Map) {
      inner = Map<String, dynamic>.from(data['data'] as Map);
    } else if (data is Map) {
      inner = Map<String, dynamic>.from(data);
    }
    if (inner == null) return null;

    final md = inner['marketplace_detail'] is Map
        ? Map<String, dynamic>.from(inner['marketplace_detail'] as Map)
        : <String, dynamic>{};
    final trainer = md['trainer'] is Map
        ? Map<String, dynamic>.from(md['trainer'] as Map)
        : <String, dynamic>{};
    final stats = md['stats'] is Map
        ? Map<String, dynamic>.from(md['stats'] as Map)
        : <String, dynamic>{};
    final ext = inner['catalog_extensions'] is Map
        ? Map<String, dynamic>.from(inner['catalog_extensions'] as Map)
        : <String, dynamic>{};
    final attrs = ext['attributes'] is Map
        ? Map<String, dynamic>.from(ext['attributes'] as Map)
        : <String, dynamic>{};
    final hero = ext['hero_media'] is Map
        ? Map<String, dynamic>.from(ext['hero_media'] as Map)
        : <String, dynamic>{};
    final prSum = ext['program_rating_summary'] is Map
        ? Map<String, dynamic>.from(ext['program_rating_summary'] as Map)
        : <String, dynamic>{};

    final displayName = (trainer['display_name'] ?? 'Trainer')
        .toString()
        .trim();
    final initial = displayName.isNotEmpty
        ? displayName.substring(0, 1).toUpperCase()
        : 'T';

    final durationLabel = attrs['duration_label']?.toString();
    final weeks = attrs['duration_weeks'] ?? inner['durationWeeks'];
    final duration = (durationLabel != null && durationLabel.isNotEmpty)
        ? durationLabel
        : (weeks != null ? '$weeks weeks' : '—');

    var rating = (stats['average_rating'] as num?)?.toDouble() ?? 0.0;
    if (rating == 0.0 && prSum['average_rating'] != null) {
      rating = (prSum['average_rating'] as num).toDouble();
    }
    final reviewCount =
        (stats['review_count'] as num?)?.toInt() ??
        (prSum['review_count'] as num?)?.toInt() ??
        0;
    final students =
        (stats['enrollment_count'] as num?)?.toInt() ??
        (ext['student_count'] as num?)?.toInt() ??
        0;

    String? img = ImageUrlSanitizer.asHttpUrlOrNull(
      inner['coverImageUrl']?.toString(),
    );
    img ??= ImageUrlSanitizer.asHttpUrlOrNull(
      hero['thumbnail_url']?.toString(),
    );
    img ??= ImageUrlSanitizer.asHttpUrlOrNull(hero['stream_url']?.toString());

    final purchased = ext['purchased'] == true;
    final price =
        (inner['price'] as num?)?.toDouble() ??
        (ext['price'] as num?)?.toDouble() ??
        0.0;

    return {
      'id': inner['_id']?.toString() ?? '',
      'trainerId': inner['trainerId']?.toString(),
      'title': inner['title']?.toString() ?? 'Program',
      'subtitle': inner['subtitle']?.toString(),
      'trainer': displayName,
      'trainerImage': initial,
      'trainerImageUrl': ImageUrlSanitizer.asHttpUrlOrNull(
        trainer['avatar_url']?.toString(),
      ),
      'price': price,
      'duration': duration,
      'category': (attrs['focus'] ?? inner['focus'])?.toString() ?? 'General',
      'goal': (attrs['level'] ?? inner['level'])?.toString() ?? 'Fitness',
      'certified':
          inner['isCertified'] == true || trainer['is_certified'] == true,
      'rating': rating,
      'students': students,
      'reviews': reviewCount,
      'description': inner['description']?.toString() ?? '',
      'status': inner['status']?.toString(),
      'purchased': purchased,
      'isEnrolled': purchased,
      'imageUrl': img,
      'weeks': inner['weeks'],
      'whatsIncluded': inner['whatsIncluded'],
      'whats_included': ext['whats_included'],
      'catalog_extensions': ext,
      'marketplace_detail': md,
      '_apiProgram': inner,
    };
  }

  /// Login via `POST /user/auth/login` with email, password, deviceType, deviceToken.
  Future<void> login({required String email, required String password}) async {
    try {
      _isLoading = true;
      update();

      final deviceToken = await _ensureDeviceToken();
      final response = await _authRepo.loginRepo(
        email: email,
        password: password,
        deviceType: _deviceTypeLabel(),
        deviceToken: deviceToken,
      );

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
      String? emailToStore;
      var needsEmailVerification = false;
      var needsProfileSetup = false;
      if (data is Map<String, dynamic>) {
        needsEmailVerification =
            _isExplicitlyFalse(data['isVerified']) ||
            _isExplicitlyFalse(data['is_verified']);
        if (!needsEmailVerification) {
          needsProfileSetup =
              _isExplicitlyFalse(data['isProfileCompleted']) ||
              _isExplicitlyFalse(data['is_profile_completed']);
        }

        final user = data['user'];
        if (user is Map<String, dynamic>) {
          final id = user['_id']?.toString();
          if (id != null && id.isNotEmpty) {
            await _storageService.saveUserId(id);
            final ls = Get.isRegistered<LocalStorage>()
                ? Get.find<LocalStorage>()
                : Get.put(LocalStorage());
            ls.saveuserid(id);
          }
          emailToStore = user['email']?.toString();
          final profile = user['profile'];
          if (profile is Map<String, dynamic>) {
            final name = profile['fullName']?.toString();
            if (name != null && name.isNotEmpty) {
              await _storageService.saveName(name);
            }
          }

          needsEmailVerification =
              needsEmailVerification ||
              _isExplicitlyFalse(user['isVerified']) ||
              _isExplicitlyFalse(user['is_verified']);
          if (!needsEmailVerification) {
            needsProfileSetup =
                needsProfileSetup ||
                _isExplicitlyFalse(user['isProfileCompleted']) ||
                _isExplicitlyFalse(user['is_profile_completed']);
            if (profile is Map<String, dynamic>) {
              needsProfileSetup =
                  needsProfileSetup ||
                  _isExplicitlyFalse(profile['isProfileCompleted']) ||
                  _isExplicitlyFalse(profile['is_profile_completed']);
            }
          }
        }
      }
      final resolvedEmail = emailToStore?.trim();
      await _storageService.saveEmail(
        (resolvedEmail != null && resolvedEmail.isNotEmpty)
            ? resolvedEmail
            : email,
      );

      if (needsEmailVerification) {
        final uid = _storageService.getUserId();
        if (uid == null || uid.isEmpty) {
          _snackError(
            'Login',
            'This account needs email verification, but user id is missing. Please try again.',
          );
          Get.offAllNamed(AppRoutes.home);
          return;
        }
        final em = (resolvedEmail != null && resolvedEmail.isNotEmpty)
            ? resolvedEmail
            : email.trim();
        _tempEmail = em;
        _pendingSignupUserId = uid;
        Get.offAllNamed(
          AppRoutes.otp,
          arguments: {'email': em, 'userId': uid, 'fromSignup': false},
        );
        return;
      }

      final token = _tokenFromVerifyResponse(response);
      if (token == null || token.isEmpty) {
        _snackError('Login', 'No access token in response');
        return;
      }
      await _persistAccessToken(token);

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

  /// Signup via `/user/auth/signup`. On success, OTP is sent to email; stores user id for verify-OTP.
  Future<bool> signup({
    required String email,
    required String password,
    String role = 'Customer',
  }) async {
    try {
      _isLoading = true;
      update();

      final deviceToken = await _ensureDeviceToken();
      final response = await _authRepo.signUp(
        email: email,
        password: password,
        deviceType: _deviceTypeLabel(),
        deviceToken: deviceToken,
        role: role,
      );

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

      final data = response['data'];
      final user = data is Map<String, dynamic> ? data['user'] : null;
      final userId = user is Map<String, dynamic>
          ? user['_id']?.toString()
          : null;

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

  String? _tokenFromVerifyResponse(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      for (final key in ['token', 'accessToken', 'access_token', 'authToken']) {
        final v = data[key];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      final user = data['user'];
      if (user is Map<String, dynamic>) {
        for (final key in ['token', 'accessToken']) {
          final v = user[key];
          if (v != null && v.toString().isNotEmpty) return v.toString();
        }
      }
    }
    for (final key in ['token', 'accessToken', 'access_token']) {
      final v = json[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  /// Verify OTP via `/user/auth/verify-otp` with `userId` + `otp`.
  /// Signup: persists token when present, then [AppRoutes.profileSetup].
  /// Forgot password ([forgotPasswordFlow]): persists token when present (for `POST /user/auth/forget-password` Bearer), then [AppRoutes.resetPassword].
  Future<bool> verifyOTP({
    required String userId,
    required String otp,
    bool forgotPasswordFlow = false,
  }) async {
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
        final message =
            response['message']?.toString() ?? 'Verification failed';
        _snackError('Verification', message);
        return false;
      }

      final message = response['message']?.toString();

      if (forgotPasswordFlow) {
        final token = _tokenFromVerifyResponse(response);
        if (token != null && token.isNotEmpty) {
          await _persistAccessToken(token);
        }
        if (message != null && message.isNotEmpty) {
          Get.snackbar(
            'Verified',
            message,
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        _tempEmail = null;
        _forgotPasswordUserId = null;
        Get.offNamed(AppRoutes.resetPassword);
        return true;
      }

      final token = _tokenFromVerifyResponse(response);
      if (token != null && token.isNotEmpty) {
        await _persistAccessToken(token);
      }

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

      Get.offNamed(AppRoutes.profileSetup);
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
  Future<void> resendOTP({
    String? email,
    bool forgotPasswordFlow = false,
  }) async {
    try {
      _isLoading = true;
      update();

      final resolved = (email != null && email.trim().isNotEmpty)
          ? email.trim()
          : _tempEmail;
      if (resolved == null || resolved.isEmpty) {
        Get.snackbar(
          'Resend OTP',
          forgotPasswordFlow
              ? 'No email found. Go back and try again.'
              : 'No email found. Go back and sign up again.',
          snackPosition: SnackPosition.BOTTOM,
        );
        if (forgotPasswordFlow) {
          Get.back();
        } else {
          Get.offAllNamed(AppRoutes.signup);
        }
        return;
      }

      final response = forgotPasswordFlow
          ? await _authRepo.forgotPasswordRepo(email: resolved)
          : await _authRepo.sendOtpRepo(email: resolved);
      if (response is! Map<String, dynamic>) {
        _snackError('Resend OTP', 'Unexpected response from server');
        return;
      }

      if (response['success'] == true) {
        final message = response['message']?.toString() ?? 'OTP sent';
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      } else {
        final message =
            response['message']?.toString() ?? 'Could not resend code';
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
  Future<bool> createProfile({
    required String fullName,
    required String dateofbirth,
    required String gender,
    required String phoneNumber,
    File? profilePicture,
  }) async {
    try {
      _isLoading = true;
      update();

      final response = await _authRepo.createProfileRepo(
        fullName: fullName,
        dateofbirth: dateofbirth,
        gender: gender,
        phoneNumber: phoneNumber,
        profilePicture: profilePicture,
      );

      if (response is! Map<String, dynamic>) {
        _snackError('Profile', 'Unexpected response from server');
        return false;
      }

      if (response['success'] != true) {
        final message =
            response['message']?.toString() ?? 'Could not create profile';
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
  Future<bool> updateCustomerOnboardingProfile({
    Map<String, dynamic>? routeArgs,
    String? exerciseFrequency,
  }) async {
    try {
      _isLoading = true;
      update();
      _syncNetworkBearerFromStorage();

      final args = routeArgs ?? <String, dynamic>{};

      String? primaryFocus = CustomerProfileEnums.normalizePrimaryFocus(
        args['primaryFocus']?.toString(),
      );
      if (!CustomerProfileEnums.isValidPrimaryFocus(primaryFocus)) {
        primaryFocus = null;
      }
      if (primaryFocus == null) {
        final pid = args['preferenceId']?.toString();
        if (pid != null && pid.isNotEmpty) {
          for (final p in _preferences) {
            if (p.id == pid) {
              primaryFocus = CustomerProfileEnums.normalizePrimaryFocus(
                p.value,
              );
              break;
            }
          }
        }
      }
      if (!CustomerProfileEnums.isValidPrimaryFocus(primaryFocus)) {
        primaryFocus = CustomerProfileEnums.primaryFocusFromDisplayName(
          args['preference']?.toString(),
        );
      }
      if (!CustomerProfileEnums.isValidPrimaryFocus(primaryFocus)) {
        primaryFocus = null;
      }

      List<String>? mainGoals;
      final rawMain = args['mainGoals'];
      if (rawMain is List && rawMain.isNotEmpty) {
        mainGoals = CustomerProfileEnums.filterMainGoals(
          rawMain.map((e) => e.toString()),
        );
        if (mainGoals.isEmpty) mainGoals = null;
      }
      if (mainGoals == null || mainGoals.isEmpty) {
        final rawIds = args['goalIds'];
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
          mainGoals = CustomerProfileEnums.filterMainGoals(
            rawNames.map(
              (e) => CustomerProfileEnums.mainGoalFromDisplayName(e.toString()),
            ),
          );
          if (mainGoals.isEmpty) mainGoals = null;
        }
      }

      final fitnessLevelRaw = args['fitnessLevel']?.toString();
      final fitnessLevel =
          (fitnessLevelRaw != null && fitnessLevelRaw.trim().isNotEmpty)
          ? fitnessLevelRaw.trim()
          : null;

      final freqRaw = exerciseFrequency?.trim();
      final freq = (freqRaw != null && freqRaw.isNotEmpty) ? freqRaw : null;

      final response = await _authRepo.updateProfileRepo(
        fullName: _storageService.getName(),
        dateofbirth: _storageService.getString('user_date_of_birth'),
        gender: _storageService.getString('user_gender'),
        phoneNumber: _storageService.getString('user_phone'),
        bio: _storageService.getString('user_bio'),
        primaryFocus: primaryFocus,
        mainGoals: mainGoals,
        fitnessLevel: fitnessLevel,
        exerciseFrequency: freq,
      );

      if (response is! Map<String, dynamic>) {
        _snackError('Profile', 'Unexpected response from server');
        return false;
      }
      if (response['success'] != true) {
        final message =
            response['message']?.toString() ?? 'Could not update profile';
        _snackError('Profile', message);
        return false;
      }

      final prefName = args['preference']?.toString();
      if (prefName != null && prefName.trim().isNotEmpty) {
        await _storageService.saveUserPreference(prefName.trim());
      }
      final goalNames = args['goals'];
      if (goalNames is List && goalNames.isNotEmpty) {
        await _storageService.saveUserGoals(
          goalNames
              .map((e) => e.toString())
              .where((e) => e.trim().isNotEmpty)
              .toList(),
        );
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
    List<String>? mainGoals,
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
        dateofbirth: (dateofbirth != null && dateofbirth.trim().isNotEmpty)
            ? dateofbirth.trim()
            : null,
        gender: (gender != null && gender.trim().isNotEmpty)
            ? gender.trim()
            : null,
        phoneNumber: (phoneNumber != null && phoneNumber.trim().isNotEmpty)
            ? phoneNumber.trim()
            : null,
        bio: (bio != null && bio.trim().isNotEmpty) ? bio.trim() : null,
        primaryFocus: (primaryFocus != null && primaryFocus.trim().isNotEmpty)
            ? primaryFocus.trim()
            : null,
        mainGoals: mainGoals,
        fitnessLevel: (fitnessLevel != null && fitnessLevel.trim().isNotEmpty)
            ? fitnessLevel.trim()
            : null,
        exerciseFrequency:
            (exerciseFrequency != null && exerciseFrequency.trim().isNotEmpty)
            ? exerciseFrequency.trim()
            : null,
        profilePicturePath:
            (profilePicturePath != null && profilePicturePath.trim().isNotEmpty)
            ? profilePicturePath.trim()
            : null,
      );

      if (response is! Map<String, dynamic>) {
        _snackError('Profile', 'Unexpected response from server');
        return false;
      }
      if (response['success'] != true) {
        final msg = response['message'];
        final message = msg is List && msg.isNotEmpty
            ? msg
                  .map(
                    (e) => e is Map
                        ? (e['message'] ?? e).toString()
                        : e.toString(),
                  )
                  .join('; ')
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

  /// Forgot password — `POST /user/auth/forget` with `{ "email": "..." }`. Stores user id for reset when present.
  Future<bool> forgotPassword(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      Get.snackbar(
        'Forgot password',
        'Please enter your email',
        snackPosition: SnackPosition.BOTTOM,
      );
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
        final message =
            response['message']?.toString() ?? 'Could not send reset code';
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
      Get.snackbar(
        'Reset password',
        'Please enter a new password',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    final session = _storageService.getToken();
    if (session == null || session.isEmpty) {
      _snackError(
        'Reset password',
        'Session expired. Start again from forgot password.',
      );
      Get.offAllNamed(AppRoutes.forgotPassword);
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
        final msg =
            response['message']?.toString() ?? 'Could not reset password';
        _snackError('Reset password', msg);
        return false;
      }

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar(
          'Success',
          'Password updated. Please sign in.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }

      await _storageService.logout();
      if (Get.isRegistered<LocalStorage>()) {
        Get.find<LocalStorage>().deleteAccessToken();
      }

      Get.offAllNamed(AppRoutes.login);
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
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final oldPw = currentPassword.trim();
    final newPw = newPassword.trim();
    if (oldPw.isEmpty || newPw.isEmpty) {
      Get.snackbar(
        'Change password',
        'Please fill in all fields',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }
    if (oldPw == newPw) {
      Get.snackbar(
        'Change password',
        'New password must be different from current password',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    }

    try {
      _isLoading = true;
      update();

      _syncNetworkBearerFromStorage();
      final response = await _authRepo.changePasswordRepo(
        oldPassword: oldPw,
        newPassword: newPw,
      );

      if (response is! Map<String, dynamic>) {
        _snackError('Change password', 'Unexpected response from server');
        return false;
      }

      if (response['success'] != true) {
        final msg =
            response['message']?.toString() ?? 'Could not update password';
        _snackError('Change password', msg);
        return false;
      }

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      } else {
        Get.snackbar(
          'Success',
          'Password updated successfully',
          snackPosition: SnackPosition.BOTTOM,
        );
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

  /// Logout
  Future<void> logout() async {
    await _storageService.logout();
    Get.offAllNamed(AppRoutes.login);
  }

  /// Sign in with Apple - DEMO VERSION
  /// Works for both login and signup (Apple handles both cases)
  Future<void> signInWithApple() async {
    try {
      // Check if Apple Sign-In is available (iOS 13+ or macOS 10.15+)
      if (!Platform.isIOS && !Platform.isMacOS) {
        Get.snackbar(
          'Not Available',
          'Apple Sign-In is only available on iOS and macOS devices',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      _isLoading = true;
      update();

      // Check if Apple Sign-In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        _isLoading = false;
        update();
        Get.snackbar(
          'Not Available',
          'Apple Sign-In is not available on this device',
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      // Request Apple Sign-In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Extract user information
      final email = credential.email ?? credential.userIdentifier;
      final firstName = credential.givenName ?? '';
      final lastName = credential.familyName ?? '';
      final displayName = '${firstName} ${lastName}'.trim();
      final userName = displayName.isNotEmpty ? displayName : 'Apple User';

      // Save demo user data locally
      await _storageService.saveToken(
        'apple_token_${DateTime.now().millisecondsSinceEpoch}',
      );
      await _storageService.saveUserId(
        'apple_user_${credential.userIdentifier}',
      );
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
      Get.snackbar(
        'Sign-In Failed',
        e.message.isNotEmpty
            ? e.message
            : 'An error occurred during Apple Sign-In',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      _isLoading = false;
      update();
      Get.snackbar(
        'Error',
        'Failed to sign in with Apple: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
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
        _nutritionMealTypesError =
            response['message']?.toString() ?? 'Could not load meal types';
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
            final o = NutritionMealTypeOption.fromJson(
              Map<String, dynamic>.from(e),
            );
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
  Future<NutritionCustomFoodsPage?> fetchNutritionCustomFoods({
    required String mealId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      _syncNetworkBearerFromStorage();
      final response = await _authRepo.getNutritionCustomFoodsRepo(
        mealId: mealId,
        page: page,
        perPage: perPage,
      );
      if (response is! Map<String, dynamic>) return null;
      if (response['success'] != true) return null;

      final data = response['data'];
      final list = <FoodItem>[];
      List<dynamic>? rawRows;
      if (data is List) {
        rawRows = data;
      } else if (data is Map) {
        final dm = Map<String, dynamic>.from(data);
        for (final key in [
          'foods',
          'items',
          'customFoods',
          'results',
          'rows',
          'list',
          'data',
        ]) {
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
            list.add(
              FoodItem.fromNutritionCustomFoodApi(Map<String, dynamic>.from(e)),
            );
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

      return NutritionCustomFoodsPage(
        items: list,
        total: total,
        page: p,
        perPage: pp,
      );
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
        _snackError(
          'Custom food',
          response['message']?.toString() ?? 'Could not create food',
        );
        return null;
      }

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return FoodItem.fromNutritionCustomFoodApi(data);
      }
      if (data is Map) {
        return FoodItem.fromNutritionCustomFoodApi(
          Map<String, dynamic>.from(data),
        );
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
        {
          'name': name.trim(),
          'servingSize': servingSize,
          'servingUnit': servingUnit.trim(),
          'calories': calories,
          'proteinG': proteinG,
          'carbsG': carbsG,
          'fatG': fatG,
        },
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
        _snackError(
          'Custom food',
          response['message']?.toString() ?? 'Could not update food',
        );
        return null;
      }

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return FoodItem.fromNutritionCustomFoodApi(data);
      }
      if (data is Map) {
        return FoodItem.fromNutritionCustomFoodApi(
          Map<String, dynamic>.from(data),
        );
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
        _snackError(
          'Custom food',
          response['message']?.toString() ?? 'Could not delete food',
        );
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
}
