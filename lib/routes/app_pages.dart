import 'package:get/get.dart';
import 'package:get_right/controllers/feed_publish_controller.dart';
import 'package:get_right/controllers/feed_video_upload_controller.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/views/auth/splash_screen.dart';
import 'package:get_right/views/auth/welcome_screen.dart';
import 'package:get_right/views/auth/onboarding_screen.dart';
import 'package:get_right/views/auth/login_screen.dart';
import 'package:get_right/views/auth/signup_screen.dart';
import 'package:get_right/views/auth/otp_screen.dart';
import 'package:get_right/views/auth/forgot_password_screen.dart';
import 'package:get_right/views/auth/reset_password_screen.dart';
import 'package:get_right/views/auth/profile_setup_screen.dart';
import 'package:get_right/views/auth/preference_selection_screen.dart';
import 'package:get_right/views/auth/goal_selection_screen.dart';
import 'package:get_right/views/auth/fitness_level_selection_screen.dart';
import 'package:get_right/views/auth/exercise_frequency_selection_screen.dart';
import 'package:get_right/views/auth/terms_conditions_screen.dart';
import 'package:get_right/views/auth/privacy_policy_screen.dart';
import 'package:get_right/views/home/home_screen.dart';
import 'package:get_right/views/home/dashboard_screen.dart';
import 'package:get_right/views/profile/profile_screen.dart';
import 'package:get_right/views/profile/personal_profile_screen.dart';
import 'package:get_right/views/profile/edit_profile_screen.dart';
import 'package:get_right/views/profile/followers_screen.dart';
import 'package:get_right/views/profile/following_screen.dart';
import 'package:get_right/views/journal/My_work_screen.dart';
import 'package:get_right/views/journal/workout_journal_screen.dart';
import 'package:get_right/views/journal/workout_timer_screen.dart';
import 'package:get_right/views/journal/add_workout_screen.dart';
import 'package:get_right/views/journal/add_exercise_screen.dart';
import 'package:get_right/views/journal/exercise_selection_screen.dart';
import 'package:get_right/views/journal/exercise_configuration_screen.dart';
import 'package:get_right/views/journal/exercise_library_detail_screen.dart';
import 'package:get_right/views/journal/add_notes_screen.dart';
import 'package:get_right/views/journal/video_walkthrough_screen.dart';
import 'package:get_right/views/journal/reorder_exercises_screen.dart';
import 'package:get_right/views/journal/log_run_screen.dart';
import 'package:get_right/views/journal/log_meal_screen.dart';
import 'package:get_right/views/journal/write_note_screen.dart';
import 'package:get_right/views/tracker/active_run_screen.dart';
import 'package:get_right/views/tracker/tracker_screen.dart';
import 'package:get_right/views/tracker/run_tracker_screen.dart';
import 'package:get_right/views/tracker/activity_type_selection_screen.dart';
import 'package:get_right/views/tracker/route_planning_screen.dart';
import 'package:get_right/views/tracker/run_summary_screen.dart';
import 'package:get_right/views/tracker/run_history_screen.dart';
import 'package:get_right/views/planner/planner_screen.dart';
import 'package:get_right/views/planner/create_plan_screen.dart';
import 'package:get_right/views/marketplace/marketplace_screen.dart';
import 'package:get_right/views/settings/settings_screen.dart';
import 'package:get_right/views/settings/change_password_screen.dart';
import 'package:get_right/views/settings/notifications_screen.dart';
import 'package:get_right/views/settings/help_feedback_screen.dart';
import 'package:get_right/views/settings/about_screen.dart';
import 'package:get_right/views/settings/blocked_users_screen.dart';
import 'package:get_right/views/settings/reports_screen.dart';
import 'package:get_right/views/chat/chat_list_screen.dart';
import 'package:get_right/views/chat/chat_room_screen.dart';
import 'package:get_right/views/tracker/progress_screen.dart';
import 'package:get_right/views/search/search_screen.dart';
import 'package:get_right/views/search/search_results_screen.dart';
import 'package:get_right/views/trainer/trainer_profile_screen.dart';
import 'package:get_right/views/trainer/trainer_reviews_screen.dart';
import 'package:get_right/views/marketplace/program_detail_screen.dart';
import 'package:get_right/views/marketplace/program_send_review_screen.dart';
import 'package:get_right/views/marketplace/purchase_details_screen.dart';
import 'package:get_right/views/marketplace/payment_form_screen.dart';
import 'package:get_right/views/marketplace/program_terms_screen.dart';
import 'package:get_right/views/marketplace/my_programs_screen.dart';
import 'package:get_right/views/marketplace/bundle_detail_screen.dart';
import 'package:get_right/views/marketplace/all_bundles_screen.dart';
import 'package:get_right/views/library/library_screen.dart';
import 'package:get_right/views/library/exercise_list_screen.dart';
import 'package:get_right/views/library/exercise_detail_screen.dart';
import 'package:get_right/views/feed/feed_screen.dart';
import 'package:get_right/views/feed/single_feed_reel_screen.dart';
import 'package:get_right/views/feed/post_detail_screen.dart';
import 'package:get_right/views/feed/create_post_screen.dart';
import 'package:get_right/views/feed/saved_posts_screen.dart';
import 'package:get_right/views/feed/saved_reels_screen.dart';
import 'package:get_right/views/feed/video_reel_screen.dart';
import 'package:get_right/views/trainer/all_programs_screen.dart';
import 'package:get_right/views/favorites/favorites_screen.dart';
import 'package:get_right/views/program_history/program_history_screen.dart';
import 'package:get_right/views/program_history/active_program_detail_screen.dart';
import 'package:get_right/views/program_history/completed_program_detail_screen.dart';
import 'package:get_right/views/program_history/program_modification_request_screen.dart';
import 'package:get_right/views/transaction_history/transaction_history_screen.dart';
import 'package:get_right/views/transaction_history/transaction_detail_screen.dart';
import 'package:get_right/views/nutrition/nutrition_screen.dart';

