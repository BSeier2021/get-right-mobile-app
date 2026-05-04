/// Response payload from `POST .../video/multipart/init` (`data` object).
class FeedMultipartInitData {
  final String feedId;
  final String uploadId;
  final String key;
  final int partSize;
  final List<FeedPresignedUrlPart> presignedParts;

  FeedMultipartInitData({
    required this.feedId,
    required this.uploadId,
    required this.key,
    required this.partSize,
    required this.presignedParts,
  });

  factory FeedMultipartInitData.fromJson(Map<String, dynamic> json) {
    final rawUrls = json['presignedUrls'];
    final parts = <FeedPresignedUrlPart>[];
    if (rawUrls is List) {
      for (final e in rawUrls) {
        if (e is Map<String, dynamic>) {
          final pn = e['partNumber'] ?? e['PartNumber'];
          final n = pn is int ? pn : int.tryParse('$pn') ?? 0;
          final url = e['url']?.toString() ?? '';
          if (n > 0 && url.isNotEmpty) {
            parts.add(FeedPresignedUrlPart(partNumber: n, url: url));
          }
        }
      }
      parts.sort((a, b) => a.partNumber.compareTo(b.partNumber));
    }

    final ps = json['partSize'];
    final partSize = ps is int ? ps : int.tryParse('$ps') ?? 8388608;

    return FeedMultipartInitData(
      feedId: json['feedId']?.toString() ?? '',
      uploadId: json['uploadId']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      partSize: partSize,
      presignedParts: parts,
    );
  }

  static FeedMultipartInitData? tryParse(dynamic response) {
    if (response is! Map) return null;
    final data = response['data'];
    if (data is! Map<String, dynamic>) return null;
    final init = FeedMultipartInitData.fromJson(data);
    if (init.uploadId.isEmpty ||
        init.key.isEmpty ||
        init.presignedParts.isEmpty)
      return null;
    return init;
  }
}

class FeedPresignedUrlPart {
  final int partNumber;
  final String url;

  FeedPresignedUrlPart({required this.partNumber, required this.url});
}

/// One completed S3 part for `multipart/complete`.
class FeedCompletedPart {
  final int partNumber;
  final String eTag;

  FeedCompletedPart({required this.partNumber, required this.eTag});

  Map<String, dynamic> toCompleteApiJson() => {
    'PartNumber': partNumber,
    'ETag': eTag,
  };
}
