/// Local demo credentials. Matching these never hits Render / SendGrid.
class WalkthroughAuth {
  WalkthroughAuth._();

  static const String email = 'walkthrough@getright.app';
  static const String password = 'Walkthrough123!';
  static const String otp = '123456';
  static const String userId = 'walkthrough-local';
  static const String token = 'walkthrough-local-token';
  static const String name = 'Walkthrough Tester';

  static String normalizeEmail(String? value) => value?.trim().toLowerCase() ?? '';

  static bool matchesEmail(String? value) => normalizeEmail(value) == email;

  static bool matchesPassword(String? value) => value == password;

  static bool matchesCredentials(String emailValue, String passwordValue) {
    return matchesEmail(emailValue) && matchesPassword(passwordValue);
  }

  static bool matchesOtp(String? value) => value?.trim() == otp;

  static bool matchesUserId(String? value) => value?.trim() == userId;
}
