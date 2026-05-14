class AppUrl {
  static const String baseUrl = 'http://getright.prodservers.com:8003/api/v1';
  static const String imnageUrl = 'http://getright.prodservers.com:8003/api/v1';
  // development url
  // static const String baseUrl = 'https://1x35v509-8000.asse.devtunnels.ms/api/v1';
  // static const String imnageUrl = 'https://1x35v509-8000.asse.devtunnels.ms/api/v1';
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

  /// `GET /user/profiles/:userId/details` — trainer/customer public card (`data.user`, counts, `isFollowedByMe`).
  static String profileUserDetails(String userId) => '$baseUrl/user/profiles/${Uri.encodeComponent(userId.trim())}/details';

  /// `GET /user/profiles/:userId/posts` — query: `page`, `limit`.
  static String profileUserPosts(String userId) => '$baseUrl/user/profiles/${Uri.encodeComponent(userId.trim())}/posts';

  /// `GET /user/profiles/:userId/programs` — paginated `data.programs.programs[]`.
  static String profileUserPrograms(String userId) => '$baseUrl/user/profiles/${Uri.encodeComponent(userId.trim())}/programs';

  /// `GET /user/profiles/:userId/bundles` — paginated `data.bundles.bundles[]` (mirror of programs shape).
  static String profileUserBundles(String userId) => '$baseUrl/user/profiles/${Uri.encodeComponent(userId.trim())}/bundles';

  /// `POST /user/profiles/:userId/follow` — follow trainer (Bearer).
  static String profileUserFollow(String userId) => '$baseUrl/user/profiles/${Uri.encodeComponent(userId.trim())}/follow';

  /// `POST /user/profiles/:userId/unfollow` — unfollow (Bearer). Adjust if backend uses DELETE on [profileUserFollow].
  static String profileUserUnfollow(String userId) => '$baseUrl/user/profiles/${Uri.encodeComponent(userId.trim())}/unfollow';

  static String exerciseCategories = '$baseUrl/user/exercise-categories';

  /// `GET /user/feed-categories` → `data.categories[]` (feed post categories).
  static String get feedCategories => '$baseUrl/user/feed-categories';

  /// `POST /user/feed` — body: `title`, `description`, `category` (id), `tags` (string array).
  static String get feedCreate => '$baseUrl/user/feed';

  /// `GET /user/feed/mine` — query: `page`, `limit`. Authenticated user's own feed posts.
  static String get feedMine => '$baseUrl/user/feed/mine';

  /// `GET /user/feed/:feedId` — single published feed reel + viewer flags (`likedByMe`, `savedByMe`).
  static String feedById(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}';

  /// `DELETE /user/feed/:feedId` — remove post (same path as [feedById], e.g. `/user/feed/69f8eaeb3447d7cba1700ec4`).
  static String feedDelete(String feedId) => feedById(feedId);

  /// `POST /user/feed/:feedId/video/multipart/init` — `contentType`, `fileSize`.
  static String feedVideoMultipartInit(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}/video/multipart/init';

  /// `POST /user/feed/:feedId/video/multipart/complete` — `key`, `uploadId`, `parts` (PartNumber, ETag).
  static String feedVideoMultipartComplete(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}/video/multipart/complete';

  static String exerciseCategory(String categoryId) => '$baseUrl/user/exercises/category/$categoryId';
  static String exerciseDetail(String exerciseId) => '$baseUrl/user/exercises/$exerciseId';

  // static String AllPlans = '$baseUrl/get-all-plans';
  /// `GET /user/auth/auto-login` — Bearer JWT; refreshes session (`data.user`, `data.token`).
  static String autoLogin = '$baseUrl/user/auth/auto-login';
  static String changePassword = '$baseUrl/user/auth/change-password';
  static String voicePosts = '$baseUrl/voice-posts';
  static String createVoicePost = '$baseUrl/voice-posts';

  /// `POST /user/auth/logout` — body: `{ "deviceToken": "..." }` (Bearer).
  static String get logout => '$baseUrl/user/auth/logout';

  /// `GET /customer/program` — paginated customer programs (`page`, `limit`, `type`).
  static String customerPrograms({required int page, required int limit, required String type}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit', 'type': type}).query;
    return '$baseUrl/customer/program?$q';
  }

  /// `GET /marketplace/programs/:programId` — full program (`data.data`).
  static String marketplaceProgramDetail(String programId) => '$baseUrl/marketplace/programs/${Uri.encodeComponent(programId.trim())}';

  /// `GET /customer/program/:programId` — full program (`data.program`).
  static String customerProgramDetail(String programId) => '$baseUrl/customer/program/${Uri.encodeComponent(programId.trim())}';

  /// `POST /customer/program/enroll` — body: `{ "id": "<programOrBundleId>", "isBundle": bool }` → `data.enrollment` (program) or `data.enrollments` (bundle).
  static String get customerProgramEnroll => '$baseUrl/customer/program/enroll';

  /// `GET /customer/program/enrolled` — query: `page`, `limit`, `status` (active | completed | cancelled | scheduled).
  static String customerProgramEnrolled({required int page, required int limit, required String status}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit', 'status': status.trim().toLowerCase()}).query;
    return '$baseUrl/customer/program/enrolled?$q';
  }

  /// `GET /customer/program/enrolled/:enrollmentId` — single enrollment with nested `program` (full media, exercises).
  static String customerProgramEnrolledDetail(String enrollmentId) => '$baseUrl/customer/program/enrolled/${Uri.encodeComponent(enrollmentId.trim())}';

  /// `GET /customer/bundle` — paginated bundle deals (`page`, `limit`). Response: `data.bundles`, `totalDocs`, `hasNextPage`.
  static String customerBundles({required int page, required int limit}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit'}).query;
    return '$baseUrl/customer/bundle?$q';
  }

  /// `GET /customer/bundle/:bundleId` — full bundle (`data.bundle`) with nested programs.
  static String customerBundleDetail(String bundleId) => '$baseUrl/customer/bundle/${Uri.encodeComponent(bundleId.trim())}';

  /// `GET /marketplace/bundles` — paginated bundles (`programs` may be program id strings).
  static String marketplaceBundles({required int page, required int perPage}) {
    final q = Uri(queryParameters: {'page': '$page', 'per_page': '$perPage'}).query;
    return '$baseUrl/marketplace/bundles?$q';
  }

  /// `GET /marketplace/bundles/:bundleId` — full bundle with programs, [pricing_summary], [marketplace_detail].
  static String marketplaceBundleDetail(String bundleId) => '$baseUrl/marketplace/bundles/${Uri.encodeComponent(bundleId.trim())}';

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
