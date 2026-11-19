import 'dart:typed_data';

import 'package:consumers/constants/app_config.dart';
import 'package:consumers/core/network/secure_http_client.dart';
import 'package:consumers/models/app_notification.dart';
import 'package:consumers/models/version_info.dart';
import 'package:consumers/utils/file_utils.dart';
import 'package:consumers/utils/url_utils.dart';
import 'package:consumers/utils/version_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VersionUtils.compare', () {
    test('orders numerically, not lexically', () {
      expect(VersionUtils.compare('1.2.10', '1.2.9'), greaterThan(0));
      expect(VersionUtils.compare('1.0.0', '1.0.1'), lessThan(0));
      expect(VersionUtils.compare('2.0', '2.0.0'), 0);
    });

    test('ignores build metadata and pre-release tags', () {
      expect(VersionUtils.compare('1.0.0+12', '1.0.0+3'), 0);
      expect(VersionUtils.compare('1.0.0-beta', '1.0.0'), 0);
    });
  });

  group('VersionInfo.requirementFor', () {
    const VersionInfo info = VersionInfo(
      latestVersion: '1.3.0',
      minSupportedVersion: '1.1.0',
      storeUrl: 'https://play.google.com',
    );

    test('below minimum requires an update', () {
      expect(info.requirementFor('1.0.9'), UpdateRequirement.required);
    });

    test('between minimum and latest is optional', () {
      expect(info.requirementFor('1.2.0'), UpdateRequirement.optional);
    });

    test('latest needs nothing', () {
      expect(info.requirementFor('1.3.0'), UpdateRequirement.none);
    });

    test('parses JSON and defaults the store URL', () {
      final VersionInfo parsed =
          VersionInfo.fromJson(<String, dynamic>{'latest_version': '2.0.0'});
      expect(parsed.latestVersion, '2.0.0');
      expect(parsed.minSupportedVersion, '0.0.0');
      expect(parsed.storeUrl, AppConfig.playStoreUrl);
    });
  });

  group('FileUtils', () {
    test('detects extensions from URLs with query strings', () {
      expect(FileUtils.extensionOf('https://x.com/files/report.PDF?token=1'), 'pdf');
      expect(FileUtils.isPdf('https://x.com/a/b'), isFalse);
      expect(FileUtils.isPdf('https://x.com/a/b', mimeType: 'application/pdf'), isTrue);
    });

    test('parses Content-Disposition headers', () {
      expect(
        FileUtils.fileNameFromContentDisposition('attachment; filename="statement 2024.xlsx"'),
        'statement 2024.xlsx',
      );
      expect(
        FileUtils.fileNameFromContentDisposition("attachment; filename*=UTF-8''r%C3%A9sum%C3%A9.pdf"),
        'résumé.pdf',
      );
      expect(FileUtils.fileNameFromContentDisposition(null), isNull);
    });

    test('adds an extension from the MIME type when missing', () {
      expect(
        FileUtils.fileNameFromUrl('https://x.com/download/123', mimeType: 'application/zip'),
        '123.zip',
      );
    });

    test('sanitizes unsafe characters', () {
      expect(FileUtils.sanitize('a/b:c*?.pdf'), 'a_b_c__.pdf');
    });

    test('classifies file kinds', () {
      expect(FileUtils.kindOf('photo.jpeg'), FileKind.image);
      expect(FileUtils.kindOf('data.xlsx'), FileKind.spreadsheet);
      expect(FileUtils.kindOf('archive.zip'), FileKind.archive);
      expect(FileUtils.kindOf('clip.mp4'), FileKind.video);
    });

    test('formats byte sizes', () {
      expect(FileUtils.formatBytes(0), '0 B');
      expect(FileUtils.formatBytes(1536), '1.5 KB');
    });
  });

  group('UrlUtils', () {
    final String host = AppConfig.webHost;

    test('keeps first-party pages inside the app', () {
      expect(UrlUtils.classify(Uri.parse('https://$host/wallet')), UrlAction.internal);
      expect(UrlUtils.classify(Uri.parse('https://sub.$host/x')), UrlAction.internal);
    });

    test('hands app links to other apps', () {
      expect(UrlUtils.classify(Uri.parse('tel:+8801700000000')), UrlAction.external);
      expect(UrlUtils.classify(Uri.parse('mailto:info@example.com')), UrlAction.external);
      expect(UrlUtils.classify(Uri.parse('https://wa.me/8801700000000')), UrlAction.external);
      expect(UrlUtils.classify(Uri.parse('https://m.me/page')), UrlAction.external);
      expect(UrlUtils.classify(Uri.parse('https://www.youtube.com/watch?v=1')), UrlAction.external);
      expect(UrlUtils.classify(Uri.parse('https://www.google.com/maps/place/x')), UrlAction.external);
      expect(UrlUtils.classify(Uri.parse('https://www.facebook.com/page')), UrlAction.external);
    });

    test('blocks dangerous schemes', () {
      expect(UrlUtils.classify(Uri.parse('javascript:alert(1)')), UrlAction.block);
      expect(UrlUtils.classify(Uri.parse('file:///etc/hosts')), UrlAction.block);
    });

    test('resolves custom-scheme deep links to website URLs', () {
      expect(
        UrlUtils.resolveDeepLink('${AppConfig.deepLinkScheme}://wallet/history?tab=2'),
        '${AppConfig.baseUri.replace(path: '/wallet/history', query: 'tab=2')}',
      );
    });

    test('accepts verified https links only for the website host', () {
      expect(UrlUtils.resolveDeepLink('https://$host/team'), 'https://$host/team');
      expect(UrlUtils.resolveDeepLink('https://evil.example/team'), isNull);
    });

    test('parses Android intent URLs', () {
      final ({String? fallback, String? primary}) parsed = UrlUtils.parseIntentUrl(
        'intent://scan/#Intent;scheme=zxing;package=com.google.zxing.client.android;'
        'S.browser_fallback_url=https%3A%2F%2Fexample.com;end',
      );
      expect(parsed.primary, 'zxing://scan/');
      expect(parsed.fallback, 'https://example.com');
    });

    test('builds referral links', () {
      final Uri link = Uri.parse(UrlUtils.referralLink('ABC123'));
      expect(link.queryParameters[AppConfig.referralQueryKey], 'ABC123');
    });
  });

  group('SecureHttpClient pins', () {
    test('accepts any certificate when no pins are configured', () {
      expect(SecureHttpClient.matchesPins(Uint8List.fromList(<int>[1, 2, 3]), <String>[]), isTrue);
    });

    test('compares base64 SHA-256 fingerprints', () {
      final Uint8List der = Uint8List.fromList(<int>[1, 2, 3]);
      final String pin = SecureHttpClient.fingerprint(der);
      expect(SecureHttpClient.matchesPins(der, <String>[pin]), isTrue);
      expect(SecureHttpClient.matchesPins(der, <String>['AAAA']), isFalse);
    });
  });

  group('AppNotification', () {
    test('round-trips through JSON', () {
      final AppNotification n = AppNotification.fromPayload(
        id: '1',
        title: 'Hello',
        body: 'World',
        data: <String, dynamic>{'url': '/notice/5'},
      );
      final AppNotification copy = AppNotification.fromJson(n.toJson());
      expect(copy.id, '1');
      expect(copy.url, '/notice/5');
      expect(copy.isRead, isFalse);
      expect(copy.copyWith(isRead: true).isRead, isTrue);
    });
  });
}
