class AppUrl {
  // development url
  // static const String baseUrl = 'http://getright.prodservers.com:8003/api/v1';
  // static const String socketUrl = 'http://getright.prodservers.com:8003';

  // client url
  static const String baseUrl = 'http://getright.prodservers.com:8004/api/v1';
  static const String imnageUrl = 'http://getright.prodservers.com:8004/api/v1';
  static const String socketUrl = 'http://getright.prodservers.com:8004';

  static String signUp = '$baseUrl/user/auth/signup';
  static String verifyOTP = '$baseUrl/user/auth/verify-otp';

  /// POST body: `{ "email": "..." }` — resend signup / verification OTP.
  static String sendOtp = '$baseUrl/user/auth/send-otp';

  /// `POST` multipart — fields: fullName, dateofbirth, gender, phoneNumber; file: profilePicture.
  static String createProfile = '$baseUrl/customer/profile/create';

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

  /// `POST /user/profiles/personal-records` — body: `name`, `value`, `unit`, `date`, `isPublic`.
  static String get userPersonalRecords => '$baseUrl/user/profiles/personal-records';

  /// `PUT`/`DELETE /user/profiles/personal-records/:recordId`.
  static String userPersonalRecordById(String recordId) => '$userPersonalRecords/${Uri.encodeComponent(recordId.trim())}';

  /// `POST /user/follow/:userId` — follow user (Bearer). Response: `data.isFollowing`.
  /// `DELETE /user/follow/:userId` — unfollow (Bearer). Response: `data.isFollowing`.
  static String userFollow(String userId) => '$baseUrl/user/follow/${Uri.encodeComponent(userId.trim())}';

  /// `GET /user/follow/:userId/followers` — paginated `data.followers.follows[]`.
  static String userFollowers(String userId) => '${userFollow(userId)}/followers';

  /// `GET /user/follow/:userId/following` — paginated `data.following.follows[]`.
  static String userFollowing(String userId) => '${userFollow(userId)}/following';

  /// `GET /user/report` — paginated `data.result.reports[]` (current user's submitted reports).
  static String get userReports => '$baseUrl/user/report';

  /// `POST /user/report/:id` — path id is reported user for `Auth`; reel creator id for `Feeds` (body `reportRef` = feed id).
  static String userReport(String reportRef) => '$baseUrl/user/report/${Uri.encodeComponent(reportRef.trim())}';

  /// `GET /user/block` — paginated `data.blocked.blocked[]`. `POST`/`DELETE` same collection + `/:userId`.
  static String get userBlocks => '$baseUrl/user/block';

  /// `POST /user/block/:userId` — block. `DELETE` — unblock.
  static String userBlock(String userId) => '${userBlocks}/${Uri.encodeComponent(userId.trim())}';

  static String exerciseCategories({int page = 1, int limit = 50}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit'}).query;
    return '$baseUrl/user/exercise-categories?$q';
  }

  /// `GET /user/feed-categories` → `data.categories[]` (feed post categories).
  static String get feedCategories => '$baseUrl/user/feed-categories';

  /// `POST /user/feed` — JSON: `title`, `description`, `category` (id), `tags`, optional `status` (`Draft`|`Published`).
  /// Image posts may use multipart on the same path (e.g. file field `images`).
  static String get feedCreate => '$baseUrl/user/feed';

  /// `GET /user/feed/mine` — query: `page`, `limit`. Authenticated user's own feed posts.
  static String get feedMine => '$baseUrl/user/feed/mine';

  /// `GET /user/feed/:feedId` — single published feed reel + viewer flags (`likedByMe`, `savedByMe`).
  static String feedById(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}';

  /// `DELETE /user/feed/:feedId` — remove post (same path as [feedById], e.g. `/user/feed/69f8eaeb3447d7cba1700ec4`).
  static String feedDelete(String feedId) => feedById(feedId);

  /// `POST /user/feed/:feedId/like` — like reel. `DELETE` same path — unlike (`message`: `Like removed`).
  static String feedLike(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}/like';

