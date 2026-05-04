import 'dart:io';
import 'dart:math';

import 'package:get_right/models/feed_multipart_init_model.dart';
import 'package:http/http.dart' as http;

/// Uploads a local file to S3 using presigned multipart URLs (PUT per part).
class FeedPresignedMultipartService {
  FeedPresignedMultipartService._();

  static const Duration _putTimeout = Duration(minutes: 20);

  static String _normalizeEtag(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    var s = raw.trim();
    if (s.length >= 2 && s.startsWith('"') && s.endsWith('"')) {
      s = s.substring(1, s.length - 1);
    }
    return s;
  }

  /// Uploads [file] in order; [onProgress] reports 0.0–1.0 by bytes uploaded.
  static Future<List<FeedCompletedPart>> uploadFileParts({
    required File file,
    required int fileSize,
    required int partSize,
    required String contentType,
    required List<FeedPresignedUrlPart> presignedParts,
    required void Function(double progress01) onProgress,
  }) async {
    if (fileSize <= 0) {
      throw StateError('Video file is empty.');
    }
    if (presignedParts.isEmpty) {
      throw StateError('No presigned upload URLs returned.');
    }

    List<FeedPresignedUrlPart> ordered = List.of(presignedParts)
      ..sort((a, b) => a.partNumber.compareTo(b.partNumber));

    final randomAccessFile = await file.open();
    try {
      var uploadedBytes = 0;
      final results = <FeedCompletedPart>[];

      for (final part in ordered) {
        final index0 = part.partNumber - 1;
        final start = index0 * partSize;
        if (start >= fileSize) break;

        final chunkLen = min(partSize, fileSize - start);
        await randomAccessFile.setPosition(start);
        final chunk = await randomAccessFile.read(chunkLen);

        final uri = Uri.parse(part.url);
        final resp = await http
            .put(uri, headers: {'Content-Type': contentType}, body: chunk)
            .timeout(_putTimeout);

        if (resp.statusCode < 200 || resp.statusCode >= 300) {
          throw HttpException(
            'Part ${part.partNumber} upload failed: HTTP ${resp.statusCode}',
            uri: uri,
          );
        }

        final etag = _normalizeEtag(
          resp.headers['etag'] ?? resp.headers['ETag'],
        );
        if (etag.isEmpty) {
          throw HttpException(
            'Missing ETag for part ${part.partNumber}',
            uri: uri,
          );
        }

        results.add(FeedCompletedPart(partNumber: part.partNumber, eTag: etag));
        uploadedBytes += chunkLen;
        onProgress(uploadedBytes / fileSize);
      }

      onProgress(1.0);
      results.sort((a, b) => a.partNumber.compareTo(b.partNumber));
      return results;
    } finally {
      await randomAccessFile.close();
    }
  }
}
