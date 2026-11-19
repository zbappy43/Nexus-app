/// Base type for errors surfaced to the UI layer.
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection.']);
}

class ServerException extends AppException {
  const ServerException(super.message, {this.statusCode});

  final int? statusCode;
}

/// Thrown when a server certificate does not match the configured pins.
class CertificatePinningException extends AppException {
  const CertificatePinningException(this.host)
      : super('Certificate pinning failed for $host.');

  final String host;
}

class PermissionDeniedException extends AppException {
  const PermissionDeniedException(super.message);
}
