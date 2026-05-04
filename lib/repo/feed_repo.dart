import 'package:get_right/app_url.dart';
import 'package:get_right/network/network_services.dart';

class FeedRepository {
  final NetworkApiService _network = NetworkApiService();

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
