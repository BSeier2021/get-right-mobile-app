import 'dart:io';
import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';

class AuthRepository {
  final _network = NetworkApiService();

  Future<dynamic> signUp({required String email, required String password, required String deviceType, required String deviceToken, String role = 'Customer'}) async {
    final response = await _network.post(
      AppUrl.signUp,
      {"email": email, "password": password, "deviceType": deviceType, "deviceToken": deviceToken, "role": role},
      headers: {"Authorization": "yNaHwJpGFSquIkXP"},
    );
    return response;
  }

  Future<dynamic> verifyOTPRepo({required String userId, required String otp}) async {
    final response = await _network.post(AppUrl.verifyOTP, {"userId": userId, "otp": otp}, headers: {"Authorization": "yNaHwJpGFSquIkXP"});
    return response;
  }

  /// `POST /user/auth/send-otp` with `{ "email": "user@example.com" }`.
  Future<dynamic> sendOtpRepo({required String email}) async {
    final response = await _network.post(AppUrl.sendOtp, {"email": email.trim()}, headers: {"Authorization": "yNaHwJpGFSquIkXP"});
    return response;
  }

  /// `POST /customer/profile/create` — multipart form: fullName, dateofbirth, gender, phoneNumber, optional profilePicture (file).
  Future<dynamic> createProfileRepo({required String fullName, required String dateofbirth, required String gender, required String phoneNumber, File? profilePicture}) async {
    final fields = <String, dynamic>{'fullName': fullName.trim(), 'dateofbirth': dateofbirth, 'gender': gender, 'phoneNumber': phoneNumber.trim()};
    final files = <String, List<File>>{};
    if (profilePicture != null && profilePicture.path.isNotEmpty && await profilePicture.exists()) {
      files['profilePicture'] = [profilePicture];
    }
    return _network.postMultipart(url: AppUrl.createProfile, fields: fields, files: files);
  }

  Future<dynamic> loginRepo({required String email, required String password, required String deviceType, required String deviceToken}) async {
    final response = await _network.post(
      AppUrl.signIn,
      {"email": email.trim(), "password": password, "deviceType": deviceType, "deviceToken": deviceToken},
      headers: {"Authorization": "yNaHwJpGFSquIkXP"},
    );
    return response;
  }

  /// `GET /user/auth/auto-login` — uses persisted Bearer from [NetworkApiService].
  Future<dynamic> autoLoginRepo() async {
    return _network.get(AppUrl.autoLogin);
  }

  /// `POST /user/auth/logout` — body: `deviceToken` (Bearer).
  Future<dynamic> logoutRepo({required String deviceToken}) async {
    return _network.post(AppUrl.logout, {'deviceToken': deviceToken.trim()});
  }

  /// `POST /user/auth/forget` with `{ "email": "..." }`.
  Future<dynamic> forgotPasswordRepo({required String email}) async {
    final response = await _network.post(AppUrl.forgotPassword, {"email": email.trim()}, headers: {"Authorization": "yNaHwJpGFSquIkXP"});
    return response;
  }

  /// `POST /user/auth/forget-password` — body: `{ "password": "..." }`. Uses Bearer from [NetworkApiService].
  Future<dynamic> resetPasswordRepo({required String password}) async {
    final response = await _network.post(AppUrl.resetPassword, {"password": password.trim()});
    return response;
  }

  Future<dynamic> getPreferencesRepo() async {
    final response = await _network.get(AppUrl.preference, headers: {"Authorization": "yNaHwJpGFSquIkXP"});
    return response;
  }

  /// `GET /user/goals` — Bearer from [NetworkApiService] (same as preferences).
  Future<dynamic> getGoalsRepo() async {
    final response = await _network.get(AppUrl.goals, headers: {"Authorization": "yNaHwJpGFSquIkXP"});
    return response;
  }

  /// `GET /user/fitness-level` → `data.fitnessLevels`.
  Future<dynamic> getFitnessLevelsRepo() async {
    final response = await _network.get(AppUrl.fitnessLevels, headers: {"Authorization": "yNaHwJpGFSquIkXP"});
    return response;
  }

  /// `GET /user/exercise-plan` → `data.exercisePlans`.
  Future<dynamic> getExercisePlansRepo() async {
    final response = await _network.get(AppUrl.exercisePlans, headers: {"Authorization": "yNaHwJpGFSquIkXP"});
    return response;
  }

  // Future<dynamic> getAllPlansRepo() async {
  //   final response = await _network.get(AppUrl.AllPlans);
  //   return response;
  // }

