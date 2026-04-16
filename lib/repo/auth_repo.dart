import 'dart:io';

import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';

class AuthRepository {
  final _network = NetworkApiService();

  Future<dynamic> signUp({required String email, required String password, required String deviceType, required String deviceToken, String role = 'Customer'}) async {
    final response = await _network.post(
      AppUrl.signUp,
      {"email": email, "password": password, "deviceType": deviceType, "deviceToken": deviceToken, "role": role},
      headers: {"Authorization": "yNaHwJpGFSquIkXP"},
    );
    return response;
  }

  Future<dynamic> verifyOTPRepo({required String userId, required String otp}) async {
    final response = await _network.post(AppUrl.verifyOTP, {"userId": userId, "otp": otp}, headers: {"Authorization": "yNaHwJpGFSquIkXP"});
    return response;
  }

  /// `POST /user/auth/send-otp` with `{ "email": "user@example.com" }`.
  Future<dynamic> sendOtpRepo({required String email}) async {
    final response = await _network.post(AppUrl.sendOtp, {"email": email.trim()}, headers: {"Authorization": "yNaHwJpGFSquIkXP"});
    return response;
  }

  /// `POST /customer/profile/create` — multipart form: fullName, dateofbirth, gender, phoneNumber, optional profilePicture (file).
  Future<dynamic> createProfileRepo({required String fullName, required String dateofbirth, required String gender, required String phoneNumber, File? profilePicture}) async {
    final fields = <String, dynamic>{'fullName': fullName.trim(), 'dateofbirth': dateofbirth, 'gender': gender, 'phoneNumber': phoneNumber.trim()};
    final files = <String, List<File>>{};
    if (profilePicture != null && profilePicture.path.isNotEmpty && await profilePicture.exists()) {
      files['profilePicture'] = [profilePicture];
    }
    return _network.postMultipart(url: AppUrl.createProfile, fields: fields, files: files);
  }

  Future<dynamic> loginRepo({required String email, required String password, required String deviceType, required String deviceToken}) async {
    final response = await _network.post(
      AppUrl.signIn,
      {"email": email.trim(), "password": password, "deviceType": deviceType, "deviceToken": deviceToken},
      headers: {"Authorization": "yNaHwJpGFSquIkXP"},
    );
    return response;
  }

  Future<dynamic> forgotPasswordRepo({required String email}) async {
    final response = await _network.post(AppUrl.forgotPassword, {"email": email});
    return response;
  }

  Future<dynamic> resetPasswordRepo({required String password, required String userId}) async {
    final response = await _network.post(AppUrl.resetPassword, {"password": password, "userId": userId});
    return response;
  }

  Future<dynamic> getPreferencesRepo() async {
    final response = await _network.get(headers: {"Authorization": "yNaHwJpGFSquIkXP"}, AppUrl.preference);
    return response;
  }

  Future<dynamic> getGoalsRepo() async {
    final response = await _network.get(headers: {"Authorization": "yNaHwJpGFSquIkXP"}, AppUrl.goals);
    return response;
  }

  // Future<dynamic> getFitnessLevelsRepo() async {
  //   final response = await _network.get(AppUrl.fitnessLevels);
  //   return response;
  // }

  // Future<dynamic> getAllPlansRepo() async {
  //   final response = await _network.get(AppUrl.AllPlans);
  //   return response;
  // }

  Future<dynamic> updateProfileRepo({
    String? fullName,
    String? dob,
    String? gender,
    String? phone,
    String? bio,
    String? preferenceId,
    List<String>? goalIds,
    String? fitnessLevelId,
    String? exercisePlanId,
    String? avatar,
  }) async {
    // Create a clean Map<String, dynamic> to ensure proper JSON encoding
    final Map<String, dynamic> fields = {};

    // Add personal information fields
    if (fullName != null && fullName.trim().isNotEmpty) {
      fields['fullName'] = fullName.trim();
    }

    if (dob != null && dob.trim().isNotEmpty) {
      fields['dob'] = dob.trim();
    }

    if (gender != null && gender.trim().isNotEmpty) {
      fields['gender'] = gender.trim();
    }

    if (phone != null && phone.trim().isNotEmpty) {
      fields['phone'] = phone.trim();
    }

    if (bio != null && bio.trim().isNotEmpty) {
      fields['bio'] = bio.trim();
    }

    // Add onboarding preference fields
    if (preferenceId != null && preferenceId.trim().isNotEmpty) {
      fields['preferences'] = preferenceId.trim(); // Note: API uses typo "prefernce"
    }

    if (goalIds != null && goalIds.isNotEmpty) {
      // API expects goals as an array
      // Filter out any empty strings
      final validGoalIds = goalIds.where((id) => id.trim().isNotEmpty).map((id) => id.trim()).toList();
      if (validGoalIds.isNotEmpty) {
        fields['goals'] = validGoalIds; // Keep as array, API expects array
      }
    }

    if (fitnessLevelId != null && fitnessLevelId.trim().isNotEmpty) {
      fields['fitnessLevel'] = fitnessLevelId.trim();
    }

    if (exercisePlanId != null && exercisePlanId.trim().isNotEmpty) {
      fields['exerciseFrequency'] = exercisePlanId.trim(); // Note: API uses typo "excercisePlan"
    }

    // Ensure body is not empty before making the request
    if (fields.isEmpty && avatar == null) {
      throw Exception('No valid data to update');
    }

    // If avatar is provided, use multipart request
    if (avatar != null && avatar.trim().isNotEmpty) {
      final file = File(avatar);
      if (await file.exists()) {
        // Prepare multipart fields - convert goals array to goals[] format for proper expansion
        final multipartFields = <String, dynamic>{};
        fields.forEach((key, value) {
          if (key == 'goals' && value is List) {
            // Use goals[] format so network service expands it as goals[0], goals[1], etc.
            multipartFields['goals[]'] = value;
          } else {
            multipartFields[key] = value;
          }
        });

        final files = <String, List<File>>{
          'avatar': [file],
        };

        // Log the final request body for debugging
        print('Final Update Profile Request (Multipart) - Fields: $multipartFields');
        print('Avatar file: ${file.path}');

        final response = await _network.postMultipart(url: AppUrl.updateProfile, fields: multipartFields, files: files);
        return response;
      } else {
        throw Exception('Avatar file does not exist');
      }
    }

    // Log the final request body for debugging
    print('Final Update Profile Request Body: $fields');
    print('Goals type: ${fields['goals']?.runtimeType}');
    print('Goals value: ${fields['goals']}');

    final response = await _network.post(AppUrl.updateProfile, fields);
    return response;
  }

  Future<dynamic> getProfileRepo() async {
    final response = await _network.get(AppUrl.getProfile);
    return response;
  }

  Future<dynamic> changePasswordRepo({required String oldPassword, required String newPassword}) async {
    final response = await _network.post(AppUrl.changePassword, {"oldPassword": oldPassword, "newPassword": newPassword});
    return response;
  }

  Future<dynamic> getExerciseCategoriesRepo() async {
    final response = await _network.get(headers: {"Authorization": "yNaHwJpGFSquIkXP"}, AppUrl.exerciseCategories);
    return response;
  }

  Future<dynamic> getExercisesByCategoryRepo(String categoryId) async {
    final response = await _network.get(headers: {"Authorization": "yNaHwJpGFSquIkXP"}, AppUrl.exerciseCategory(categoryId));
    return response;
  }
}
