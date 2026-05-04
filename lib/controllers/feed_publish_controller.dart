import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/feed_category_model.dart';
import 'package:get_right/models/feed_multipart_init_model.dart';
import 'package:get_right/repo/auth_repo.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/controllers/feed_video_upload_controller.dart';
import 'package:get_right/theme/color_constants.dart';

List<String> parseFeedTagsInput(String raw) {
  return raw
      .split(RegExp(r'\s+'))
      .map((t) => t.replaceFirst(RegExp(r'^#+'), '').trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

String guessVideoContentType(String filePath) {
  final lower = filePath.toLowerCase();
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.m4v')) return 'video/x-m4v';
  if (lower.endsWith('.webm')) return 'video/webm';
  return 'video/mp4';
}

/// Orchestrates feed creation and optional S3 multipart video upload with progress.
class FeedPublishController extends GetxController {
  FeedPublishController({
    AuthRepository? authRepository,
    FeedRepository? feedRepository,
  }) : _auth = authRepository ?? AuthRepository(),
       _feed = feedRepository ?? FeedRepository();

  final AuthRepository _auth;
  final FeedRepository _feed;

  final feedCategories = <FeedCategory>[].obs;
  final RxnString selectedCategoryId = RxnString();
  final feedCategoriesLoading = true.obs;
  final RxnString feedCategoriesError = RxnString();

  final isPublishing = false.obs;
  final uploadProgress = 0.0.obs;
  final publishPhase = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadFeedCategories();
  }

  Future<void> loadFeedCategories() async {
    feedCategoriesLoading.value = true;
    feedCategoriesError.value = null;
    try {
      final dynamic res = await _auth.getFeedCategoriesRepo();
      final list = FeedCategory.listFromResponse(res);
      feedCategories.assignAll(list);
      if (selectedCategoryId.value != null &&
          !list.any((c) => c.id == selectedCategoryId.value)) {
        selectedCategoryId.value = null;
      }
      if (selectedCategoryId.value == null && list.isNotEmpty) {
        selectedCategoryId.value = list.first.id;
      }
    } catch (e) {
      feedCategoriesError.value = e.toString();
    } finally {
      feedCategoriesLoading.value = false;
    }
  }

  void setCategory(String? id) {
    selectedCategoryId.value = id;
  }

  String? _feedIdFromCreate(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'];
    if (data is! Map) return null;
    final feed = data['feed'];
    if (feed is! Map) return null;
    final id = feed['_id'] ?? feed['id'];
    final s = id?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }

  /// Full publish: [isVideo] runs multipart pipeline after create; photos only create the feed draft.
  Future<void> publish({
    required String mediaPath,
    required bool isVideo,
    required String title,
    required String description,
    required String tagsRaw,
  }) async {
    if (title.trim().isEmpty) {
      Get.snackbar(
        'Title Required',
        'Please enter a title for your post.',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (feedCategories.isNotEmpty &&
        (selectedCategoryId.value == null ||
            selectedCategoryId.value!.isEmpty)) {
      Get.snackbar(
        'Category',
        'Please select a category.',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (feedCategories.isEmpty) {
      Get.snackbar(
        'Categories',
        'No categories available. Try again later.',
        backgroundColor: AppColors.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final categoryId = selectedCategoryId.value!;
    final tags = parseFeedTagsInput(tagsRaw);

    isPublishing.value = true;
    uploadProgress.value = 0.0;
    publishPhase.value = 'creating';

    try {
      final createRes = await _feed.createFeedRepo(
        title: title.trim(),
        description: description.trim(),
        categoryId: categoryId,
        tags: tags,
      );

      final feedId = _feedIdFromCreate(createRes);
      if (feedId == null) {
        throw StateError('Could not read feed id from server response.');
      }

      uploadProgress.value = 0.08;

      if (!isVideo) {
        uploadProgress.value = 1.0;
        publishPhase.value = '';
        Get.back();
        Get.snackbar(
          'Post created',
          'Your feed entry was created.',
          backgroundColor: AppColors.completed,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      final file = File(mediaPath);
      if (!await file.exists()) {
        throw StateError('Video file not found.');
      }
      final fileSize = await file.length();
      if (fileSize <= 0) {
        throw StateError('Video file is empty.');
      }

      final contentType = guessVideoContentType(mediaPath);
      publishPhase.value = 'preparing_upload';

      final initRaw = await _feed.initVideoMultipartRepo(
        feedId: feedId,
        contentType: contentType,
        fileSize: fileSize,
      );

      final init = FeedMultipartInitData.tryParse(initRaw);
      if (init == null) {
        throw StateError('Invalid multipart init response.');
      }

      publishPhase.value = 'uploading';
      uploadProgress.value = 0.12;

      final videoUpload = Get.find<FeedVideoUploadController>();
      final uploaded = await videoUpload.runMultipartUpload(
        file: file,
        fileSize: fileSize,
        init: init,
        contentType: contentType,
        onOverallProgress: (raw) {
          uploadProgress.value = 0.12 + raw * 0.78;
        },
      );

      publishPhase.value = 'finishing';
      uploadProgress.value = 0.92;

      await _feed.completeVideoMultipartRepo(
        feedId: feedId,
        key: init.key,
        uploadId: init.uploadId,
        parts: uploaded.map((e) => e.toCompleteApiJson()).toList(),
      );

      uploadProgress.value = 1.0;
      publishPhase.value = '';
      Get.back();
      Get.snackbar(
        'Post published',
        'Your video was uploaded and is processing.',
        backgroundColor: AppColors.completed,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      publishPhase.value = '';
      if (!Get.isSnackbarOpen) {
        Get.snackbar(
          'Publish failed',
          e.toString(),
          backgroundColor: AppColors.error,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      isPublishing.value = false;
      uploadProgress.value = 0.0;
      publishPhase.value = '';
    }
  }
}