  /// `POST /customer/profile/update` — JSON, or multipart when [profilePicturePath] is set (field `profilePicture` + form fields).
  /// Send API slugs for `primaryFocus` / `mainGoals` (e.g. `strength_training`, `lose_weight`) and plan-style `exerciseFrequency` (e.g. `FiveTimesaWeek`).
  Future<dynamic> updateProfileRepo({
    String? fullName,
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
    final fields = <String, dynamic>{};

    if (fullName != null && fullName.trim().isNotEmpty) {
      fields['fullName'] = fullName.trim();
    }
    if (dateofbirth != null && dateofbirth.trim().isNotEmpty) {
      fields['dateofbirth'] = dateofbirth.trim();
    }
    if (gender != null && gender.trim().isNotEmpty) {
      fields['gender'] = gender.trim();
    }
    if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
      fields['phoneNumber'] = phoneNumber.trim();
    }
    if (bio != null && bio.trim().isNotEmpty) {
      fields['bio'] = bio.trim();
    }
    if (primaryFocus != null && primaryFocus.trim().isNotEmpty) {
      fields['primaryFocus'] = primaryFocus.trim();
    }
    if (preferenceId != null && preferenceId.trim().isNotEmpty) {
      fields['preferences'] = preferenceId.trim();
    }

    if (goalIds != null && goalIds.isNotEmpty) {
      final ids = goalIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (ids.isNotEmpty) {
        fields['goals'] = ids;
      }
    }
    if (fitnessLevel != null && fitnessLevel.trim().isNotEmpty) {
      fields['fitnessLevel'] = fitnessLevel.trim();
    }
    if (exerciseFrequency != null && exerciseFrequency.trim().isNotEmpty) {
      fields['exerciseFrequency'] = exerciseFrequency.trim();
    }

    if (fields.isEmpty && (profilePicturePath == null || profilePicturePath.trim().isEmpty)) {
      throw Exception('No valid data to update');
    }

    if (profilePicturePath != null && profilePicturePath.trim().isNotEmpty) {
      final file = File(profilePicturePath.trim());
      if (!await file.exists()) {
        throw Exception('Profile picture file does not exist');
      }
      final multipartFields = <String, dynamic>{};
      fields.forEach((key, value) {
        if (key == 'mainGoals' && value is List) {
          multipartFields['mainGoals[]'] = value;
        } else if (key == 'goals' && value is List) {
          // [NetworkApiService.sendMultipart] only expands arrays when the key ends with [];
          // otherwise List becomes value.toString() → backend sees a string, not an array.
          multipartFields['goals[]'] = value;
        } else {
          multipartFields[key] = value;
        }
      });
      final files = <String, List<File>>{
        'profilePicture': [file],
      };
      return _network.postMultipart(url: AppUrl.updateProfile, fields: multipartFields, files: files);
    }

    return _network.post(AppUrl.updateProfile, fields);
  }

  /// `POST /customer/profile/update` — JSON: `dailyCalorieGoal`.
  Future<dynamic> updateDailyCalorieGoalRepo(num dailyCalorieGoal) async {
    return _network.post(AppUrl.updateProfile, {'dailyCalorieGoal': dailyCalorieGoal});
  }

  /// `GET /customer/profile` — Bearer; returns `data.user` with nested `profile`.
  Future<dynamic> getProfileRepo() async {
    return _network.get(AppUrl.getProfile);
  }

  /// `GET /customer/program` — paginated customer program catalog (`data.programs`).
  Future<dynamic> getMarketplaceProgramsRepo({int page = 1, int perPage = 10, String type = 'All'}) async {
    return _network.get(AppUrl.customerPrograms(page: page, limit: perPage, type: type));
  }

  /// `GET /customer/program/:programId` — program detail; root `data.program` holds the program document.
  Future<dynamic> getMarketplaceProgramDetailRepo(String programId) async {
    return _network.get(AppUrl.customerProgramDetail(programId));
  }

  /// `POST /customer/program/enroll` — enroll in a program or bundle (`isBundle`).
  Future<dynamic> enrollProgramRepo({required String id, required bool isBundle}) async {
    return _network.post(AppUrl.customerProgramEnroll, {'id': id.trim(), 'isBundle': isBundle});
  }

  /// `GET /customer/program/enrolled` — paginated enrollments (`data.enrollments`), filtered by [status].
  Future<dynamic> getCustomerEnrolledProgramsRepo({int page = 1, int limit = 10, required String status}) async {
    return _network.get(AppUrl.customerProgramEnrolled(page: page, limit: limit, status: status));
  }

  /// `GET /customer/program/enrolled/:enrollmentId` — `data.enrollment` with nested full `program`.
  Future<dynamic> getEnrolledProgramDetailRepo(String enrollmentId) async {
    return _network.get(AppUrl.customerProgramEnrolledDetail(enrollmentId));
  }

  /// `GET /customer/bundle` — paginated bundle deals (`limit` maps from [perPage]).
  Future<dynamic> getMarketplaceBundlesRepo({int page = 1, int perPage = 10}) async {
    return _network.get(AppUrl.customerBundles(page: page, limit: perPage));
  }

  /// `GET /customer/bundle/:bundleId` — detail; root `data.bundle` holds the bundle document.
  Future<dynamic> getMarketplaceBundleDetailRepo(String bundleId) async {
    return _network.get(AppUrl.customerBundleDetail(bundleId));
  }

  /// `POST /user/auth/change-password` — body: `{ "oldPassword": "...", "newPassword": "..." }` (Bearer).
  Future<dynamic> changePasswordRepo({required String oldPassword, required String newPassword}) async {
    final response = await _network.post(AppUrl.changePassword, {"oldPassword": oldPassword.trim(), "newPassword": newPassword.trim()});
    return response;
  }

