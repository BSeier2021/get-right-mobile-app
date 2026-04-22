class AppUrl {
  static const String baseUrl = 'http://getright.prodservers.com:9965/api/v1';
  static const String imnageUrl = 'http://getright.prodservers.com:9965/api/v1';
  // development url
  // static const String baseUrl = 'https://rampantly-proemial-antonietta.ngrok-free.dev/api/v1';
  // static const String imnageUrl = 'https://rampantly-proemial-antonietta.ngrok-free.dev/api/v1';
  // static const String socketUrl = 'http://getright.prodservers.com:9965/';

  static String signUp = '$baseUrl/user/auth/signup';
  static String verifyOTP = '$baseUrl/user/auth/verify-otp';

  /// POST body: `{ "email": "..." }` — resend signup / verification OTP.
  static String sendOtp = '$baseUrl/user/auth/send-otp';

  /// `POST` multipart — fields: fullName, dateofbirth, gender, phoneNumber; file: profilePicture.
  static String createProfile = '$baseUrl/customer/profile/create';

  /// `POST /user/auth/login` — body: email, password, deviceType, deviceToken.
  static String signIn = '$baseUrl/user/auth/login';

  /// `POST /user/auth/forget` — body: `{ "email": "..." }`; OTP sent to registered email.
  static String forgotPassword = '$baseUrl/user/auth/forget';

  /// `POST /user/auth/forget-password` — body: `{ "password": "..." }` (Bearer after verify-otp in forgot flow).
  static String resetPassword = '$baseUrl/user/auth/forget-password';
  static String preference = '$baseUrl/user/preferences';
  static String goals = '$baseUrl/user/goals';
  static String fitnessLevels = '$baseUrl/user/fitness-level';
  static String exercisePlans = '$baseUrl/user/exercise-plan';
  static String updateProfile = '$baseUrl/customer/profile/update';
  static String getProfile = '$baseUrl/customer/profile';
  static String exerciseCategories = '$baseUrl/user/exercise-categories';
  static String exerciseCategory(String categoryId) => '$baseUrl/user/exercises/category/$categoryId';
  static String exerciseDetail(String exerciseId) => '$baseUrl/user/exercises/$exerciseId';

  // static String AllPlans = '$baseUrl/get-all-plans';
  static String autoLogin = '$baseUrl/auth/auto-login';
  static String changePassword = '$baseUrl/user/auth/change-password';
  static String voicePosts = '$baseUrl/voice-posts';
  static String createVoicePost = '$baseUrl/voice-posts';

  /////////logout API//
  static String logout = '$baseUrl/auth/logout';

  /// `GET /marketplace/sections` — query: `page`, `per_page`, `section` (`featured` | `new_releases` | …).
  static String marketplaceSections({required int page, required int perPage, required String section}) {
    final q = Uri(queryParameters: {'page': '$page', 'per_page': '$perPage', 'section': section}).query;
    return '$baseUrl/marketplace/sections?$q';
  }

  /// `GET /marketplace/programs` — paginated full catalog.
  static String marketplacePrograms({required int page, required int perPage}) {
    final q = Uri(queryParameters: {'page': '$page', 'per_page': '$perPage'}).query;
    return '$baseUrl/marketplace/programs?$q';
  }

  /// `GET /marketplace/bundles` — paginated bundles (`programs` may be program id strings).
  static String marketplaceBundles({required int page, required int perPage}) {
    final q = Uri(queryParameters: {'page': '$page', 'per_page': '$perPage'}).query;
    return '$baseUrl/marketplace/bundles?$q';
  }

  /// `GET /nutrition/tracker` — optional `date` (`YYYY-MM-DD`).
  static String nutritionTracker({String? date}) {
    if (date == null || date.isEmpty) return '$baseUrl/nutrition/tracker';
    final q = Uri(queryParameters: {'date': date}).query;
    return '$baseUrl/nutrition/tracker?$q';
  }

  /// `GET /nutrition/meal-types` → `data.mealTypes`.
  static String get nutritionMealTypes => '$baseUrl/nutrition/meal-types';

  /// `GET /nutrition/foods/custom` — query: `page`, `per_page`, `mealId`.
  static String nutritionFoodsCustom({required int page, required int perPage, required String mealId}) {
    final q = Uri(queryParameters: {'page': '$page', 'per_page': '$perPage', 'mealId': mealId}).query;
    return '$baseUrl/nutrition/foods/custom?$q';
  }

  /// `POST /nutrition/foods/custom` — JSON body (create custom food).
  static String get nutritionFoodsCustomCreate => '$baseUrl/nutrition/foods/custom';

  /// `PUT` (update) / `PATCH` (delete) custom food by document id. Optional [mealId] query when the API requires it.
  static String nutritionFoodsCustomById(String id, {String? mealId}) {
    final path = '$baseUrl/nutrition/foods/custom/${Uri.encodeComponent(id.trim())}';
    if (mealId == null || mealId.trim().isEmpty) return path;
    final q = Uri(queryParameters: {'mealId': mealId.trim()}).query;
    return '$path?$q';
  }
}
