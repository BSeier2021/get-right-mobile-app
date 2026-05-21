import 'package:get_right/app_url.dart';
import 'package:get_right/constants/app_constants.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/services/storage_service.dart';

/// API Service for backend communication
///
/// Note: This is a template. Update with actual HTTP client (dio/http package)
/// and implement real API endpoints when backend is ready.
class ApiService {
  static ApiService? _instance;
  final StorageService _storage; // Used for auth token in real API calls

  ApiService._(this._storage);

  /// Get singleton instance
  static Future<ApiService> getInstance() async {
    if (_instance == null) {
      final storage = await StorageService.getInstance();
      _instance = ApiService._(storage);
    }
    return _instance!;
  }

  /// Get base URL
  String get baseUrl => '${AppConstants.baseUrl}/${AppConstants.apiVersion}';

  // ========== AUTH ENDPOINTS ==========

  /// Login
  Future<Map<String, dynamic>> login({required String email, required String password}) async {
    // TODO: Implement actual API call
    // Example:
    // final response = await http.post(
    //   Uri.parse('$baseUrl/auth/login'),
    //   headers: _headers,
    //   body: jsonEncode({'email': email, 'password': password}),
    // );

    // Mock response for development
    await Future.delayed(const Duration(seconds: 1));
    return {
      'success': true,
      'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      'user': {'id': 'user_1', 'email': email, 'firstName': 'John', 'lastName': 'Doe'},
    };
  }

