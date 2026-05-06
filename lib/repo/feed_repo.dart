import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';

class FeedRepository {
  final NetworkApiService _network = NetworkApiService();

  /// `GET /user/feed` — query: `page`, `limit`, optional `type` (`following`).
  ///
  /// Response shape (backend):
  /// `data.totalDocs`, `data.feeds[]`, `data.currentPage`, `data.totalPages`,
  /// `data.hasNextPage`, `data.hasPrevPage`.
  Future<dynamic> getFeedsRepo({
    required int page,
    required int limit,
    String? type,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
    };
    return _network.get(AppUrl.feedCreate, params: params);
  }

  /// `POST /user/feed`
  Future<dynamic> createFeedRepo({
    required String title,
    required String description,
    required String categoryId,
    required List<String> tags,
  }) async {
    return _network.post(AppUrl.feedCreate, {
      'title': title,
      'description': description,
      'category': categoryId,
      'tags': tags,
    });
  }

  /// `POST /user/feed/:feedId/video/multipart/init`
  Future<dynamic> initVideoMultipartRepo({
    required String feedId,
    required String contentType,
    required int fileSize,
  }) async {
    return _network.post(AppUrl.feedVideoMultipartInit(feedId), {
      'contentType': contentType,
      'fileSize': fileSize,
    });
  }

  /// `POST /user/feed/:feedId/video/multipart/complete`
  Future<dynamic> completeVideoMultipartRepo({
    required String feedId,
    required String key,
    required String uploadId,
    required List<Map<String, dynamic>> parts,
  }) async {
    return _network.post(AppUrl.feedVideoMultipartComplete(feedId), {
      'key': key,
      'uploadId': uploadId,
      'parts': parts,
    });
  }
}
