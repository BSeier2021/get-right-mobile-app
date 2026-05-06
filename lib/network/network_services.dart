import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:get/state_manager.dart';
import 'package:get_right/Local%20Storage/local_storage.dart';
import 'package:get_right/utils%20copy/utils.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;

class NetworkApiService extends GetxService {
  static const int _defaultTimeoutSeconds = 30;
  static const int _maxRetries = 3;
  static const String _guestAuthToken = "ab6410c710c7ce43c36e37084a4b5205b0e1608477336023a8520c9f104398f9";
  final LocalStorage localStorage = Get.put<LocalStorage>(LocalStorage());

  /// Retrieves the authorization token from local storage.
  String _getToken() {
    Utils.logInfo('Retrieving authorization token', name: 'NetworkApiService');
    final token = localStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      Utils.logError('No access token found, using guest mode', name: 'NetworkApiService');
      return _guestAuthToken;
    }
    return "Bearer $token";
  }

  /// [`Uri.replace`]'s query map must use [String] or [Iterable<String>] values.
  /// Passing [int]/[double]/[bool] throws: `type 'int' is not a subtype of type 'Iterable<dynamic>'`.
  Map<String, dynamic>? _normalizeQueryParameters(Map<String, dynamic>? params) {
    if (params == null) return null;
    final out = <String, dynamic>{};
    for (final MapEntry(:key, :value) in params.entries) {
      if (value == null) continue;
      if (value is Iterable && value is! String) {
        out[key] = value.map((dynamic x) => x.toString()).toList();
      } else {
        out[key] = value.toString();
      }
    }
    return out;
  }

  /// Default headers for all requests with optional custom headers.
  Map<String, String> _defaultHeaders({Map<String, String>? customHeaders}) {
    Utils.logInfo('Creating default headers for request', name: 'NetworkApiService');
    final headers = {'Content-Type': 'application/json'};

    // Check if we should skip Authorization header
    bool skipAuth = customHeaders != null && customHeaders.containsKey('skipAuth') && customHeaders['skipAuth'] == 'true';

    if (!skipAuth) {
      headers['Authorization'] = _getToken();
    }

    if (customHeaders != null) {
      // Remove skipAuth from headers before merging
      final headersToAdd = Map<String, String>.from(customHeaders);
      headersToAdd.remove('skipAuth');
      headers.addAll(headersToAdd);
    }
    return headers;
  }

  void _logResponse(http.Response response) {
    Utils.logSuccess("[${response.request?.method}] Request URL: ${response.request?.url}", name: "APIX");
    Utils.logInfo("Status Code: ${response.statusCode}", name: "APIX");
    Utils.logInfo("Response Headers: ${response.headers}", name: "APIX");
    // Try to decode the response body to a Map for pretty printing
    try {
      // Make sure we're getting an actual Map from the response body
      final bodyMap = jsonDecode(response.body);
      if (bodyMap is Map) {
        Utils.logSuccess("Response Body: ${bodyMap.prettyLog}", name: "APIX");
      } else {
        // If it's JSON but not a Map (e.g., it's a List or primitive)
        Utils.logSuccess("Response Body: ${JsonEncoder.withIndent('  ').convert(bodyMap)}", name: "APIX");
      }
    } catch (e) {
      // If body is not valid JSON, log as is
      Utils.logSuccess("Response Body: ${response.body}", name: "APIX");
    }
  }

  /// Extracts error message from response JSON, checking both 'error' and 'message' fields
  String _extractErrorMessage(dynamic responseJson, String defaultMessage) {
    if (responseJson is! Map<String, dynamic>) {
      return defaultMessage;
    }

    // Handle error field
    if (responseJson['error'] != null) {
      if (responseJson['error'] is String) {
        return responseJson['error'];
      } else if (responseJson['error'] is List && (responseJson['error'] as List).isNotEmpty) {
        final firstError = (responseJson['error'] as List)[0];
        if (firstError is Map && firstError['message'] != null) {
          return firstError['message'].toString();
        }
      }
    }

    // Handle message field (can be String or List)
    if (responseJson['message'] != null) {
      if (responseJson['message'] is String) {
        return responseJson['message'];
      } else if (responseJson['message'] is List && (responseJson['message'] as List).isNotEmpty) {
        final firstError = (responseJson['message'] as List)[0];
        if (firstError is Map && firstError['message'] != null) {
          return firstError['message'].toString();
        } else if (firstError is String) {
          return firstError;
        }
      }
    }

    // Handle errorMessage field
    if (responseJson['errorMessage'] != null && responseJson['errorMessage'] is String) {
      return responseJson['errorMessage'];
    }

    return defaultMessage;
  }

  /// Handles HTTP responses and processes JSON data or throws appropriate exceptions.
  dynamic _processResponse(http.Response response) {
    Utils.logInfo("Processing response with status code: ${response.statusCode}", name: "NetworkApiService");

    if (response.body.isEmpty) {
      if (response.statusCode == 204 ||
          response.statusCode == 205 ||
          (response.statusCode >= 200 && response.statusCode < 300)) {
        Utils.logSuccess("Empty body with ${response.statusCode} — treating as success", name: "NetworkApiService");
        return <String, dynamic>{'success': true};
      }
      Utils.logError("Empty response body received", name: "NetworkApiService");
      throw Exception("Empty response received");
    }

    try {
      final responseJson = jsonDecode(response.body);

      switch (response.statusCode) {
        case 200:
        case 201:
          Utils.logSuccess("Request successful with status: ${response.statusCode}", name: "NetworkApiService");
          return responseJson;
        case 400:
          final errorMsg = _extractErrorMessage(responseJson, "Bad Request");
          Utils.logError("Bad Request: $errorMsg", name: "NetworkApiService");
          throw BadRequestException(errorMsg);
        case 401:
          final errorMsg = _extractErrorMessage(responseJson, "Unauthorized");
          Utils.logError("Unauthorized: $errorMsg", name: "NetworkApiService");
          throw UnauthorizedException(errorMsg);
        case 403:
          final errorMsg = _extractErrorMessage(responseJson, "Forbidden");
          Utils.logError("Forbidden: $errorMsg", name: "NetworkApiService");
          throw ForbiddenException(errorMsg);
        case 404:
          final errorMsg = _extractErrorMessage(responseJson, "Not Found");
          Utils.logError("Not Found: $errorMsg", name: "NetworkApiService");
          throw NotFoundException(errorMsg);
        case 409:
          final errorMsg = _extractErrorMessage(responseJson, "Conflict");
          Utils.logError("Conflict: $errorMsg", name: "NetworkApiService");
          throw ConflictException(errorMsg);
        case 410:
          final errorMsg = _extractErrorMessage(responseJson, "Gone / Unauthorized Request");
          Utils.logError("Gone / Unauthorized Request: $errorMsg", name: "NetworkApiService");
          throw UnauthorizedException(errorMsg);
        case 429:
          final errorMsg = _extractErrorMessage(responseJson, "Too Many Requests");
          Utils.logError("Too Many Requests: $errorMsg", name: "NetworkApiService");
          throw TooManyRequestsException(errorMsg);
        case 500:
          final errorMsg = _extractErrorMessage(responseJson, "Internal Server Error");
          Utils.logError("Internal Server Error: $errorMsg", name: "NetworkApiService");
          throw ServerException(errorMsg);
        case 503:
          final errorMsg = _extractErrorMessage(responseJson, "Service Unavailable");
          Utils.logError("Service Unavailable: $errorMsg", name: "NetworkApiService");
          throw ServiceUnavailableException(errorMsg);
        default:
          Utils.logError("Unhandled Status Code: ${response.statusCode}", name: "NetworkApiService");
          throw UnknownException("Unhandled Status Code: ${response.statusCode}");
      }
    } catch (e) {
      if (e is FormatException) {
        Utils.logError("Failed to parse response body as JSON: ${e.message}", name: "NetworkApiService");
        throw InvalidResponseException("Invalid response format");
      }
      rethrow;
    }
  }

  /// Centralized method to send requests with retry logic and timeout handling.
  Future<dynamic> _sendRequest(Future<http.Response> Function() requestFunc, {int retryCount = 0}) async {
    try {
      Utils.logInfo("Sending network request (Attempt ${retryCount + 1})", name: "NetworkApiService");
      final response = await requestFunc().timeout(Duration(seconds: _defaultTimeoutSeconds));
      _logResponse(response);
      return _processResponse(response);
    } on SocketException {
      Utils.logError("SocketException: No Internet Connection", name: "NetworkApiService");
      throw NoInternetException("No Internet Connection");
    } on TimeoutException {
      Utils.logError("TimeoutException: Request timed out", name: "NetworkApiService");
      if (retryCount < _maxRetries) {
        Utils.logInfo("Retrying request (${retryCount + 1}/$_maxRetries)", name: "NetworkApiService");
        await Future.delayed(Duration(seconds: 2 * (retryCount + 1)));
        return _sendRequest(requestFunc, retryCount: retryCount + 1);
      }
      throw RequestTimeoutException("Request timed out");
    } catch (e) {
      Utils.logError("Exception during request: $e", name: "NetworkApiService");
      rethrow;
    }
  }

  /// Generic HTTP methods for GET, POST, PUT, DELETE, PATCH requests.
  Future<dynamic> get(String url, {Map<String, dynamic>? params, Map<String, String>? headers}) async {
    Utils.logInfo("Preparing GET request to: $url", name: "NetworkApiService");
    if (params != null) {
      Utils.logInfo("With query parameters: $params", name: "NetworkApiService");
    }

    final uri = Uri.parse(url).replace(queryParameters: _normalizeQueryParameters(params));
    return _sendRequest(() => http.get(uri, headers: _defaultHeaders(customHeaders: headers)));
  }

  Future<dynamic> post(String url, dynamic data, {Map<String, String>? headers, Map<String, dynamic>? params}) async {
    Utils.logInfo("Preparing POST request to: $url", name: "NetworkApiService");
    Utils.logInfo("Request payload: $data", name: "NetworkApiService");

    final uri = Uri.parse(url).replace(queryParameters: _normalizeQueryParameters(params));
    return _sendRequest(
      () => http.post(
        uri,
        headers: _defaultHeaders(customHeaders: headers),
        body: jsonEncode(data),
      ),
    );
  }

  Future<dynamic> postS(String url, dynamic data) async {
    return _sendRequest(() => http.post(Uri.parse(url), body: jsonEncode(data), headers: {'Content-Type': 'application/json', 'Authorization': _guestAuthToken}));
  }

  Future<dynamic> put(String url, dynamic data, {Map<String, String>? headers, Map<String, dynamic>? params}) async {
    Utils.logInfo("Preparing PUT request to: $url", name: "NetworkApiService");
    Utils.logInfo("Request payload: $data", name: "NetworkApiService");

    final uri = Uri.parse(url).replace(queryParameters: _normalizeQueryParameters(params));
    return _sendRequest(
      () => http.put(
        uri,
        headers: _defaultHeaders(customHeaders: headers),
        body: jsonEncode(data),
      ),
    );
  }

  Future<dynamic> patch(String url, dynamic data, {Map<String, String>? headers, Map<String, dynamic>? params}) async {
    Utils.logInfo("Preparing PATCH request to: $url", name: "NetworkApiService");
    Utils.logInfo("Request payload: $data", name: "NetworkApiService");

    final uri = Uri.parse(url).replace(queryParameters: _normalizeQueryParameters(params));
    return _sendRequest(
      () => http.patch(
        uri,
        headers: _defaultHeaders(customHeaders: headers),
        body: jsonEncode(data),
      ),
    );
  }

  Future<dynamic> delete(String url, {Map<String, String>? headers, Map<String, dynamic>? params}) async {
    Utils.logInfo("Preparing DELETE request to: $url", name: "NetworkApiService");

    final uri = Uri.parse(url).replace(queryParameters: _normalizeQueryParameters(params));
    return _sendRequest(() => http.delete(uri, headers: _defaultHeaders(customHeaders: headers)));
  }

  /// Multipart POST request
  Future<dynamic> postMultipart({required String url, required Map<String, dynamic> fields, required Map<String, List<File>> files, Map<String, String>? headers}) async {
    Utils.logInfo("Preparing POST multipart request to: $url", name: "NetworkApiService");
    return sendMultipart('POST', url, fields, files, headers: headers);
  }

  /// Multipart PUT request
  Future<dynamic> putMultipart({required String url, required Map<String, dynamic> fields, required Map<String, List<File>> files, Map<String, String>? headers}) async {
    Utils.logInfo("Preparing PUT multipart request to: $url", name: "NetworkApiService");
    return sendMultipart('PUT', url, fields, files, headers: headers);
  }

  /// Multipart PATCH request
  Future<dynamic> patchMultipart({required String url, required Map<String, dynamic> fields, required Map<String, List<File>> files, Map<String, String>? headers}) async {
    Utils.logInfo("Preparing PATCH multipart request to: $url", name: "NetworkApiService");
    return sendMultipart('PATCH', url, fields, files, headers: headers);
  }

  /// Handles multipart requests for POST, PUT, and PATCH methods.
  Future<dynamic> sendMultipart(String method, String url, Map<String, dynamic> fields, Map<String, List<File>> files, {Map<String, String>? headers}) async {
    Utils.logInfo("Setting up $method multipart request to: $url", name: "NetworkApiService");

    final request = http.MultipartRequest(method, Uri.parse(url))..headers.addAll(_defaultHeaders(customHeaders: headers));

    Utils.logInfo("Multipart request fields: ${fields.prettyLog}", name: "NetworkApiService");
    Utils.logInfo("Multipart request files count: ${files.entries.fold(0, (sum, entry) => sum + entry.value.length)}", name: "NetworkApiService");

    // Add form fields to the request
    fields.forEach((key, value) {
      if (value is List && key.endsWith('[]')) {
        final newKey = key.replaceFirst('[]', '');
        for (var i = 0; i < value.length; i++) {
          request.fields["$newKey[$i]"] = value[i].toString();
          Utils.logInfo("Added array field: $newKey[$i] = ${value[i]}", name: "NetworkApiService");
        }
      } else {
        request.fields[key] = value.toString();
        Utils.logInfo("Added field: $key = $value", name: "NetworkApiService");
      }
    });

    // Validate and add files to the request
    for (var entry in files.entries) {
      Utils.logInfo("Processing ${entry.value.length} files for field: ${entry.key}", name: "NetworkApiService");

      for (var file in entry.value) {
        try {
          if (file.path.isEmpty) {
            continue;
          }
          final fileSize = await file.length();
          if (fileSize > 50 * 1024 * 1024) {
            // 50MB limit
            Utils.logError("File ${file.path} exceeds size limit (50MB)", name: "NetworkApiService");
            throw FileSizeException("File exceeds size limit");
          }

          final fileStream = http.ByteStream(file.openRead());
          final fileExtension = file.path.split('.').last;
          final fileName = file.path.split('/').last;
          final contentType = _getContentType(fileExtension);

          Utils.logInfo("Adding file: $fileName, size: $fileSize bytes, type: ${contentType.mimeType}", name: "NetworkApiService");

          final multipartFile = http.MultipartFile(entry.key, fileStream, fileSize, filename: fileName, contentType: contentType);
          request.files.add(multipartFile);
          Utils.logSuccess("Successfully added file: $fileName", name: "NetworkApiService");
        } catch (e) {
          Utils.logError("Failed to add file ${file.path}: $e", name: "NetworkApiService");
          rethrow;
        }
      }
    }

    Utils.logInfo("Multipart request prepared with ${request.fields.length} fields and ${request.files.length} files", name: "NetworkApiService");

    return _sendRequest(
      () => request.send().then((streamedResponse) {
        Utils.logSuccess("Multipart request sent and stream response received", name: "NetworkApiService");
        return http.Response.fromStream(streamedResponse);
      }),
    );
  }

  /// Determines the content type based on the file extension.
  http_parser.MediaType _getContentType(String extension) {
    Utils.logInfo("Determining content type for extension: $extension", name: "NetworkApiService");

    final mediaMap = {
      'video': ['mp4', 'mov', 'avi', 'wmv'],
      'image': ['jpg', 'jpeg', 'png', 'gif', 'bmp'],
      'audio': ['mp3', 'wav', 'ogg', 'aac', 'm4a'],
      'document': ['pdf', 'doc', 'docx', 'txt', 'rtf'],
    };

    for (var entry in mediaMap.entries) {
      if (entry.value.contains(extension.toLowerCase())) {
        Utils.logSuccess("Content type determined: ${entry.key}/$extension", name: "NetworkApiService");
        return http_parser.MediaType(entry.key, extension);
      }
    }

    Utils.logInfo("Using default content type for extension: $extension", name: "NetworkApiService");
    return http_parser.MediaType("application", "octet-stream");
  }
}

