class AppExceptions implements Exception {
  final String? message;
  final String? prefix;

  AppExceptions([this.message, this.prefix]);

  @override
  String toString() => "${message ?? ''}${prefix ?? ''}";
}

class InternetException extends AppExceptions {
  InternetException([String? message]) : super(message, "");
}

class RequestTimeOut extends AppExceptions {
  RequestTimeOut([String? message]) : super(message, "");
}

class ServerException extends AppExceptions {
  ServerException([String? message]) : super(message, "");
}

class BadRequestException extends AppExceptions {
  BadRequestException([String? message]) : super(message, "");
}

class InvalidUrlException extends AppExceptions {
  InvalidUrlException([String? message]) : super(message, "");
}

class FetchDataException extends AppExceptions {
  FetchDataException([String? message]) : super(message, "");
}

class UnknownException extends AppExceptions {
  UnknownException([String? message]) : super(message, "");
}

class RequestCancelledException extends AppExceptions {
  RequestCancelledException([String? message]) : super(message, "");
}
