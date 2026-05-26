import 'dart:io';

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

  /// `GET /user/feed/mine?page=&limit=` — paginated reels owned by current user (`data.feeds`, `hasNextPage`, …).
  Future<dynamic> getMyFeedsRepo({required int page, required int limit}) async {
    return _network.get(AppUrl.feedMine, params: <String, dynamic>{'page': page, 'limit': limit});
  }

  /// `GET /user/feed/:feedId` — `data.feed`, `likedByMe`, `savedByMe`.
  Future<dynamic> getFeedByIdRepo(String feedId) async {
    return _network.get(AppUrl.feedById(feedId));
  }

  /// `GET /user/feed-categories` — same base auth as other feed routes (`data.categories[]`).
  Future<dynamic> getFeedCategoriesRepo() async {
    // Backend expects the raw guest token (non-Bearer) for this endpoint.
    return _network.get(
      AppUrl.feedCategories,
      headers: <String, String>{
        'skipAuth': 'true',
        'Authorization': NetworkApiService.guestAuthToken,
      },
    );
  }

  /// `PATCH /user/feed/:feedId` — body: `title`, `description`, `tags`, `category` (id), optional `status` (`Draft` | `Published`).
  Future<dynamic> updateFeedRepo({
    required String feedId,
    required String title,
    required String description,
    required String categoryId,
    required List<String> tags,
    String? status,
  }) async {
    final body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'tags': tags,
    };
    if (categoryId.trim().isNotEmpty) {
      body['category'] = categoryId.trim();
    }
    final st = status?.trim();
    if (st != null && st.isNotEmpty) {
      body['status'] = st;
    }
    return _network.patch(AppUrl.feedById(feedId), body);
  }

  /// `DELETE` — [AppUrl.feedDelete] → `/api/v1/user/feed/:feedId`.
  Future<dynamic> deleteFeedRepo(String feedId) async {
    return _network.delete(AppUrl.feedDelete(feedId));
  }

  /// `POST /user/feed/:feedId/like` — like feed post.
  Future<dynamic> likeFeedRepo(String feedId) async {
    return _network.post(AppUrl.feedLike(feedId), <String, dynamic>{});
  }

  /// `DELETE /user/feed/:feedId/like` — remove like (`message`: `Like removed`).
  Future<dynamic> unlikeFeedRepo(String feedId) async {
    return _network.delete(AppUrl.feedLike(feedId));
  }

  /// `POST /user/feed/:feedId/save` — save feed post (`message`: `Feed saved`).
  Future<dynamic> saveFeedRepo(String feedId) async {
    return _network.post(AppUrl.feedSave(feedId), <String, dynamic>{});
  }

  /// `DELETE /user/feed/:feedId/save` — remove saved feed post.
  Future<dynamic> unsaveFeedRepo(String feedId) async {
    return _network.delete(AppUrl.feedSave(feedId));
  }

  /// `POST /user/feed/:feedId/repost` — repost reel.
  Future<dynamic> repostFeedRepo(String feedId) async {
    return _network.post(AppUrl.feedRepost(feedId), <String, dynamic>{});
  }

  /// `GET /user/feed/save` — paginated saved reels (`data.savedFeeds[].feed`, `hasNextPage`, …).
  Future<dynamic> getSavedFeedsRepo({required int page, required int limit}) async {
    return _network.get(
      AppUrl.feedSavedList,
      params: <String, dynamic>{'page': page, 'limit': limit},
    );
  }

  /// `GET /user/feed/:feedId/comments` — paginated comments (`data.comments`, `hasNextPage`, …).
  Future<dynamic> getFeedCommentsRepo({
    required String feedId,
    required int page,
    required int limit,
  }) async {
    return _network.get(
      AppUrl.feedComments(feedId),
      params: <String, dynamic>{'page': page, 'limit': limit},
    );
  }

  /// `GET /user/feed/comments/:commentId/replies` — paginated replies for a top-level comment.
  Future<dynamic> getFeedCommentRepliesRepo({
    required String commentId,
    required int page,
    required int limit,
  }) async {
    return _network.get(
      AppUrl.feedCommentReplies(commentId),
      params: <String, dynamic>{'page': page, 'limit': limit},
    );
  }

  /// `POST /user/feed/:feedId/comments` — body: `text`, optional `parentComment` for replies.
  Future<dynamic> postFeedCommentRepo({
    required String feedId,
    required String text,
    String? parentCommentId,
  }) async {
    final body = <String, dynamic>{'text': text.trim()};
    final parent = parentCommentId?.trim();
    if (parent != null && parent.isNotEmpty) {
      body['parentComment'] = parent;
    }
    return _network.post(AppUrl.feedComments(feedId), body);
  }

  /// `PATCH /user/feed/:feedId/comments/:commentId` — body: `text`.
  Future<dynamic> updateFeedCommentRepo({
    required String feedId,
    required String commentId,
    required String text,
  }) async {
    return _network.patch(AppUrl.feedCommentById(feedId, commentId), <String, dynamic>{'text': text.trim()});
  }

  /// `DELETE /user/feed/:feedId/comments/:commentId`.
  Future<dynamic> deleteFeedCommentRepo({
    required String feedId,
    required String commentId,
  }) async {
    return _network.delete(AppUrl.feedCommentById(feedId, commentId));
  }

  /// `POST /user/feed` — JSON body. Use [status] `Draft` when media is attached afterward (e.g. video multipart).
  Future<dynamic> createFeedRepo({
    required String title,
    required String description,
    required String categoryId,
    required List<String> tags,
    String? status,
  }) async {
    final body = <String, dynamic>{
      'title': title.trim(),
      'description': description.trim(),
      'category': categoryId.trim(),
      'tags': tags,
    };
    final st = status?.trim();
    if (st != null && st.isNotEmpty) {
      body['status'] = st;
    }
    return _network.post(AppUrl.feedCreate, body);
  }

  /// `POST /user/feed` — multipart when publishing with at least one image (backend rejects Published without media).
  Future<dynamic> createFeedWithImagesMultipartRepo({
    required String title,
    required String description,
    required String categoryId,
    required List<String> tags,
    required List<File> imageFiles,
  }) async {
    if (imageFiles.isEmpty) {
      throw ArgumentError('At least one image is required.');
    }
    return _network.postMultipart(
      url: AppUrl.feedCreate,
      fields: <String, dynamic>{
        'title': title.trim(),
        'description': description.trim(),
        'category': categoryId.trim(),
        'tags[]': tags,
        'status': 'Published',
      },
      files: <String, List<File>>{'images': imageFiles},
    );
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

  /// `POST /user/report/:creatorUserId` — report feed/reel/comment.
  ///
  /// Path uses the content author's user id; body `reportRef` is the target id (`Feeds`, `FeedComment`, …).
  Future<dynamic> reportFeedRepo({
    required String creatorUserId,
    required String feedId,
    required String reason,
    String? details,
    String reportRefType = 'Feeds',
  }) async {
    final userRef = creatorUserId.trim();
    final feedRef = feedId.trim();
    final body = <String, dynamic>{
      'reason': reason,
      'reportRef': feedRef,
      'reportRefType': reportRefType,
    };
    final trimmedDetails = details?.trim();
    if (trimmedDetails != null && trimmedDetails.isNotEmpty) {
      body['details'] = trimmedDetails.length > 2000 ? trimmedDetails.substring(0, 2000) : trimmedDetails;
    }
    return _network.post(AppUrl.userReport(userRef), body);
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
