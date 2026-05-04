import 'dart:io';

import 'package:get/get.dart';
import 'package:get_right/models/feed_multipart_init_model.dart';
import 'package:get_right/services/feed_presigned_multipart_service.dart';

/// Presigned multipart video upload with per-chunk progress (`0.0`–`1.0` during upload).
/// Feed lifecycle (create → init → complete) is handled by [FeedPublishController].
class FeedVideoUploadController extends GetxController {
  final uploadProgress = 0.0.obs;

  /// Delegates to [FeedPresignedMultipartService]. [onOverallProgress] receives mapped overall app progress (e.g. 0.12–0.90).
  Future<List<FeedCompletedPart>> runMultipartUpload({
    required File file,
    required int fileSize,
    required FeedMultipartInitData init,
    required String contentType,
    required void Function(double overall01) onOverallProgress,
  }) async {
    uploadProgress.value = 0;

    final uploaded = await FeedPresignedMultipartService.uploadFileParts(
      file: file,
      fileSize: fileSize,
      partSize: init.partSize,
      contentType: contentType,
      presignedParts: init.presignedParts,
      onProgress: (raw) {
        uploadProgress.value = raw;
        onOverallProgress(raw);
      },
    );

    uploadProgress.value = 1.0;
    return uploaded;
  }
}
