import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_right/models/feed_category_model.dart';
import 'package:get_right/models/feed_multipart_init_model.dart';
import 'package:get_right/repo/auth_repo.dart';
import 'package:get_right/network/network_services.dart';
import 'package:get_right/repo/feed_repo.dart';
import 'package:get_right/controllers/feed_video_upload_controller.dart';
import 'package:get_right/theme/color_constants.dart';
import 'package:get_right/utils/feed_post_mapper.dart';

List<String> parseFeedTagsInput(String raw) {
  return raw
      .split(RegExp(r'\s+'))
      .map((t) => t.replaceFirst(RegExp(r'^#+'), '').trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

void _noopUploadProgress(double _) {}

String guessVideoContentType(String filePath) {
  final lower = filePath.toLowerCase();
  if (lower.endsWith('.mov')) return 'video/quicktime';
  if (lower.endsWith('.m4v')) return 'video/x-m4v';
  if (lower.endsWith('.webm')) return 'video/webm';
  return 'video/mp4';
}

/// Orchestrates feed creation, draft saves, and optional S3 multipart video upload with progress.
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
  final isSavingDraft = false.obs;
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

  Map<String, dynamic>? _feedDocFromGetResponse(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'];
    if (data is! Map) return null;
    final feed = data['feed'];
    if (feed is! Map) return null;
    return Map<String, dynamic>.from(feed);
  }

  bool _feedVideoProcessingFailed(Map<String, dynamic> feed) {
    final st = (feed['videoProcessingStatus'] ?? '').toString().toLowerCase();
    if (st.isEmpty) return false;
    return st.contains('fail') || st.contains('error') || st == 'cancelled' || st == 'canceled';
  }

  bool _feedVideoReadyForPublish(Map<String, dynamic> feed) {
    final video = feed['video'];
    if (video is Map) {
      final vm = Map<String, dynamic>.from(video);
      final url = extractFeedVideoUrl(feed, vm);
      if (url != null && url.trim().isNotEmpty) return true;
    }
    final st = (feed['videoProcessingStatus'] ?? '').toString().toLowerCase().trim();
    return st == 'ready' ||
        st == 'completed' ||
        st == 'complete' ||
        st == 'succeeded' ||
        st == 'success' ||
        st == 'done';
  }

  void _showSnack(String title, String message, {Color? backgroundColor, int seconds = 3}) {
    if (Get.isSnackbarOpen) return;
    Get.snackbar(
      title,
      message,
      backgroundColor: backgroundColor ?? AppColors.error,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: seconds),
    );
  }

  String? _validateForm({required String title, required bool requireMedia, required bool hasMedia}) {
    if (requireMedia && !hasMedia) return 'Please select an image or video';
    if (title.trim().isEmpty) return 'Please enter a title for your post.';
    if (feedCategories.isNotEmpty &&
        (selectedCategoryId.value == null || selectedCategoryId.value!.isEmpty)) {
      return 'Please select a category.';
    }
    if (feedCategories.isEmpty) return 'No categories available. Try again later.';
    return null;
  }

  Future<List<File>> _imageFilesFromPaths(List<String> mediaPaths) async {
    final imageFiles = <File>[];
    for (final path in mediaPaths) {
      final imageFile = File(path);
      if (!await imageFile.exists()) {
        throw StateError('Image file not found.');
      }
      if (await imageFile.length() <= 0) {
        throw StateError('Image file is empty.');
      }
      imageFiles.add(imageFile);
    }
    return imageFiles;
  }

  Future<void> _uploadVideoToFeed({
    required String feedId,
    required String mediaPath,
    void Function(double overallProgress) onOverallProgress = _noopUploadProgress,
  }) async {
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

    final videoUpload = Get.find<FeedVideoUploadController>();
    final uploaded = await videoUpload.runMultipartUpload(
      file: file,
      fileSize: fileSize,
      init: init,
      contentType: contentType,
      onOverallProgress: onOverallProgress,
    );

    publishPhase.value = 'finishing';

    await _feed.completeVideoMultipartRepo(
      feedId: feedId,
      key: init.key,
      uploadId: init.uploadId,
      parts: uploaded.map((e) => e.toCompleteApiJson()).toList(),
    );
  }

  /// Returns `true` if the reel is live (`Published`). `false` if we stopped waiting (still draft / processing).
  Future<Map<String, dynamic>?> _fetchFeedDocForPolling(String feedId) async {
    try {
      final raw = await _feed.getFeedByIdRepo(feedId);
      final doc = _feedDocFromGetResponse(raw);
      if (doc != null) return doc;
    } on NotFoundException {
      // Draft reels are not available on GET /user/feed/:id.
    } catch (_) {
      return null;
    }

    try {
      final raw = await _feed.getMyFeedsRepo(page: 1, limit: 50);
      return feedDocumentFromMineListResponse(raw, feedId);
    } catch (_) {
      return null;
    }
  }

  /// Returns `true` if the reel is live (`Published`). `false` if we stopped waiting (still draft / processing).
  Future<bool> _waitForVideoReadyThenPublish({
    required String feedId,
    required String title,
    required String description,
    required String categoryId,
    required List<String> tags,
  }) async {
    const poll = Duration(seconds: 2);
    const maxAttempts = 150;

    publishPhase.value = 'processing';

    for (var i = 0; i < maxAttempts; i++) {
      if (i > 0) await Future<void>.delayed(poll);

      Map<String, dynamic>? doc = await _fetchFeedDocForPolling(feedId);
      if (doc == null) continue;

      if (_feedVideoProcessingFailed(doc)) {
        throw StateError(
          'Video processing failed. You can open this post from your profile to try again.',
        );
      }

      final statusNorm = (doc['status'] ?? '').toString().toLowerCase().trim();
      if (statusNorm == 'published') {
        return true;
      }

      if (_feedVideoReadyForPublish(doc)) {
        try {
          await _feed.updateFeedRepo(
            feedId: feedId,
            title: title.trim(),
            description: description.trim(),
            categoryId: categoryId,
            tags: tags,
            status: 'Published',
          );
          return true;
        } catch (e) {
          final msg = e.toString();
          if (msg.contains('Cannot set Published') || msg.contains('ready video')) {
            continue;
          }
          rethrow;
        }
      }

      uploadProgress.value = (0.92 + 0.07 * (i + 1) / maxAttempts).clamp(0.0, 0.99);
    }

    return false;
  }

  Future<String?> _ensureDraftFeedId({
    String? existingFeedId,
    required String title,
    required String description,
    required String categoryId,
    required List<String> tags,
  }) async {
    final trimmedExisting = existingFeedId?.trim();
    if (trimmedExisting != null && trimmedExisting.isNotEmpty) {
      await _feed.updateFeedRepo(
        feedId: trimmedExisting,
        title: title.trim(),
        description: description.trim(),
        categoryId: categoryId,
        tags: tags,
        status: 'Draft',
      );
      return trimmedExisting;
    }

    final createRes = await _feed.createFeedRepo(
      title: title.trim(),
      description: description.trim(),
      categoryId: categoryId,
      tags: tags,
      status: 'Draft',
    );
    return _feedIdFromCreate(createRes);
  }

  /// Saves metadata as `Draft`. Media is optional; attach video/images when provided.
  Future<String?> saveDraft({
    String? existingFeedId,
    required String title,
    required String description,
    required String tagsRaw,
    List<String> mediaPaths = const [],
    bool isVideo = false,
  }) async {
    final err = _validateForm(title: title, requireMedia: false, hasMedia: true);
    if (err != null) {
      _showSnack(err.contains('title') ? 'Title Required' : 'Category', err);
      return null;
    }

    final categoryId = selectedCategoryId.value!;
    final tags = parseFeedTagsInput(tagsRaw);

    isSavingDraft.value = true;
    uploadProgress.value = 0.0;
    publishPhase.value = 'creating';

    try {
      final feedId = await _ensureDraftFeedId(
        existingFeedId: existingFeedId,
        title: title,
        description: description,
        categoryId: categoryId,
        tags: tags,
      );
      if (feedId == null) {
        throw StateError('Could not read feed id from server response.');
      }

      uploadProgress.value = 0.2;

      if (!isVideo && mediaPaths.isNotEmpty) {
        publishPhase.value = 'uploading';
        final imageFiles = await _imageFilesFromPaths(mediaPaths);
        await _feed.updateFeedWithImagesMultipartRepo(
          feedId: feedId,
          title: title.trim(),
          description: description.trim(),
          categoryId: categoryId,
          tags: tags,
          imageFiles: imageFiles,
          status: 'Draft',
        );
      } else if (isVideo && mediaPaths.isNotEmpty) {
        await _uploadVideoToFeed(
          feedId: feedId,
          mediaPath: mediaPaths.first,
          onOverallProgress: (raw) {
            uploadProgress.value = 0.2 + raw * 0.75;
          },
        );
      }

      uploadProgress.value = 1.0;
      publishPhase.value = '';
      Get.back(result: <String, dynamic>{'feedId': feedId, 'savedDraft': true});
      _showSnack(
        'Draft saved',
        mediaPaths.isEmpty
            ? 'Your post was saved as a draft. Add media and publish from your profile when ready.'
            : 'Your draft was saved. Finish publishing from your profile when ready.',
        backgroundColor: AppColors.completed,
        seconds: 4,
      );
      return feedId;
    } catch (e) {
      publishPhase.value = '';
      _showSnack('Could not save draft', e.toString());
      return null;
    } finally {
      isSavingDraft.value = false;
      uploadProgress.value = 0.0;
      publishPhase.value = '';
    }
  }

  /// Full publish: video = create/update as `Draft`, multipart upload, poll until ready, then `PATCH` `Published`;
  /// photo = multipart create/update with image files.
  Future<void> publish({
    String? existingFeedId,
    bool hasExistingMedia = false,
    required List<String> mediaPaths,
    required bool isVideo,
    required String title,
    required String description,
    required String tagsRaw,
  }) async {
    final hasMedia = mediaPaths.isNotEmpty || hasExistingMedia;
    final err = _validateForm(title: title, requireMedia: true, hasMedia: hasMedia);
    if (err != null) {
      _showSnack(err.contains('Media') ? 'Media Required' : err.contains('title') ? 'Title Required' : 'Category', err);
      return;
    }

    final categoryId = selectedCategoryId.value!;
    final tags = parseFeedTagsInput(tagsRaw);
    final trimmedExisting = existingFeedId?.trim();

    isPublishing.value = true;
    uploadProgress.value = 0.0;
    publishPhase.value = 'creating';

    try {
      late final String feedId;

      if (trimmedExisting != null && trimmedExisting.isNotEmpty) {
        feedId = trimmedExisting;
        await _feed.updateFeedRepo(
          feedId: feedId,
          title: title.trim(),
          description: description.trim(),
          categoryId: categoryId,
          tags: tags,
          status: isVideo ? 'Draft' : 'Published',
        );
        uploadProgress.value = 0.08;
      } else if (isVideo) {
        final createRes = await _feed.createFeedRepo(
          title: title.trim(),
          description: description.trim(),
          categoryId: categoryId,
          tags: tags,
          status: 'Draft',
        );
        final createdId = _feedIdFromCreate(createRes);
        if (createdId == null) {
          throw StateError('Could not read feed id from server response.');
        }
        feedId = createdId;
        uploadProgress.value = 0.08;
      } else {
        final imageFiles = await _imageFilesFromPaths(mediaPaths);
        final createRes = await _feed.createFeedWithImagesMultipartRepo(
          title: title.trim(),
          description: description.trim(),
          categoryId: categoryId,
          tags: tags,
          imageFiles: imageFiles,
          status: 'Published',
        );
        final createdId = _feedIdFromCreate(createRes);
        if (createdId == null) {
          throw StateError('Could not read feed id from server response.');
        }
        feedId = createdId;
        uploadProgress.value = 1.0;
        publishPhase.value = '';
        Get.back();
        final imageCount = mediaPaths.length;
        _showSnack(
          'Post published',
          imageCount > 1 ? 'Your photo post with $imageCount images was published.' : 'Your photo post was published.',
          backgroundColor: AppColors.completed,
        );
        return;
      }

      if (!isVideo) {
        if (mediaPaths.isNotEmpty) {
          final imageFiles = await _imageFilesFromPaths(mediaPaths);
          await _feed.updateFeedWithImagesMultipartRepo(
            feedId: feedId,
            title: title.trim(),
            description: description.trim(),
            categoryId: categoryId,
            tags: tags,
            imageFiles: imageFiles,
            status: 'Published',
          );
        } else if (hasExistingMedia) {
          await _feed.updateFeedRepo(
            feedId: feedId,
            title: title.trim(),
            description: description.trim(),
            categoryId: categoryId,
            tags: tags,
            status: 'Published',
          );
        }

        uploadProgress.value = 1.0;
        publishPhase.value = '';
        Get.back();
        _showSnack('Post published', 'Your photo post was published.', backgroundColor: AppColors.completed);
        return;
      }

      if (mediaPaths.isNotEmpty) {
        await _uploadVideoToFeed(
          feedId: feedId,
          mediaPath: mediaPaths.first,
          onOverallProgress: (raw) {
            uploadProgress.value = 0.12 + raw * 0.78;
          },
        );
      } else if (!hasExistingMedia) {
        throw StateError('Please select a video to publish.');
      } else {
        uploadProgress.value = 0.92;
      }

      final published = await _waitForVideoReadyThenPublish(
        feedId: feedId,
        title: title.trim(),
        description: description.trim(),
        categoryId: categoryId,
        tags: tags,
      );

      uploadProgress.value = 1.0;
      publishPhase.value = '';
      Get.back();
      _showSnack(
        published ? 'Post published' : 'Video uploaded',
        published
            ? 'Your reel is live.'
            : 'Encoding is taking longer than usual. The post stays as a draft until the video is ready—open it from your profile and set status to Published when processing finishes.',
        backgroundColor: AppColors.completed,
        seconds: published ? 3 : 5,
      );
    } catch (e) {
      publishPhase.value = '';
      _showSnack('Publish failed', e.toString());
    } finally {
      isPublishing.value = false;
      uploadProgress.value = 0.0;
      publishPhase.value = '';
    }
  }
}