  /// `POST /user/feed/:feedId/save` — save reel (`message`: `Feed saved`). `DELETE` same path — unsave.
  static String feedSave(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}/save';

  /// `POST /user/feed/:feedId/repost` — repost reel to current user's feed.
  static String feedRepost(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}/repost';

  /// `GET /user/feed/save` — paginated saved reels (`data.savedFeeds[]` with nested `feed`, `hasNextPage`, …).
  static String get feedSavedList => '$baseUrl/user/feed/save';

  /// `GET /user/feed/:feedId/comments` — query: `page`, `limit`. `POST` body: `{ "text" }` → `data.comment`.
  static String feedComments(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}/comments';

  /// `PATCH` / `DELETE /user/feed/:feedId/comments/:commentId` — edit or delete a comment.
  static String feedCommentById(String feedId, String commentId) => '${feedComments(feedId)}/${Uri.encodeComponent(commentId.trim())}';

  /// `GET /user/feed/comments/:commentId/replies` — paginated replies (`data.comments`, `hasNextPage`, …).
  static String feedCommentReplies(String commentId) => '$baseUrl/user/feed/comments/${Uri.encodeComponent(commentId.trim())}/replies';

  /// `POST /user/feed/:feedId/video/multipart/init` — `contentType`, `fileSize`.
  static String feedVideoMultipartInit(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}/video/multipart/init';

  /// `POST /user/feed/:feedId/video/multipart/complete` — `key`, `uploadId`, `parts` (PartNumber, ETag).
  static String feedVideoMultipartComplete(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}/video/multipart/complete';

  /// `GET /user/exercises/` — all exercises for journal selection; query: `page`, `limit`.
  static String userExercises({int page = 1, int limit = 50}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit'}).query;
    return '$baseUrl/user/exercises/?$q';
  }

  /// `GET /user/exercises/category/:categoryId` — query: `page`, `limit`.
  static String exerciseCategory(String categoryId, {int page = 1, int limit = 20}) {
    final id = Uri.encodeComponent(categoryId.trim());
    return '$baseUrl/user/exercises/category/$id?page=$page&limit=$limit';
  }

  static String exerciseDetail(String exerciseId) => '$baseUrl/user/exercises/${Uri.encodeComponent(exerciseId.trim())}';

  // static String AllPlans = '$baseUrl/get-all-plans';
  /// `GET /user/auth/auto-login` — Bearer JWT; refreshes session (`data.user`, `data.token`).
  static String autoLogin = '$baseUrl/user/auth/auto-login';
  static String changePassword = '$baseUrl/user/auth/change-password';
  static String voicePosts = '$baseUrl/voice-posts';
  static String createVoicePost = '$baseUrl/voice-posts';

  /// `POST /user/auth/logout` — body: `{ "deviceToken": "..." }` (Bearer).
  static String get logout => '$baseUrl/user/auth/logout';

  /// `GET /customer/program` — paginated customer programs with optional filters.
  static String customerPrograms({
    required int page,
    required int limit,
    String? type,
    String? sort,
    List<String> categories = const [],
    List<String> difficulties = const [],
    int? durationMin,
    int? durationMax,
    bool? certifiedOnly,
    String? title,
  }) {
    final parts = <String>['page=$page', 'limit=$limit'];
    void add(String key, String value) => parts.add('$key=${Uri.encodeQueryComponent(value)}');

    if (type != null && type.trim().isNotEmpty) add('type', type.trim());
    if (sort != null && sort.trim().isNotEmpty) add('sort', sort.trim());
    for (final id in categories) {
      final t = id.trim();
      if (t.isNotEmpty) add('categories', t);
    }
    for (final d in difficulties) {
      final t = d.trim();
      if (t.isNotEmpty) add('difficulties', t);
    }
    if (durationMin != null) parts.add('durationMin=$durationMin');
    if (durationMax != null) parts.add('durationMax=$durationMax');
    if (certifiedOnly == true) parts.add('certifiedOnly=true');
    if (title != null && title.trim().isNotEmpty) add('title', title.trim());
    return '$baseUrl/customer/program?${parts.join('&')}';
  }