  Future<dynamic> getExerciseCategoriesRepo() async {
    final response = await _network.get(
      AppUrl.exerciseCategories(),
      headers: {'skipAuth': 'true', 'Authorization': NetworkApiService.guestAuthToken},
    );
    return response;
  }

  /// `GET /user/feed-categories` → `data.categories`.
  Future<dynamic> getFeedCategoriesRepo() async {
    // Backend expects the raw guest token (non-Bearer) here.
    final response = await _network.get(AppUrl.feedCategories, headers: {"skipAuth": "true", "Authorization": NetworkApiService.guestAuthToken});
    return response;
  }

  Future<dynamic> getExercisesByCategoryRepo(String categoryId) async {
    final response = await _network.get(
      AppUrl.exerciseCategory(categoryId),
      headers: {'skipAuth': 'true', 'Authorization': NetworkApiService.guestAuthToken},
    );
    return response;
  }

  /// `GET /nutrition/tracker` — Bearer from [NetworkApiService]; optional [date] `YYYY-MM-DD`.
  Future<dynamic> getNutritionTrackerRepo({String? date}) async {
    return _network.get(AppUrl.nutritionTracker(date: date));
  }

  /// `GET /nutrition/meal-types` — Bearer from [NetworkApiService].
  Future<dynamic> getNutritionMealTypesRepo() async {
    return _network.get(AppUrl.nutritionMealTypes);
  }

  /// `GET /nutrition/foods/custom` — paginated custom foods for a meal type id.
  Future<dynamic> getNutritionCustomFoodsRepo({required String mealId, int page = 1, int perPage = 20}) async {
    return _network.get(AppUrl.nutritionFoodsCustom(page: page, perPage: perPage, mealId: mealId));
  }

  /// `POST /nutrition/foods/custom` — Bearer; body: name, mealType, servingSize, servingUnit, calories, proteinG, carbsG, fatG.
  Future<dynamic> createNutritionCustomFoodRepo(Map<String, dynamic> body) async {
    return _network.post(AppUrl.nutritionFoodsCustomCreate, body);
  }

  /// `PUT /nutrition/foods/custom/:id` — JSON: name, servingSize, servingUnit, calories, proteinG, carbsG, fatG.
  Future<dynamic> updateNutritionCustomFoodRepo(String id, Map<String, dynamic> body, {String? mealId}) async {
    return _network.put(AppUrl.nutritionFoodsCustomById(id, mealId: mealId), body);
  }

  /// `PATCH /nutrition/foods/custom/:id` — delete (API uses PATCH, not DELETE).
  Future<dynamic> deleteNutritionCustomFoodRepo(String id, {String? mealId}) async {
    return _network.patch(AppUrl.nutritionFoodsCustomById(id, mealId: mealId), {});
  }

  /// `GET /customer/food-saves` — paginated saved foods.
  Future<dynamic> getFoodSavesRepo({int page = 1, int limit = 10}) async {
    return _network.get(AppUrl.customerFoodSaves(page: page, limit: limit));
  }

  /// `POST /customer/food-saves` — JSON: name, servingSize, unit, calories, macronutrients.
  Future<dynamic> createFoodSaveRepo(Map<String, dynamic> body) async {
    return _network.post(AppUrl.customerFoodSavesCreate, body);
  }

  /// `PUT /customer/food-saves/:id` — JSON: name, calories, macronutrients.
  Future<dynamic> updateFoodSaveRepo(String id, Map<String, dynamic> body) async {
    return _network.put(AppUrl.customerFoodSaveById(id), body);
  }

  /// `DELETE /customer/food-saves/:id`.
  Future<dynamic> deleteFoodSaveRepo(String id) async {
    return _network.delete(AppUrl.customerFoodSaveById(id));
  }

  /// `GET /customer/food-logs/analytics` — query: `date`, `dailyGoal`.
  Future<dynamic> getFoodLogAnalyticsRepo({required String date, int dailyGoal = 2000}) async {
    return _network.get(AppUrl.customerFoodLogAnalytics(date: date, dailyGoal: dailyGoal));
  }

  /// `POST /customer/food-logs` — JSON: mealType, meal (foodSaveId), loggedAt, servings, notes.
  Future<dynamic> createFoodLogRepo(Map<String, dynamic> body) async {
    return _network.post(AppUrl.customerFoodLogsCreate, body);
  }

  /// `GET /customer/food-logs/:foodLogId` → `data.log`.
  Future<dynamic> getFoodLogDetailRepo(String foodLogId) async {
    return _network.get(AppUrl.customerFoodLogById(foodLogId));
  }

  /// `PUT /customer/food-logs/:foodLogId` — JSON: mealType, servings, notes.
  Future<dynamic> updateFoodLogRepo(String foodLogId, Map<String, dynamic> body) async {
    return _network.put(AppUrl.customerFoodLogById(foodLogId), body);
  }

  /// `DELETE /customer/food-logs/:foodLogId`.
  Future<dynamic> deleteFoodLogRepo(String foodLogId) async {
    return _network.delete(AppUrl.customerFoodLogById(foodLogId));
  }
}
