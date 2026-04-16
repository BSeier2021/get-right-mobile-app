import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:get_right/Local%20Storage/local_storage.dart';
import 'package:get_right/repo/auth_repo.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/network/network_services.dart';

/// Auth controller: signup, OTP, and login flows (signup uses live API).
class AuthController extends GetxController {
  static const _deviceTokenStorageKey = 'app_install_device_token';

  final StorageService _storageService;
  final AuthRepository _authRepo = AuthRepository();

  AuthController(this._storageService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _tempEmail;
  String? _pendingSignupUserId;

  /// Set after successful signup; pass to OTP route for verify-OTP API.
  String? get pendingSignupUserId => _pendingSignupUserId;

  String _deviceTypeLabel() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  Future<String> _ensureDeviceToken() async {
    var token = _storageService.getString(_deviceTokenStorageKey);
    if (token == null || token.isEmpty) {
      token = 'getright-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(0x7fffffff)}';
      await _storageService.saveString(_deviceTokenStorageKey, token);
    }
    return token;
  }

  void _snackError(String title, Object e) {
    final msg = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
    Get.snackbar(title, msg, snackPosition: SnackPosition.BOTTOM);
  }

  /// SharedPreferences + GetStorage token so [NetworkApiService] sends `Bearer` on API calls.
  Future<void> _persistAccessToken(String token) async {
    await _storageService.saveToken(token);
    await _storageService.saveLoginStatus(true);
    Get.put(LocalStorage()).saveAccessToken(token);
  }

  // Note: Removed onInit auto-navigation - Splash screen handles initial routing

  /// Check if onboarding has been completed
  bool isOnboardingComplete() {
    return _storageService.isOnboardingComplete();
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    await _storageService.completeOnboarding();
  }

  /// Check if user is logged in
  bool isLoggedIn() {
    return _storageService.isLoggedIn();
  }

  /// Login via `POST /user/auth/login` with email, password, deviceType, deviceToken.
  Future<void> login({required String email, required String password}) async {
    try {
      _isLoading = true;
      update();

      final deviceToken = await _ensureDeviceToken();
      final response = await _authRepo.loginRepo(
        email: email,
        password: password,
        deviceType: _deviceTypeLabel(),
        deviceToken: deviceToken,
      );

      if (response is! Map<String, dynamic>) {
        _snackError('Login', 'Unexpected response from server');
        return;
      }

      if (response['success'] != true) {
        final message = response['message']?.toString() ?? 'Login failed';
        _snackError('Login', message);
        return;
      }

      final token = _tokenFromVerifyResponse(response);
      if (token == null || token.isEmpty) {
        _snackError('Login', 'No access token in response');
        return;
      }
      await _persistAccessToken(token);

      final data = response['data'];
      String? emailToStore;
      if (data is Map<String, dynamic>) {
        final user = data['user'];
        if (user is Map<String, dynamic>) {
          final id = user['_id']?.toString();
          if (id != null && id.isNotEmpty) {
            await _storageService.saveUserId(id);
            Get.put(LocalStorage()).saveuserid(id);
          }
          emailToStore = user['email']?.toString();
          final profile = user['profile'];
          if (profile is Map<String, dynamic>) {
            final name = profile['fullName']?.toString();
            if (name != null && name.isNotEmpty) {
              await _storageService.saveName(name);
            }
          }
        }
      }
      final resolvedEmail = emailToStore?.trim();
      await _storageService.saveEmail((resolvedEmail != null && resolvedEmail.isNotEmpty) ? resolvedEmail : email);

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Welcome', message, snackPosition: SnackPosition.BOTTOM);
      }

      Get.offAllNamed(AppRoutes.home);
    } on BadRequestException catch (e) {
      _snackError('Login', e.message);
    } on UnauthorizedException catch (e) {
      _snackError('Login', e.message);
    } on ForbiddenException catch (e) {
      _snackError('Login', e.message);
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
    } on RequestTimeoutException catch (e) {
      _snackError('Login', e.message);
    } on ServerException catch (e) {
      _snackError('Login', e.message);
    } catch (e) {
      _snackError('Login', e);
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Signup via `/user/auth/signup`. On success, OTP is sent to email; stores user id for verify-OTP.
  Future<bool> signup({required String email, required String password, String role = 'Customer'}) async {
    try {
      _isLoading = true;
      update();

      final deviceToken = await _ensureDeviceToken();
      final response = await _authRepo.signUp(email: email, password: password, deviceType: _deviceTypeLabel(), deviceToken: deviceToken, role: role);

      if (response is! Map<String, dynamic>) {
        _snackError('Sign up', 'Unexpected response from server');
        return false;
      }

      final success = response['success'] == true;
      if (!success) {
        final message = response['message']?.toString() ?? 'Sign up failed';
        _snackError('Sign up', message);
        return false;
      }

      final data = response['data'];
      final user = data is Map<String, dynamic> ? data['user'] : null;
      final userId = user is Map<String, dynamic> ? user['_id']?.toString() : null;

      _tempEmail = email;
      _pendingSignupUserId = userId;

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      }

      return true;
    } on BadRequestException catch (e) {
      _snackError('Sign up', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Sign up', e.message);
      return false;
    } on ConflictException catch (e) {
      _snackError('Sign up', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Sign up', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Sign up', e.message);
      return false;
    } catch (e) {
      _snackError('Sign up', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  String? _tokenFromVerifyResponse(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      for (final key in ['token', 'accessToken', 'access_token', 'authToken']) {
        final v = data[key];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      final user = data['user'];
      if (user is Map<String, dynamic>) {
        for (final key in ['token', 'accessToken']) {
          final v = user[key];
          if (v != null && v.toString().isNotEmpty) return v.toString();
        }
      }
    }
    for (final key in ['token', 'accessToken', 'access_token']) {
      final v = json[key];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  /// Verify OTP via `/user/auth/verify-otp` with `userId` + `otp`. On success, persists token/user id when present, then opens profile setup.
  Future<bool> verifyOTP({required String userId, required String otp}) async {
    try {
      _isLoading = true;
      update();

      final response = await _authRepo.verifyOTPRepo(userId: userId, otp: otp);

      if (response is! Map<String, dynamic>) {
        _snackError('Verification', 'Unexpected response from server');
        return false;
      }

      final success = response['success'] == true;
      if (!success) {
        final message = response['message']?.toString() ?? 'Verification failed';
        _snackError('Verification', message);
        return false;
      }

      final token = _tokenFromVerifyResponse(response);
      if (token != null && token.isNotEmpty) {
        await _persistAccessToken(token);
      }

      await _storageService.saveUserId(userId);
      if (_tempEmail != null) {
        await _storageService.saveEmail(_tempEmail!);
      }

      final data = response['data'];
      final user = data is Map<String, dynamic> ? data['user'] : null;
      if (user is Map<String, dynamic>) {
        final id = user['_id']?.toString();
        if (id != null && id.isNotEmpty) {
          await _storageService.saveUserId(id);
        }
        final email = user['email']?.toString();
        if (email != null && email.isNotEmpty) {
          await _storageService.saveEmail(email);
        }
      }

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Verified', message, snackPosition: SnackPosition.BOTTOM);
      }

      _tempEmail = null;
      _pendingSignupUserId = null;

      Get.offNamed(AppRoutes.profileSetup);
      return true;
    } on BadRequestException catch (e) {
      _snackError('Verification', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Verification', e.message);
      return false;
    } on ConflictException catch (e) {
      _snackError('Verification', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Verification', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Verification', e.message);
      return false;
    } catch (e) {
      _snackError('Verification', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Resend OTP via `POST /user/auth/send-otp` with `{ "email": "..." }`.
  /// Pass [email] from the OTP screen when available; otherwise uses email from signup (`_tempEmail`).
  Future<void> resendOTP({String? email}) async {
    try {
      _isLoading = true;
      update();

      final resolved = (email != null && email.trim().isNotEmpty) ? email.trim() : _tempEmail;
      if (resolved == null || resolved.isEmpty) {
        Get.snackbar('Resend OTP', 'No email found. Go back and sign up again.', snackPosition: SnackPosition.BOTTOM);
        Get.offAllNamed(AppRoutes.signup);
        return;
      }

      final response = await _authRepo.sendOtpRepo(email: resolved);
      if (response is! Map<String, dynamic>) {
        _snackError('Resend OTP', 'Unexpected response from server');
        return;
      }

      if (response['success'] == true) {
        final message = response['message']?.toString() ?? 'OTP sent';
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      } else {
        final message = response['message']?.toString() ?? 'Could not resend code';
        _snackError('Resend OTP', message);
      }
    } on BadRequestException catch (e) {
      _snackError('Resend OTP', e.message);
    } on UnauthorizedException catch (e) {
      _snackError('Resend OTP', e.message);
    } on ConflictException catch (e) {
      _snackError('Resend OTP', e.message);
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
    } on RequestTimeoutException catch (e) {
      _snackError('Resend OTP', e.message);
    } on ServerException catch (e) {
      _snackError('Resend OTP', e.message);
    } catch (e) {
      _snackError('Resend OTP', e);
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Create customer profile — `POST /customer/profile/create` (multipart). Saves returned token and user ids.
  Future<bool> createProfile({
    required String fullName,
    required String dateofbirth,
    required String gender,
    required String phoneNumber,
    File? profilePicture,
  }) async {
    try {
      _isLoading = true;
      update();

      final response = await _authRepo.createProfileRepo(
        fullName: fullName,
        dateofbirth: dateofbirth,
        gender: gender,
        phoneNumber: phoneNumber,
        profilePicture: profilePicture,
      );

      if (response is! Map<String, dynamic>) {
        _snackError('Profile', 'Unexpected response from server');
        return false;
      }

      if (response['success'] != true) {
        final message = response['message']?.toString() ?? 'Could not create profile';
        _snackError('Profile', message);
        return false;
      }

      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final token = data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await _persistAccessToken(token);
        }

        final user = data['user'];
        if (user is Map<String, dynamic>) {
          final id = user['_id']?.toString();
          if (id != null && id.isNotEmpty) {
            await _storageService.saveUserId(id);
          }
          final email = user['email']?.toString();
          if (email != null && email.isNotEmpty) {
            await _storageService.saveEmail(email);
          }
          final profile = user['profile'];
          if (profile is Map<String, dynamic>) {
            final name = profile['fullName']?.toString();
            if (name != null && name.isNotEmpty) {
              await _storageService.saveName(name);
            }
          }
        }
      }

      final message = response['message']?.toString();
      if (message != null && message.isNotEmpty) {
        Get.snackbar('Success', message, snackPosition: SnackPosition.BOTTOM);
      }

      Get.offNamed(AppRoutes.preferenceSelection);
      return true;
    } on BadRequestException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on ForbiddenException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on NoInternetException catch (e) {
      _snackError('No connection', e.message);
      return false;
    } on RequestTimeoutException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } on ServerException catch (e) {
      _snackError('Profile', e.message);
      return false;
    } catch (e) {
      _snackError('Profile', e);
      return false;
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Forgot password - send reset code - DEMO VERSION
  Future<void> forgotPassword(String email) async {
    try {
      _isLoading = true;
      update();

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      _tempEmail = email; // Store email for reset password step
    } catch (e) {
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Reset password - DEMO VERSION
  Future<void> resetPassword({required String otp, required String newPassword}) async {
    try {
      _isLoading = true;
      update();

      if (_tempEmail == null) {
        Get.offAllNamed(AppRoutes.forgotPassword);
        return;
      }

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      _tempEmail = null; // Clear temp email
      Get.offAllNamed(AppRoutes.login);
    } catch (e) {
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Change password from settings - DEMO VERSION
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    try {
      _isLoading = true;
      update();

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));
    } catch (e) {
    } finally {
      _isLoading = false;
      update();
    }
  }

  /// Logout
  Future<void> logout() async {
    await _storageService.logout();
    Get.offAllNamed(AppRoutes.login);
  }

  /// Sign in with Apple - DEMO VERSION
  /// Works for both login and signup (Apple handles both cases)
  Future<void> signInWithApple() async {
    try {
      // Check if Apple Sign-In is available (iOS 13+ or macOS 10.15+)
      if (!Platform.isIOS && !Platform.isMacOS) {
        Get.snackbar('Not Available', 'Apple Sign-In is only available on iOS and macOS devices', snackPosition: SnackPosition.BOTTOM);
        return;
      }

      _isLoading = true;
      update();

      // Check if Apple Sign-In is available
      final isAvailable = await SignInWithApple.isAvailable();
      if (!isAvailable) {
        _isLoading = false;
        update();
        Get.snackbar('Not Available', 'Apple Sign-In is not available on this device', snackPosition: SnackPosition.BOTTOM);
        return;
      }

      // Request Apple Sign-In
      final credential = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName]);

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 1));

      // Extract user information
      final email = credential.email ?? credential.userIdentifier;
      final firstName = credential.givenName ?? '';
      final lastName = credential.familyName ?? '';
      final displayName = '${firstName} ${lastName}'.trim();
      final userName = displayName.isNotEmpty ? displayName : 'Apple User';

      // Save demo user data locally
      await _storageService.saveToken('apple_token_${DateTime.now().millisecondsSinceEpoch}');
      await _storageService.saveUserId('apple_user_${credential.userIdentifier}');
      await _storageService.saveEmail(email ?? 'apple_user@example.com');
      await _storageService.saveName(userName);
      await _storageService.saveLoginStatus(true);

      _isLoading = false;
      update();

      // Navigate to home
      Get.offAllNamed(AppRoutes.home);
    } on SignInWithAppleAuthorizationException catch (e) {
      _isLoading = false;
      update();

      // Handle user cancellation
      if (e.code == AuthorizationErrorCode.canceled) {
        // User canceled, do nothing
        return;
      }

      // Handle other errors
      Get.snackbar('Sign-In Failed', e.message.isNotEmpty ? e.message : 'An error occurred during Apple Sign-In', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      _isLoading = false;
      update();
      Get.snackbar('Error', 'Failed to sign in with Apple: ${e.toString()}', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
