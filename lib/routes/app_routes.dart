/// Route names for navigation
class AppRoutes {
  AppRoutes._();

  // Auth Routes
  static const String splash = '/splash';
  static const String welcome = '/welcome';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String otp = '/otp';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String changePassword = '/change-password';
  static const String profileSetup = '/profile-setup';
  static const String preferenceSelection = '/preference-selection';
  static const String goalSelection = '/goal-selection';
  static const String fitnessLevelSelection = '/fitness-level-selection';
  static const String exerciseFrequencySelection = '/exercise-frequency-selection';

  // Main App Routes
  static const String home = '/home';
  static const String dashboard = '/dashboard';

  // Profile Routes
  static const String profile = '/profile';
  static const String personalProfile = '/personal-profile';
  static const String editProfile = '/edit-profile';
  static const String createProfile = '/create-profile';
  static const String followers = '/followers';
  static const String following = '/following';

  // Journal Routes
  static const String journal = '/journal';
  static const String workoutJournal = '/workout-journal';
  static const String addWorkout = '/add-workout';
  static const String addExercise = '/add-exercise';
  static const String exerciseSelection = '/exercise-selection';
  static const String exerciseConfiguration = '/exercise-configuration';
  static const String addNotes = '/add-notes';
  static const String videoWalkthrough = '/video-walkthrough';
  static const String reorderExercises = '/reorder-exercises';
  static const String editWorkout = '/edit-workout';
  static const String workoutDetail = '/workout-detail';
  static const String workoutTimer = '/workout-timer';
  static const String logRun = '/log-run';
  static const String logMeal = '/log-meal';
  static const String writeNote = '/write-note';

  // Tracker Routes
  static const String tracker = '/tracker';
  static const String calendar = '/calendar';
  static const String progress = '/progress';
  static const String runTracker = '/run-tracker';
  static const String runTracking = '/run-tracking';
  static const String runHistory = '/run-history';
  static const String runDetail = '/run-detail';
  static const String routePlanning = '/route-planning';
  static const String activityTypeSelection = '/activity-type-selection';

  // Planner Routes
  static const String planner = '/planner';
  static const String createPlan = '/create-plan';
  static const String editPlan = '/edit-plan';
  static const String planDetail = '/plan-detail';
  static const String templates = '/templates';

  // Marketplace Routes
  static const String marketplace = '/marketplace';
  static const String programDetail = '/program-detail';
  static const String programSendReview = '/program-send-review';
  static const String programEnrollment = '/program-enrollment';
  static const String purchaseDetails = '/purchase-details';
  static const String paymentForm = '/payment-form';
  static const String programTerms = '/program-terms';
  static const String trainerProfile = '/trainer-profile';
  static const String trainerReviews = '/trainer-reviews';
  static const String myPrograms = '/my-programs';
  static const String favorites = '/favorites';
  static const String checkout = '/checkout';
  static const String programHistory = '/program-history';
  static const String activeProgramDetail = '/active-program-detail';
  static const String completedProgramDetail = '/completed-program-detail';
  static const String programModificationRequest = '/program-modification-request';
  static const String transactionHistory = '/transaction-history';
  static const String transactionDetail = '/transaction-detail';
  static const String bundleDetail = '/bundle-detail';
  static const String bundleEnrollment = '/bundle-enrollment';
  static const String allBundles = '/all-bundles';
  static const String trainerAllPrograms = '/trainer-all-programs';

  // Library Routes
  static const String library = '/library';
  static const String exerciseList = '/exercise-list';
  static const String exerciseDetail = '/exercise-detail';

  // Feed Routes
  static const String feed = '/feed';
  static const String createPost = '/create-post';
  static const String postDetail = '/post-detail';
  static const String savedPosts = '/saved-posts';
  /// Server-backed saved reels (`GET /user/feed/save`).
  static const String savedReels = '/saved-reels';
  static const String videoReel = '/video-reel';
  /// One reel fetched by id (same UX as feed tab reels).
  static const String feedSingleReel = '/feed/single-reel';

  // Search Routes
  static const String search = '/search';
  static const String searchResults = '/search-results';

  // Chat Routes
  static const String chatList = '/chat-list';
  static const String chatRoom = '/chat-room';

  // Nutrition Routes
  static const String nutrition = '/nutrition';
  static const String recipeDetail = '/recipe-detail';
  static const String addFood = '/add-food';

  // Settings Routes
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String blockedUsers = '/blocked-users';
  static const String reports = '/reports';
  static const String helpFeedback = '/help-feedback';
  static const String termsConditions = '/terms-conditions';
  static const String privacyPolicy = '/privacy-policy';
  static const String about = '/about';
  static const String discover = '/discover';
  static const String supportTickets = '/support-tickets';
  static const String createSupportTicket = '/support-tickets/create';
  static const String supportTicketDetail = '/support-ticket-detail';
  static const String createTrainerProfile = '/create-trainer-profile';
}