/// App Pages - GetX route configuration
class AppPages {
  AppPages._(); // Private constructor

  static const initial = AppRoutes.splash;

  static final routes = [
    // Auth Pages
    GetPage(name: AppRoutes.splash, page: () => const SplashScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.welcome, page: () => const WelcomeScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.onboarding, page: () => const OnboardingScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.login, page: () => const LoginScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.signup, page: () => const SignupScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.otp, page: () => const OtpScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.forgotPassword, page: () => const ForgotPasswordScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.resetPassword, page: () => const ResetPasswordScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.changePassword, page: () => const ChangePasswordScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.profileSetup, page: () => const ProfileSetupScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.preferenceSelection, page: () => const PreferenceSelectionScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.goalSelection, page: () => const GoalSelectionScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.fitnessLevelSelection, page: () => const FitnessLevelSelectionScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.exerciseFrequencySelection, page: () => const ExerciseFrequencySelectionScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.termsConditions, page: () => const TermsConditionsScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.privacyPolicy, page: () => const PrivacyPolicyScreen(), transition: Transition.rightToLeft),

    // Main App Pages
    GetPage(name: AppRoutes.home, page: () => const HomeScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.dashboard, page: () => const DashboardScreen(), transition: Transition.fade),

    // Profile Pages
    GetPage(name: AppRoutes.profile, page: () => const ProfileScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.personalProfile, page: () => const PersonalProfileScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.editProfile, page: () => const EditProfileScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.followers, page: () => const FollowersScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.following, page: () => const FollowingScreen(), transition: Transition.rightToLeft),

    // Journal Pages
    GetPage(name: AppRoutes.journal, page: () => const WorkoutScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.workoutJournal, page: () => const WorkoutJournalScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.workoutTimer, page: () => const WorkoutTimerScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.addWorkout, page: () => const AddWorkoutScreen(), transition: Transition.downToUp),
    GetPage(name: AppRoutes.addExercise, page: () => const AddExerciseScreen(), transition: Transition.downToUp),
    GetPage(name: AppRoutes.exerciseSelection, page: () => const ExerciseSelectionScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.exerciseConfiguration, page: () => const ExerciseConfigurationScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.exerciseLibraryDetail, page: () => const ExerciseLibraryDetailScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.addNotes, page: () => const AddNotesScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.videoWalkthrough, page: () => const VideoWalkthroughScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.reorderExercises, page: () => const ReorderExercisesScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.logRun, page: () => const LogRunScreen(), transition: Transition.downToUp),
    GetPage(name: AppRoutes.logMeal, page: () => const LogMealScreen(), transition: Transition.downToUp),
    GetPage(name: AppRoutes.writeNote, page: () => const WriteNoteScreen(), transition: Transition.downToUp),

    // Tracker Pages
    GetPage(name: AppRoutes.tracker, page: () => const TrackerScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.runTracker, page: () => const RunTrackerScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.runTracking, page: () => const ActiveRunScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.runHistory, page: () => const RunHistoryScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.runDetail, page: () => const RunSummaryScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.progress, page: () => const ProgressScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.routePlanning, page: () => const RoutePlanningScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.activityTypeSelection, page: () => const ActivityTypeSelectionScreen(), transition: Transition.rightToLeft),

    // Planner Pages
    GetPage(name: AppRoutes.planner, page: () => const PlannerScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.createPlan, page: () => const CreatePlanScreen(), transition: Transition.downToUp),

    // Marketplace Pages
    GetPage(name: AppRoutes.marketplace, page: () => const MarketplaceScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.programDetail, page: () => const ProgramDetailScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.programSendReview, page: () => const ProgramSendReviewScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.purchaseDetails, page: () => const PurchaseDetailsScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.paymentForm, page: () => const PaymentFormScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.programTerms, page: () => const ProgramTermsScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.myPrograms, page: () => const MyProgramsScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.favorites, page: () => const FavoritesScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.trainerProfile, page: () => const TrainerProfileScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.trainerReviews, page: () => const TrainerReviewsScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.programHistory, page: () => const ProgramHistoryScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.activeProgramDetail, page: () => const ActiveProgramDetailScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.completedProgramDetail, page: () => const CompletedProgramDetailScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.programModificationRequest, page: () => const ProgramModificationRequestScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.transactionHistory, page: () => TransactionHistoryScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.transactionDetail, page: () => const TransactionDetailScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.bundleDetail, page: () => const BundleDetailScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.allBundles, page: () => const AllBundlesScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.trainerAllPrograms, page: () => const AllProgramsScreen(), transition: Transition.rightToLeft),

    // Library Pages
    GetPage(name: AppRoutes.library, page: () => const LibraryScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.exerciseList, page: () => const ExerciseListScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.exerciseDetail, page: () => const ExerciseDetailScreen(), transition: Transition.rightToLeft),

    // Feed Pages
    GetPage(name: AppRoutes.feed, page: () => const FeedScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.feedSingleReel, page: () => const SingleFeedReelScreen(), transition: Transition.fade),
    GetPage(name: AppRoutes.postDetail, page: () => const PostDetailScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.savedPosts, page: () => const SavedPostsScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.savedReels, page: () => const SavedReelsScreen(), transition: Transition.rightToLeft),
    GetPage(
      name: AppRoutes.createPost,
      page: () => const CreatePostScreen(),
      binding: BindingsBuilder(() {
        Get.lazyPut<FeedVideoUploadController>(() => FeedVideoUploadController());
        Get.lazyPut<FeedPublishController>(() => FeedPublishController());
      }),
      transition: Transition.downToUp,
    ),
    GetPage(name: AppRoutes.videoReel, page: () => const VideoReelScreen(), transition: Transition.fade),

    // Search Pages
    GetPage(name: AppRoutes.search, page: () => SearchScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.searchResults, page: () => const SearchResultsScreen(), transition: Transition.rightToLeft),

    // Chat Pages
    GetPage(name: AppRoutes.chatList, page: () => const ChatListScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.chatRoom, page: () => const ChatRoomScreen(), transition: Transition.rightToLeft),

    // Nutrition Pages
    GetPage(name: AppRoutes.nutrition, page: () => const NutritionScreen(), transition: Transition.rightToLeft),
    // Note: Recipe detail and add food are typically navigated to directly with Get.to() passing parameters

    // Settings Pages
    GetPage(name: AppRoutes.settings, page: () => const SettingsScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.notifications, page: () => const NotificationsScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.blockedUsers, page: () => const BlockedUsersScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.reports, page: () => const ReportsScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.helpFeedback, page: () => const HelpFeedbackScreen(), transition: Transition.rightToLeft),
    GetPage(name: AppRoutes.about, page: () => const AboutScreen(), transition: Transition.rightToLeft),
    // GetPage(name: AppRoutes.createTrainerProfile, page: () => const CreateTrainerProfileScreen(), transition: Transition.rightToLeft),
  ];
}
