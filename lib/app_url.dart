class AppUrl {
  // development url
  static const String baseUrl = 'https://rampantly-proemial-antonietta.ngrok-free.dev/api/v1';
  static const String imnageUrl = 'https://rampantly-proemial-antonietta.ngrok-free.dev/';
  // static const String socketUrl = 'http://api.voicecast.thesuitchstaging2.com:4627';

  static String signUp = '$baseUrl/user/auth/signup';
  static String verifyOTP = '$baseUrl/user/auth/verify-otp';

  /// POST body: `{ "email": "..." }` — resend signup / verification OTP.
  static String sendOtp = '$baseUrl/user/auth/send-otp';

  /// `POST` multipart — fields: fullName, dateofbirth, gender, phoneNumber; file: profilePicture.
  static String createProfile = '$baseUrl/customer/profile/create';
  /// `POST /user/auth/login` — body: email, password, deviceType, deviceToken.
  static String signIn = '$baseUrl/user/auth/login';
  static String forgotPassword = '$baseUrl/user/auth/resend-otp';
  static String resetPassword = '$baseUrl/user/auth/forgot-passowrd-reset';
  static String preference = '$baseUrl/user/preferences';
  static String goals = '$baseUrl/user/goals';
  static String updateProfile = '$baseUrl/customer/profile/update';
  static String getProfile = '$baseUrl/customer/profile';
  static String exerciseCategories = '$baseUrl/user/exercise-categories';
  static String exerciseCategory(String categoryId) => '$baseUrl/user/exercises/category/$categoryId';
  static String exerciseDetail(String exerciseId) => '$baseUrl/user/exercises/$exerciseId';

  // static String fitnessLevels = '$baseUrl/get-all-fitnesses';
  // static String AllPlans = '$baseUrl/get-all-plans';
  static String autoLogin = '$baseUrl/auth/auto-login';
  static String changePassword = '$baseUrl/user/auth/change-password';
  static String voicePosts = '$baseUrl/voice-posts';
  static String createVoicePost = '$baseUrl/voice-posts';

  /////////logout API//
  static String logout = '$baseUrl/auth/logout';
}
