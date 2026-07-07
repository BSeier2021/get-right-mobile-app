import 'package:get/get.dart';
import 'package:get_right/Local%20Storage/local_storage.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/services/storage_service.dart';

/// Resolves the email used for support ticket list/create APIs.
Future<String?> resolveSupportTicketEmail({String? overrideEmail}) async {
  final override = overrideEmail?.trim();
  if (override != null && override.isNotEmpty) return override;

  if (Get.isRegistered<AuthController>()) {
    final auth = Get.find<AuthController>();
    if (auth.isLoggedIn()) {
      final profileEmail = auth.customerProfile?.email.trim();
      if (profileEmail != null && profileEmail.isNotEmpty) return profileEmail;
    }
  }

  StorageService? storage;
  if (Get.isRegistered<StorageService>()) {
    storage = Get.find<StorageService>();
  } else {
    storage = await StorageService.getInstance();
  }

  final sessionEmail = storage.getEmail()?.trim();
  if (sessionEmail != null && sessionEmail.isNotEmpty) return sessionEmail;

  final persisted = storage.getSupportTicketEmail()?.trim();
  if (persisted != null && persisted.isNotEmpty) return persisted;

  if (Get.isRegistered<LocalStorage>()) {
    final saved = Get.find<LocalStorage>().getSavedEmail()?.trim();
    if (saved != null && saved.isNotEmpty) return saved;
  }

  return null;
}
