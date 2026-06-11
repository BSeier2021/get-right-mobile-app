import 'package:get_right/utils/customer_profile_enums.dart';

/// App-wide constants for Get Right
class AppConstants {
  AppConstants._(); // Private constructor

  // App Info
  static const String appName = 'Get Right';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Your fitness journey starts here';

  // API Configuration (Update with your backend URLs)
  static const String baseUrl =
      'https://api.getright.app'; // TODO: Update with actual API
  static const String apiVersion = 'v1';

  // Storage Keys
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserId = 'user_id';
  static const String keyUserToken = 'user_token';
  static const String keyUserEmail = 'user_email';
  static const String keyUserName = 'user_name';
  static const String keyUserPhotoUrl = 'user_photo_url';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyUserPreference = 'user_preference';
  static const String keyUserGoals = 'user_goals';
  static const String keyFitnessLevel = 'fitness_level';
  static const String keyExerciseFrequency = 'exercise_frequency';
  static const String keySavedPosts = 'saved_posts';
  static const String keyLikedFeedPostIds = 'liked_feed_post_ids';
  static const String keyHasSubscription = 'has_subscription';
  static const String keySubscriptionExpiryDate = 'subscription_expiry_date';
  static const String keySubscriptionType =
      'subscription_type'; // 'monthly', 'quarterly', 'yearly'

  // Workout Tags
  static const List<String> workoutTags = [
    'Leg Day',
    'Upper Body',
    'Arms',
    'Chest',
    'Back',
    'Shoulders',
    'Core',
    'Cardio',
    'HIIT',
    'Yoga',
    'Stretching',
    'Full Body',
  ];

  // Fitness Goals
  static const List<String> fitnessGoals = [
    'Weight Loss',
    'Muscle Gain',
    'Endurance',
    'Strength',
    'Flexibility',
    'General Fitness',
    'Athletic Performance',
  ];

  // Workout Types
  static const List<String> workoutTypes = [
    'Cardio',
    'Strength Training',
    'Yoga',
    'HIIT',
    'Pilates',
    'Crossfit',
    'Running',
    'Cycling',
    'Swimming',
    'Sports',
  ];

  // Gender — API values (`Male`, `Female`, `Other`, `PreferNotToSay`). Use [GenderEnums.displayForApi] for labels.
  static const List<String> genderOptions = GenderEnums.apiValues;

  // Activity Levels
  static const List<String> activityLevels = [
    'Sedentary',
    'Lightly Active',
    'Moderately Active',
    'Very Active',
    'Extremely Active',
  ];

  // Units
  static const List<String> unitsOptions = ['Metric', 'Imperial'];

  // Validation
  static const int minPasswordLength = 8;
  static const int otpLength = 6;
  static const int otpResendTimeSeconds = 60;

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 50;

  // Image
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png'];

  // GPS Tracking
  static const double defaultLatitude = 37.7749; // San Francisco (default)
  static const double defaultLongitude = -122.4194;
  static const double minDistanceFilterMeters = 10.0;

  // Time Formats
  static const String timeFormat12Hour = 'hh:mm a';
  static const String timeFormat24Hour = 'HH:mm';
  static const String dateFormat = 'MMM dd, yyyy';
  static const String dateTimeFormat = 'MMM dd, yyyy hh:mm a';

  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Snackbar Duration
  static const Duration snackbarDuration = Duration(seconds: 3);

  // Commission
  static const double platformCommissionPercentage = 15.0; // 15% platform fee

  // Chat
  static const int maxChatMessageLength = 1000;
  static const int maxChatFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxChatImageAttachments = 10;
}
