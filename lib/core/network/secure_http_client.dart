import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../constants/app_config.dart';
import '../../utils/url_utils.dart';
import '../errors/app_exception.dart';

/// Result of a streamed file download.
class DownloadedFile {
  const DownloadedFile({required this.file, required this.contentType});

  final File file;
  final String? contentType;
}

/// HTTPS client used for every native request made by the app.
///
/// * Plain-text HTTP is rejected.
/// * When [AppConfig.sslPins] is non-empty, the certificate presented by a
///   first-party host must match one of the pins (base64 SHA-256 of the DER
///   encoded certificate), otherwise a [CertificatePinningException] is thrown
///   before any response body is read.
class SecureHttpClient {
  SecureHttpClient({List<String>? pins}) : _pins = pins ?? AppConfig.sslPins;

  final List<String> _pins;

  HttpClient _newClient() => HttpClient()
    ..connectionTimeout = AppConfig.httpTimeout
    ..idleTimeout = const Duration(seconds: 10)
    ..userAgent = '${AppConfig.shortName} Android';

  /// Base64 SHA-256 fingerprint of a DER certificate.
  static String fingerprint(Uint8List der) => base64.encode(sha256.convert(der).bytes);

  /// Returns `true` when pinning is disabled or [der] matches a pin.
  static bool matchesPins(Uint8List der, List<String> pins) =>
      pins.isEmpty || pins.contains(fingerprint(der));

  void _verify(Uri uri, HttpClientResponse response) {
    if (_pins.isEmpty || !UrlUtils.isFirstParty(uri)) return;
    final X509Certificate? cert = response.certificate;
    if (cert == null || !matchesPins(cert.der, _pins)) {
      throw CertificatePinningException(uri.host);
    }
  }

  Future<HttpClientResponse> _send(
    HttpClient client,
    Uri uri,
    Map<String, String> headers,
  ) async {
    if (uri.scheme != 'https') {
      throw const ServerException('Only HTTPS connections are allowed.');
    }
    try {
      final HttpClientRequest request =
          await client.getUrl(uri).timeout(AppConfig.httpTimeout);
      headers.forEach(request.headers.set);
      final HttpClientResponse response =
          await request.close().timeout(AppConfig.httpTimeout);
      _verify(uri, response);
      return response;
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } on TimeoutException {
      throw const NetworkException('The connection timed out.');
    } on HandshakeException catch (e) {
      throw ServerException('Secure connection failed: ${e.message}');
    }
  }

  /// Performs a GET request and decodes a JSON object body.
  Future<Map<String, dynamic>> getJson(
    String url, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final HttpClient client = _newClient();
    try {
      final HttpClientResponse response = await _send(
        client,
        Uri.parse(url),
        <String, String>{'Accept': 'application/json', ...headers},
      );
      final String body = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ServerException('HTTP ${response.statusCode}', statusCode: response.statusCode);
      }
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const ServerException('Unexpected response format.');
      }
      return decoded;
    } finally {
      client.close();
    }
  }

  /// Streams [url] into [target], reporting progress in the range 0..1.
  Future<DownloadedFile> download(
    String url,
    File target, {
    Map<String, String> headers = const <String, String>{},
    void Function(double progress)? onProgress,
  }) async {
    final HttpClient client = _newClient();
    try {
      final HttpClientResponse response = await _send(client, Uri.parse(url), headers);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ServerException('HTTP ${response.statusCode}', statusCode: response.statusCode);
      }
      await target.parent.create(recursive: true);
      final IOSink sink = target.openWrite();
      final int total = response.contentLength;
      int received = 0;
      try {
        await for (final List<int> chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
      } finally {
        await sink.close();
      }
      onProgress?.call(1);
      return DownloadedFile(file: target, contentType: response.headers.contentType?.mimeType);
    } finally {
      client.close();
    }
  }
}
