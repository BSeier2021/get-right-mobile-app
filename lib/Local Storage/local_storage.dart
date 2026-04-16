import 'dart:developer';
import 'package:get/get.dart';
import 'package:get_right/Local%20Storage/local_storage_keys.dart';
import 'package:get_right/utils%20copy/utils.dart';
import 'package:get_storage/get_storage.dart';

class LocalStorage extends GetxService {
  final getStorage = GetStorage();

  Future init() async {
    await GetStorage.init();
    log("GetStorage initialized");
  }

  saveJson({required String key, required value}) {
    var res = getStorage.write(key, value);
    log("Saved key: $key with value: $value");
    return res;
  }

  readJson({required String key}) {
    var res = getStorage.read(key);
    log("Read key: $key, value: $res");
    return res;
  }

  deleteJson({required String key}) {
    var res = getStorage.remove(key);
    log("Deleted key: $key");
    return res;
  }

  saveAccessToken(String token) {
    getStorage.write(lsk.authToken, token);
    log("Access token saved: $token");
  }

  saveuserid(String id) {
    getStorage.write("id", id);

    log("Access id saved: $id");
  }

  getAccessToken() {
    var token = getStorage.read(lsk.authToken) ?? "";
    log("Access token retrieved: $token");
    return token;
  }

  deleteAccessToken() {
    getStorage.remove(lsk.authToken);
    log("Access token deleted");
  }

  clearAlldata() {
    getStorage.erase();
    log("All data cleared from storage");
  }

  clearCredentials() {
    getStorage.remove(lsk.authToken);
    getStorage.remove(lsk.password);
    getStorage.remove(lsk.email);
    getStorage.remove(lsk.rememberMe);
    Utils.logSuccess("Credentials cleared");
  }

  // ========================================
  // Remember Me Functionality
  // ========================================

  /// Save user credentials for remember me functionality
  void saveCredentials({required String email, required String password}) {
    getStorage.write(lsk.email, email);
    getStorage.write(lsk.password, password);
    getStorage.write(lsk.rememberMe, true);
    log("Credentials saved for remember me: email=$email");
  }

  /// Get saved email
  String? getSavedEmail() {
    final email = getStorage.read(lsk.email);
    log("Retrieved saved email: $email");
    return email;
  }

  /// Get saved password
  String? getSavedPassword() {
    final password = getStorage.read(lsk.password);
    log("Retrieved saved password: ${password != null ? '***' : 'null'}");
    return password;
  }

  /// Check if remember me is enabled
  bool isRememberMeEnabled() {
    final rememberMe = getStorage.read(lsk.rememberMe) ?? false;
    log("Remember me status: $rememberMe");
    return rememberMe;
  }

  /// Set remember me preference
  void setRememberMe(bool value) {
    getStorage.write(lsk.rememberMe, value);
    log("Remember me preference set to: $value");
  }

  /// Check if we have saved credentials
  bool hasSavedCredentials() {
    final hasEmail = getStorage.read(lsk.email) != null;
    final hasPassword = getStorage.read(lsk.password) != null;
    final rememberMe = getStorage.read(lsk.rememberMe) ?? false;
    final hasCredentials = hasEmail && hasPassword && rememberMe;
    log("Has saved credentials: $hasCredentials");
    return hasCredentials;
  }

  /// Clear saved credentials but keep remember me preference
  void clearSavedCredentials() {
    getStorage.remove(lsk.email);
    getStorage.remove(lsk.password);
    log("Saved credentials cleared");
  }

  /// Set whether we have asked the user about remember me
  void setHasAskedRememberMe(bool value) {
    getStorage.write(lsk.hasAskedRememberMe, value);
    log("Has asked remember me set to: $value");
  }

  /// Check if we have asked the user about remember me
  bool hasAskedRememberMe() {
    final hasAsked = getStorage.read(lsk.hasAskedRememberMe) ?? false;
    log("Has asked remember me: $hasAsked");
    return hasAsked;
  }

  writeIfNull(String key, bool value) {
    getStorage.writeIfNull(key, value);
    log("Write if null key: $key with value: $value");
  }
}