  /// Signup
  Future<Map<String, dynamic>> signup({required String email, required String password, required String firstName, required String lastName}) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'message': 'OTP sent to email'};
  }

  /// Verify OTP
  Future<Map<String, dynamic>> verifyOTP({required String email, required String otp}) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {
      'success': true,
      'token': 'mock_token_${DateTime.now().millisecondsSinceEpoch}',
      'user': {'id': 'user_1', 'email': email, 'firstName': 'John', 'lastName': 'Doe'},
    };
  }

  /// Resend OTP
  Future<Map<String, dynamic>> resendOTP(String email) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'message': 'OTP resent'};
  }

  /// Forgot password
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'message': 'Reset link sent to email'};
  }

  /// Reset password
  Future<Map<String, dynamic>> resetPassword({required String email, required String otp, required String newPassword}) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'message': 'Password reset successful'};
  }

  // ========== USER ENDPOINTS ==========

  /// Get user profile
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {
      'success': true,
      'user': {'id': userId, 'email': 'user@example.com', 'firstName': 'John', 'lastName': 'Doe'},
    };
  }

  /// Update user profile
  Future<Map<String, dynamic>> updateUserProfile({required String userId, required Map<String, dynamic> data}) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'message': 'Profile updated'};
  }

  // ========== WORKOUT ENDPOINTS ==========

  /// Get workouts
  Future<List<Map<String, dynamic>>> getWorkouts({required String userId, int page = 1, int limit = 20}) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  /// Add workout
  Future<Map<String, dynamic>> addWorkout(Map<String, dynamic> workout) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'id': 'workout_${DateTime.now().millisecondsSinceEpoch}'};
  }

  /// Update workout
  Future<Map<String, dynamic>> updateWorkout(String workoutId, Map<String, dynamic> workout) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true};
  }

  /// Delete workout
  Future<Map<String, dynamic>> deleteWorkout(String workoutId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true};
  }

  // ========== RUN ENDPOINTS ==========

  /// Save run
  Future<Map<String, dynamic>> saveRun(Map<String, dynamic> run) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'id': 'run_${DateTime.now().millisecondsSinceEpoch}'};
  }

  /// Get runs
  Future<List<Map<String, dynamic>>> getRuns({required String userId, int page = 1, int limit = 20}) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  // ========== PROGRAM ENDPOINTS ==========

  /// Get programs (marketplace)
  Future<List<Map<String, dynamic>>> getPrograms({String? category, String? searchQuery, int page = 1, int limit = 20}) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return [];
  }

  /// Get program details
  Future<Map<String, dynamic>> getProgramDetails(String programId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true};
  }

  /// Purchase program
  Future<Map<String, dynamic>> purchaseProgram({required String userId, required String programId, required double amount}) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'message': 'Program purchased'};
  }

  // ========== CHAT ENDPOINTS ==========

  /// Get conversations
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));

    // Mock conversations for demo
    final now = DateTime.now();
    return [
      {
        'id': 'conv_1',
        'userId': userId,
        'trainerId': 'trainer_1',
        'trainerName': 'Sarah Johnson',
        'trainerImage': 'SJ',
        'programId': 'prog_1',
        'programTitle': 'Complete Strength Program',
        'lastMessage': {
          'id': 'msg_1',
          'conversationId': 'conv_1',
          'senderId': 'trainer_1',
          'receiverId': userId,
          'message': 'Great progress on your workout today! Keep it up! 💪',
          'type': 'text',
          'isRead': false,
          'timestamp': now.subtract(const Duration(hours: 2)).toIso8601String(),
        },
        'unreadCount': 1,
        'createdAt': now.subtract(const Duration(days: 5)).toIso8601String(),
      },
      {
        'id': 'conv_2',
        'userId': userId,
        'trainerId': 'trainer_2',
        'trainerName': 'Mike Chen',
        'trainerImage': 'MC',
        'programId': 'prog_2',
        'programTitle': 'Cardio Blast Challenge',
        'lastMessage': {
          'id': 'msg_2',
          'conversationId': 'conv_2',
          'senderId': userId,
          'receiverId': 'trainer_2',
          'message': 'Thanks for the tips! I\'ll try that tomorrow.',
          'type': 'text',
          'isRead': true,
          'timestamp': now.subtract(const Duration(days: 1)).toIso8601String(),
        },
        'unreadCount': 0,
        'createdAt': now.subtract(const Duration(days: 3)).toIso8601String(),
      },
    ];
  }

  /// Create a new conversation
  Future<String> createConversation({
    required String userId,
    required String trainerId,
    required String trainerName,
    String? trainerImage,
    required String programId,
    required String programTitle,
  }) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return 'conv_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Get messages
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));

    // Mock message for demo
    final now = DateTime.now();
    final userId = _storage.getUserId() ?? 'user_1';

    // Return different messages based on conversation ID
    String messageText;
    String senderId;

    if (conversationId.contains('conv_1')) {
      messageText =
          'Welcome to the Complete Strength Program! I\'m here to help you achieve your fitness goals. Feel free to ask me any questions about your workouts, nutrition, or progress tracking. Let\'s get started! 💪';
      senderId = 'trainer_1';
    } else if (conversationId.contains('conv_2')) {
      messageText =
          'Hi! Welcome to the Cardio Blast Challenge. I\'m excited to work with you on this journey. Remember to stay hydrated and listen to your body. Ready to crush your goals? 🏃‍♂️';
      senderId = 'trainer_2';
    } else {
      // Default welcome message for new conversations
      messageText = 'Hello! Thanks for reaching out. I\'m here to help you with your fitness journey. Feel free to ask me any questions! 💪';
      senderId = 'trainer_1'; // Default trainer
    }

    return [
      {
        'id': 'msg_mock_${conversationId}',
        'conversationId': conversationId,
        'senderId': senderId,
        'receiverId': userId,
        'message': messageText,
        'type': 'text',
        'isRead': false,
        'timestamp': now.subtract(const Duration(hours: 1)).toIso8601String(),
      },
    ];
  }

  /// Send message
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String message,
    String type = 'text',
    String? fileUrl,
    String? fileName,
  }) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {
      'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'isRead': false,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Upload chat file (image, video, audio)
  Future<Map<String, dynamic>> uploadChatFile({
    required String filePath,
    required String conversationId,
    required String type, // 'image', 'video', 'audio'
  }) async {
    // TODO: Implement actual file upload API call
    await Future.delayed(const Duration(seconds: 2));
    return {'success': true, 'fileUrl': 'https://example.com/files/${filePath.split('/').last}', 'fileName': filePath.split('/').last};
  }

  /// Mark messages as read
  Future<Map<String, dynamic>> markMessagesAsRead(String conversationId) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(milliseconds: 500));
    return {'success': true};
  }

  /// Report a trainer
  Future<Map<String, dynamic>> reportTrainer({
    required String conversationId,
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? description,
  }) async {
    // TODO: Implement actual API call
    await Future.delayed(const Duration(seconds: 1));
    return {'success': true, 'id': 'report_${DateTime.now().millisecondsSinceEpoch}', 'message': 'Report submitted successfully'};
  }

  /// `POST /user/block/:blockedUserId`
  Future<Map<String, dynamic>> blockUser({required String blockerId, required String blockedUserId, String? reason}) async {
    final raw = await NetworkApiService().post(AppUrl.userBlock(blockedUserId), <String, dynamic>{});
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'success': true};
  }

  /// `DELETE /user/block/:blockedUserId`
  Future<Map<String, dynamic>> unblockUser({required String blockerId, required String blockedUserId}) async {
    final raw = await NetworkApiService().delete(AppUrl.userBlock(blockedUserId));
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {'success': true};
  }
}