  /// `GET /marketplace/programs/:programId` — full program (`data.data`).
  static String marketplaceProgramDetail(String programId) => '$baseUrl/marketplace/programs/${Uri.encodeComponent(programId.trim())}';

  /// `GET /customer/program/:programId` — full program (`data.program`).
  static String customerProgramDetail(String programId) => '$baseUrl/customer/program/${Uri.encodeComponent(programId.trim())}';

  /// `GET /customer/program/:programId/reviews` — query: `page`, `limit`.
  static String customerProgramReviews(String programId, {required int page, required int limit}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit'}).query;
    return '$baseUrl/customer/program/${Uri.encodeComponent(programId.trim())}/reviews?$q';
  }

  /// `POST` / `PUT` / `DELETE /customer/program/:programId/reviews` — body (POST/PUT): `{ "rating", "description" }`.
  static String customerProgramReviewsSubmit(String programId) => '$baseUrl/customer/program/${Uri.encodeComponent(programId.trim())}/reviews';

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

  /// `GET /customer/workout-journal` — query: `page`, `limit`, `dateFrom` (`YYYY-MM-DD`), optional `date`.
  static String customerWorkoutJournalList({int page = 1, int limit = 10, String? dateFrom, String? date}) {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (dateFrom != null && dateFrom.trim().isNotEmpty) params['dateFrom'] = dateFrom.trim();
    if (date != null && date.trim().isNotEmpty) params['date'] = date.trim();
    final q = Uri(queryParameters: params).query;
    return '$baseUrl/customer/workout-journal?$q';
  }

  /// `POST /customer/workout-journal` — body: `date`, `workout` (id[]), `duration`, `notes`, optional `type`.
  static String get customerWorkoutJournalCreate => '$baseUrl/customer/workout-journal';

  /// `PUT /customer/workout-journal/:journalId` — body: `workout` (id[]), `duration`, `notes`.
  static String customerWorkoutJournalById(String journalId) => '$baseUrl/customer/workout-journal/${journalId.trim()}';

  /// `POST /customer/workout` — body: `type`, `name`, `exercise[]`, optional `refExercise`, `supersetIdentifier`, optional `workoutJournal`.
  static String get customerWorkout => '$baseUrl/customer/workout';

  /// `PUT /customer/workout/:workoutId` — body: `name`, `exercise[]`.
  static String customerWorkoutById(String workoutId) => '$baseUrl/customer/workout/${workoutId.trim()}';

  /// `POST /customer/running-logs` — body: `runningType`, `distance`, `duration`, `startTime`, `endTime`, `route`, `elevationGain`, `routePoints`, `caloriesBurned`.
  static String get customerRunningLogs => '$baseUrl/customer/running-logs';

  /// `GET /customer/food-saves` — query: `page`, `limit` → `data.foods[]`.
  static String customerFoodSaves({int page = 1, int limit = 10}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit'}).query;
    return '$baseUrl/customer/food-saves?$q';
  }

  /// `POST /customer/food-saves` — create saved food.
  static String get customerFoodSavesCreate => '$baseUrl/customer/food-saves';

  /// `PUT` / `DELETE /customer/food-saves/:foodSaveId`.
  static String customerFoodSaveById(String foodSaveId) => '$baseUrl/customer/food-saves/${Uri.encodeComponent(foodSaveId.trim())}';

  /// `GET /customer/food-logs/analytics` — query: `date` (`YYYY-MM-DD`), `dailyGoal`.
  static String customerFoodLogAnalytics({required String date, int dailyGoal = 2000}) {
    final q = Uri(queryParameters: {'date': date.trim(), 'dailyGoal': '$dailyGoal'}).query;
    return '$baseUrl/customer/food-logs/analytics?$q';
  }

