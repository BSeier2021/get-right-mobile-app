import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_right/Local%20Storage/local_storage.dart';

class AuthService extends GetxService {
  final String initialToken = "yNaHwJpGFSquIkXP";
  final LocalStorage localStorage = Get.put<LocalStorage>(LocalStorage());
  // Make token reactive
  final RxString _token = RxString('');

  @override
  void onInit() {
    super.onInit();
    log(this.hashCode.toString(), name: "AuthService Code");
    getTokenFromLocalStorage();
  }

  String? getTokenFromLocalStorage() {
    _token.value = localStorage.getAccessToken() ?? '';
    log(_token.value.toString(), name: "Get token");
    return _token.value;
  }

  String get authToken {
    log(_token.value.toString(), name: "token");
    log(this.hashCode.toString(), name: "AuthService Code");
    return _token.value;
  }

  Future<bool> setToken(String token) async {
    try {
      await localStorage.saveAccessToken(token);
      _token.value = token;
      log(_token.value.toString(), name: "Saved token");
      return true;
    } catch (e) {
      debugPrint('Error saving token: $e');
      return false;
    }
  }

  Future<void> clearToken() async {
    await localStorage.deleteAccessToken();
    _token.value = '';
  }

  Future<void> clearAllAuthData() async {
    await clearToken();
  }
}