/// Custom exception classes for better error handling
class BadRequestException implements Exception {
  final String message;
  BadRequestException(this.message);
  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException(this.message);
  @override
  String toString() => message;
}

class ForbiddenException implements Exception {
  final String message;
  ForbiddenException(this.message);
  @override
  String toString() => message;
}

class NotFoundException implements Exception {
  final String message;
  NotFoundException(this.message);
  @override
  String toString() => message;
}

class ConflictException implements Exception {
  final String message;
  ConflictException(this.message);
  @override
  String toString() => message;
}

class TooManyRequestsException implements Exception {
  final String message;
  TooManyRequestsException(this.message);
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
  @override
  String toString() => message;
}

class ServiceUnavailableException implements Exception {
  final String message;
  ServiceUnavailableException(this.message);
  @override
  String toString() => message;
}

class UnknownException implements Exception {
  final String message;
  UnknownException(this.message);
  @override
  String toString() => message;
}

class NoInternetException implements Exception {
  final String message;
  NoInternetException(this.message);
  @override
  String toString() => message;
}

class RequestTimeoutException implements Exception {
  final String message;
  RequestTimeoutException(this.message);
  @override
  String toString() => message;
}

class InvalidResponseException implements Exception {
  final String message;
  InvalidResponseException(this.message);
  @override
  String toString() => message;
}

class FileSizeException implements Exception {
  final String message;
  FileSizeException(this.message);
  @override
  String toString() => message;
}

extension PrettyMap on Map {
  String get prettyLog {
    final converter = JsonEncoder.withIndent('  ');
    return converter.convert(this);
  }
}