  /// `POST /customer/food-logs` — create food log entry.
  static String get customerFoodLogsCreate => '$baseUrl/customer/food-logs';

  /// `GET` / `PUT` / `DELETE /customer/food-logs/:foodLogId`.
  static String customerFoodLogById(String foodLogId) => '$baseUrl/customer/food-logs/${Uri.encodeComponent(foodLogId.trim())}';

  /// `GET /customer/running-logs` — query: `page`, `limit` → `data.logs[]`.
  static String customerRunningLogsList({int page = 1, int limit = 10}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit'}).query;
    return '$baseUrl/customer/running-logs?$q';
  }

  /// `GET /customer/running-logs/:logId` → `data.log`.
  static String customerRunningLogById(String logId) => '$baseUrl/customer/running-logs/${Uri.encodeComponent(logId.trim())}';

  /// `POST /customer/planned-routes` — body: `location` (waypoint[] with `coordinates` [long, lat]).
  static String get customerPlannedRoutes => '$baseUrl/customer/planned-routes';

  /// `GET /customer/planned-routes` — query: `page`, `limit` → `data.routes[]`.
  static String customerPlannedRoutesList({int page = 1, int limit = 10}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit'}).query;
    return '$baseUrl/customer/planned-routes?$q';
  }

  /// `GET /customer/planned-routes/:routeId` → `data.route`.
  static String customerPlannedRouteById(String routeId) => '$baseUrl/customer/planned-routes/${Uri.encodeComponent(routeId.trim())}';

  /// `GET /user/chat/conversations` — query: `page`, `limit`, optional `search`.
  static String get chatConversations => '$baseUrl/user/chat/conversations';

  /// `GET /user/chat/conversations/unread-count` — total unread messages.
  static String get chatUnreadCount => '$chatConversations/unread-count';

  /// `GET /user/chat/conversations/with/:otherUserId` — get or create direct conversation.
  static String chatConversationWith(String otherUserId) => '$chatConversations/with/${Uri.encodeComponent(otherUserId.trim())}';

  /// `GET`/`POST /user/chat/conversations/:conversationId/messages` — GET query: `page`, `limit`; POST multipart: `content`, `attachments`.
  static String chatConversationMessages(String conversationId) => '$chatConversations/${Uri.encodeComponent(conversationId.trim())}/messages';

  /// `DELETE /user/chat/messages/:messageId` — delete a chat message.
  static String chatMessageDelete(String messageId) => '$baseUrl/user/chat/messages/${Uri.encodeComponent(messageId.trim())}';

  /// `POST /customer/calendar` — body: `date`, `type`, optional `notes`, `workoutJournal`, `progressPhotos` (multipart file).
  static String get customerCalendarCreate => '$baseUrl/customer/calendar';

  /// `GET /customer/calendar` — query: `year`, `month` → `data.entries[]`.
  static String customerCalendarList({required int year, required int month}) {
    final q = Uri(queryParameters: {'year': '$year', 'month': '$month'}).query;
    return '$baseUrl/customer/calendar?$q';
  }

  /// `GET /customer/calendar/:calendarEntryId` → `data.entry`, `data.nutrition`.
  /// `PUT /customer/calendar/:calendarEntryId` — body: `notes`, `type`, optional `progressPhotos` (multipart file).
  /// `DELETE /customer/calendar/:calendarEntryId` — remove calendar entry.
  static String customerCalendarById(String calendarEntryId) => '$baseUrl/customer/calendar/${Uri.encodeComponent(calendarEntryId.trim())}';

  /// `POST /customer/calendar/program/map` — body: `enrollmentId`, `programId`, `startDate`.
  static String get customerCalendarProgramMap => '$baseUrl/customer/calendar/program/map';

  /// `POST /customer/calendar/program/move` — body: `calendarEntryId`, `targetDate`.
  static String get customerCalendarProgramMove => '$baseUrl/customer/calendar/program/move';
}
