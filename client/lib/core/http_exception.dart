/// Thrown when an HTTP call to our backend returns a non-2xx response.
/// Carries the raw status + body so caller can branch on it (e.g. 401 → sign out).
class HttpException implements Exception {
  final int? statusCode;
  final String message;

  HttpException(this.message, {this.statusCode});

  @override
  String toString() => statusCode != null ? 'HTTP $statusCode: $message' : message;
}
