class AppUrl {
  // development url
  // static const String baseUrl = 'http://getright.prodservers.com:8003/api/v1';
  // static const String imnageUrl = 'http://getright.prodservers.com:8003/api/v1';
  // static const String socketUrl = 'http://getright.prodservers.com:8003';

  // client url — local Mac API (same Wi‑Fi as phone)
  static const String baseUrl = 'http://192.168.40.32:8004/api/v1';
  static const String imnageUrl = 'http://192.168.40.32:8004/api/v1';
  static const String socketUrl = 'http://192.168.40.32:8004';



  
  

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

  /// `GET /customer/profile/progress` — optional `startDate` / `endDate` (`yyyy-MM-dd`).
  static String customerProfileProgress({DateTime? startDate, DateTime? endDate}) {
    final params = <String, String>{};
    if (startDate != null) params['startDate'] = _apiDateKey(startDate);
    if (endDate != null) params['endDate'] = _apiDateKey(endDate);
    if (params.isEmpty) return '$baseUrl/customer/profile/progress';
    return '$baseUrl/customer/profile/progress?${Uri(queryParameters: params).query}';
  }

  static String _apiDateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// `GET /user/discover` — search users (`search`, `role`, `sort`, `page`, `limit`).
  static String usersDiscover({
    String? search,
    String? role,
    String? sort,
    int page = 1,
    int limit = 20,
  }) {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    final q = search?.trim();
    if (q != null && q.isNotEmpty) params['search'] = q;
    final r = role?.trim();
    if (r != null && r.isNotEmpty) params['role'] = r;
    final s = sort?.trim();
    if (s != null && s.isNotEmpty) params['sort'] = s;
    return '$baseUrl/user/discover?${Uri(queryParameters: params).query}';
  }

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

  /// `GET /user/report` — query: `page`, `limit`, optional `status`, optional `type` (`ReportRefTypeEnums`).
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

  /// `POST /user/feed/:feedId/share` — share analytics (`channel`: `copy_link` | `native_share` | `chat`).
  static String feedShareAnalytics(String feedId) => '$baseUrl/user/feed/${Uri.encodeComponent(feedId.trim())}/share';

  /// Public web app origin for reel deep links (`/reels/:feedId`).
  static const String webAppBaseUrl = 'http://getright.prodservers.com:8011';

  static String reelShareLink(String feedId) => '$webAppBaseUrl/reels/${Uri.encodeComponent(feedId.trim())}';

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

  /// `DELETE /user/auth/account` — body: `{ "password": "...", "deviceToken": "..." }` (Bearer).
  static String get deleteAccount => '$baseUrl/user/auth/account';

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

  /// `POST /customer/program/enrolled/:enrollmentId/cancel` — cancel a scheduled enrollment.
  static String customerProgramEnrolledCancel(String enrollmentId) =>
      '$baseUrl/customer/program/enrolled/${Uri.encodeComponent(enrollmentId.trim())}/cancel';

  /// `GET /customer/bundle` — paginated bundle deals (`page`, `limit`). Response: `data.bundles`, `totalDocs`, `hasNextPage`.
  static String customerBundles({required int page, required int limit}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit'}).query;
    return '$baseUrl/customer/bundle?$q';
  }

  /// `GET /customer/bundle/:bundleId` — full bundle (`data.bundle`) with nested programs.
  static String customerBundleDetail(String bundleId) => '$baseUrl/customer/bundle/${Uri.encodeComponent(bundleId.trim())}';

  /// `GET /customer/favourites` — query: `page`, `limit`, optional `type` (`program` | `bundle`).
  static String customerFavourites({int page = 1, int limit = 10, String? type}) {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (type != null && type.trim().isNotEmpty) params['type'] = type.trim();
    return '$baseUrl/customer/favourites?${Uri(queryParameters: params).query}';
  }

  /// `POST` / `DELETE /customer/favourites` — body: `{ itemId, type }`.
  static String get customerFavouritesMutate => '$baseUrl/customer/favourites';

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

