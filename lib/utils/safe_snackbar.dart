import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Shows a snackbar without GetX's async queue (which can throw when Overlay is missing).
void showSafeSnackbar(String title, String message) {
  final text = title.isEmpty ? message : '$title: $message';

  void show() {
    final ctx = Get.context;
    if (ctx == null || !ctx.mounted) {
      debugPrint('[SafeSnackbar] $text');
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) {
      debugPrint('[SafeSnackbar] $text');
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) => show());
}