  /// `GET /customer/workout-journal` — query: `page`, `limit`, `dateFrom`, `dateTo`, optional `status` (`Active` | `Completed` | `Incomplete`).
  static String customerWorkoutJournalList({
    int page = 1,
    int limit = 10,
    String? dateFrom,
    String? dateTo,
    String? status,
  }) {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (dateFrom != null && dateFrom.trim().isNotEmpty) params['dateFrom'] = dateFrom.trim();
    if (dateTo != null && dateTo.trim().isNotEmpty) params['dateTo'] = dateTo.trim();
    if (status != null && status.trim().isNotEmpty) params['status'] = status.trim();
    final q = Uri(queryParameters: params).query;
    return '$baseUrl/customer/workout-journal?$q';
  }

  /// `POST /customer/workout-journal` — body: `date` (ISO), `workout` (id[]), `duration`, `notes`, optional `type`.
  static String get customerWorkoutJournalCreate => '$baseUrl/customer/workout-journal';

  /// `PUT /customer/workout-journal/:journalId` — partial body: `workout`, `duration`, `notes`, `isComplete`.
  static String customerWorkoutJournalById(String journalId) => '$baseUrl/customer/workout-journal/${journalId.trim()}';

  /// `POST /customer/workout` — body: `type`, `name`, `exercise[]`, optional `refExercise`, `supersetIdentifier`, `workoutJournal`, `date`.
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
  static String customerFoodLogAnalytics({required String date, }) {
    final q = Uri(queryParameters: {'date': date.trim(),}).query;
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

  /// `GET /user/chat/conversations` — query: `page`, `limit`, optional `search`, optional `unblockedOnly`.
  static String get chatConversations => '$baseUrl/user/chat/conversations';

  /// `GET /user/chat/conversations/unread-count` — total unread messages.
  static String get chatUnreadCount => '$chatConversations/unread-count';

  /// `GET /user/chat/conversations/with/:otherUserId` — get or create direct conversation.
  static String chatConversationWith(String otherUserId) => '$chatConversations/with/${Uri.encodeComponent(otherUserId.trim())}';

  /// `GET`/`POST /user/chat/conversations/:conversationId/messages` — GET query: `page`, `limit`; POST multipart: `content`, `attachments`.
  static String chatConversationMessages(String conversationId) => '$chatConversations/${Uri.encodeComponent(conversationId.trim())}/messages';

  /// `DELETE /user/chat/messages/:messageId` — delete a chat message.
  static String chatMessageDelete(String messageId) => '$baseUrl/user/chat/messages/${Uri.encodeComponent(messageId.trim())}';

  /// `POST /customer/calendar` — body: `date`, `type`, optional `notes`, `workoutJournal`; multipart: `progressPhotoFront` / `progressPhotoBack`.
  static String get customerCalendarCreate => '$baseUrl/customer/calendar';

  /// `GET /customer/calendar` — query: `year`, `month` → `data.entries[]`.
  static String customerCalendarList({required int year, required int month}) {
    final q = Uri(queryParameters: {'year': '$year', 'month': '$month'}).query;
    return '$baseUrl/customer/calendar?$q';
  }

  /// `DELETE /customer/calendar/:calendarEntryId/running-logs/:runningLogId` — unlink run from day only.
  static String customerCalendarUnlinkRunningLog(String calendarEntryId, String runningLogId) =>
      '$baseUrl/customer/calendar/${Uri.encodeComponent(calendarEntryId.trim())}/running-logs/${Uri.encodeComponent(runningLogId.trim())}';

  /// `GET /customer/calendar/:calendarEntryId` → `data.entry`, `data.nutrition`.
  /// `PUT /customer/calendar/:calendarEntryId` — body: `notes`, `type`, `runningLog`, optional `removeProgressPhotosIds` + `progressPhotoFront` / `progressPhotoBack` (multipart file).
  /// `DELETE /customer/calendar/:calendarEntryId` — remove calendar entry.
  static String customerCalendarById(String calendarEntryId) => '$baseUrl/customer/calendar/${Uri.encodeComponent(calendarEntryId.trim())}';

  /// `POST /customer/calendar/program/map` — body: `enrollmentId`, `programId`, `startDate`.
  static String get customerCalendarProgramMap => '$baseUrl/customer/calendar/program/map';

  /// `POST /customer/calendar/program/move` — body: `calendarEntryId`, `targetDate`.
  static String get customerCalendarProgramMove => '$baseUrl/customer/calendar/program/move';

  /// `GET /customer/recipes/catalog` — query: `page`, `limit`, `sort`, `search`, `mealType`, `featured`.
  static String customerRecipesCatalog({
    int page = 1,
    int limit = 10,
    String? sort,
    String? search,
    String? mealType,
    bool? featured,
  }) {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (sort != null && sort.trim().isNotEmpty) params['sort'] = sort.trim();
    if (search != null && search.trim().isNotEmpty) params['search'] = search.trim();
    if (mealType != null && mealType.trim().isNotEmpty) params['mealType'] = mealType.trim();
    if (featured == true) params['featured'] = 'true';
    return '$baseUrl/customer/recipes/catalog?${Uri(queryParameters: params).query}';
  }

  /// `GET /customer/recipes/catalog/:recipeId`
  static String customerRecipeById(String recipeId) => '$baseUrl/customer/recipes/catalog/${Uri.encodeComponent(recipeId.trim())}';

  /// `POST /customer/recipes/purchase` — body: `recipeId`, `logToTracker` (`mealType`, `servings`).
  static String get customerRecipesPurchase => '$baseUrl/customer/recipes/purchase';

  /// `GET /customer/transactions` — query: `page`, `limit` → `data.transactions[]`, `data.summary`.
  static String customerTransactionsList({int page = 1, int limit = 10}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit'}).query;
    return '$baseUrl/customer/transactions?$q';
  }

  /// `GET /customer/transactions/summary` → `data.summary`.
  static String get customerTransactionsSummary => '$baseUrl/customer/transactions/summary';

  /// `GET /customer/transactions/:transactionId` → `data.transaction`.
  static String customerTransactionById(String transactionId) =>
      '$baseUrl/customer/transactions/${Uri.encodeComponent(transactionId.trim())}';

  /// `POST /user/support-tickets` — create ticket (default token, no Bearer prefix).
  static String get userSupportTickets => '$baseUrl/user/support-tickets';

  /// `GET /user/support-tickets?email=&page=&limit=&status=`
  static String userSupportTicketsList({
    required String email,
    int page = 1,
    int limit = 10,
    String? status,
  }) {
    final params = <String, String>{
      'email': email.trim(),
      'page': '$page',
      'limit': '$limit',
    };
    if (status != null && status.trim().isNotEmpty) {
      params['status'] = status.trim();
    }
    return '$baseUrl/user/support-tickets?${Uri(queryParameters: params).query}';
  }

  /// `GET /user/support-tickets/{ticketId}`
  static String userSupportTicketById(String ticketId) =>
      '$baseUrl/user/support-tickets/${Uri.encodeComponent(ticketId.trim())}';

  /// `GET|POST /user/support-tickets/{ticketId}/messages`
  static String userSupportTicketMessages(String ticketId, {int page = 1, int limit = 20}) {
    final q = Uri(queryParameters: {'page': '$page', 'limit': '$limit'}).query;
    return '$baseUrl/user/support-tickets/${Uri.encodeComponent(ticketId.trim())}/messages?$q';
  }

  /// `POST /user/support-tickets/{ticketId}/messages` (no query params).
  static String userSupportTicketReply(String ticketId) =>
      '$baseUrl/user/support-tickets/${Uri.encodeComponent(ticketId.trim())}/messages';

  /// `GET /user/notifications/unread-count` — inbox badge (excludes chat).
  static String get userNotificationsUnreadCount => '$baseUrl/user/notifications/unread-count';

  /// `GET /user/notifications` — paginated inbox.
  static String userNotificationsList({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (unreadOnly) params['unreadOnly'] = 'true';
    return '$baseUrl/user/notifications?${Uri(queryParameters: params).query}';
  }

  /// `PATCH /user/notifications/{notificationId}/read`
  static String userNotificationRead(String notificationId) =>
      '$baseUrl/user/notifications/${Uri.encodeComponent(notificationId.trim())}/read';

  /// `PATCH /user/notifications/read-all`
  static String get userNotificationsReadAll => '$baseUrl/user/notifications/read-all';
}
