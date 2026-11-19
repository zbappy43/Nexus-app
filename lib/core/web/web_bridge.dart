import 'dart:convert';
import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/download_provider.dart';
import '../../screens/pdf/pdf_viewer_screen.dart';
import '../../screens/scanner/qr_scanner_screen.dart';
import '../../services/media_service.dart';
import '../../utils/app_logger.dart';
import '../../utils/file_utils.dart';
import '../../utils/ui_utils.dart';
import '../../utils/url_utils.dart';
import '../di/app_services.dart';

/// Registers the `window.NexusApp` JavaScript handlers on a WebView.
///
/// Handlers that expose personal data or change account state only answer
/// pages served over HTTPS from the website's own host(s).
class WebBridge {
  WebBridge({
    required this.controller,
    required this.services,
    required this.contextProvider,
    required this.onLogout,
  });

  final InAppWebViewController controller;
  final AppServices services;
  final BuildContext? Function() contextProvider;
  final Future<void> Function() onLogout;

  void register() {
    _add(JsHandlers.scanQr, _scanQr);
    _add(JsHandlers.pickImage, _pickImage);
    _add(JsHandlers.share, _share);
    _add(JsHandlers.openPdf, _openPdf);
    _add(JsHandlers.download, _download);
    _add(JsHandlers.downloadBase64, _downloadBase64);
    _add(JsHandlers.deviceInfo, (_) async => services.deviceInfo.toJson());
    _add(JsHandlers.pushToken, _secure(_pushToken));
    _add(JsHandlers.biometric, _secure(_biometric));
    _add(JsHandlers.saveCredentials, _secure(_saveCredentials));
    _add(JsHandlers.setReferralCode, _secure(_setReferralCode));
    _add(JsHandlers.setUserId, _secure(_setUserId));
    _add(JsHandlers.logout, _secure((_) async {
      await onLogout();
      return true;
    }));
  }

  void _add(String name, Future<Object?> Function(Map<String, dynamic> args) handler) {
    controller.addJavaScriptHandler(
      handlerName: name,
      callback: (List<dynamic> arguments) async {
        final Map<String, dynamic> args = arguments.isNotEmpty && arguments.first is Map
            ? Map<String, dynamic>.from(arguments.first as Map<dynamic, dynamic>)
            : <String, dynamic>{};
        try {
          return await handler(args);
        } on Object catch (e, st) {
          AppLogger.error('JS handler $name failed', error: e, stackTrace: st);
          return null;
        }
      },
    );
  }

  Future<Object?> Function(Map<String, dynamic>) _secure(
    Future<Object?> Function(Map<String, dynamic>) handler,
  ) =>
      (Map<String, dynamic> args) async {
        final WebUri? url = await controller.getUrl();
        if (url == null || url.scheme != 'https' || !UrlUtils.isFirstParty(url)) {
          AppLogger.debug('Blocked bridge call from untrusted origin: $url');
          return null;
        }
        return handler(args);
      };

  BuildContext? get _context {
    final BuildContext? context = contextProvider();
    return context != null && context.mounted ? context : null;
  }

  Future<Object?> _scanQr(Map<String, dynamic> _) async {
    final BuildContext? context = _context;
    if (context == null) return null;
    return Navigator.of(context).push<String>(QrScannerScreen.route(returnResult: true));
  }

  Future<Object?> _pickImage(Map<String, dynamic> args) async {
    final File? file = await services.media.pickImage(ImagePickOptions.fromJson(args));
    if (file == null) return null;
    final List<int> bytes = await file.readAsBytes();
    final String name = file.uri.pathSegments.last;
    final String mime = FileUtils.mimeTypeOf(name) ?? 'image/jpeg';
    return <String, Object?>{
      'dataUrl': 'data:$mime;base64,${base64Encode(bytes)}',
      'fileName': name,
      'mimeType': mime,
      'size': bytes.length,
    };
  }

  Future<Object?> _share(Map<String, dynamic> args) async {
    final String? url = args['url'] as String?;
    final String? text = args['text'] as String?;
    final String? title = args['title'] as String?;
    final String body = <String?>[text, url].whereType<String>().where((String s) => s.isNotEmpty).join('\n');
    if (body.isEmpty) {
      final WebUri? current = await controller.getUrl();
      await services.share.sharePage(url: current.toString(), title: await controller.getTitle());
    } else {
      await services.share.shareText(body, subject: title);
    }
    return true;
  }

  Future<Object?> _openPdf(Map<String, dynamic> args) async {
    final String? url = args['url'] as String?;
    final BuildContext? context = _context;
    if (url == null || context == null) return false;
    await Navigator.of(context).push<void>(PdfViewerScreen.route(url: url));
    return true;
  }

  Future<Object?> _download(Map<String, dynamic> args) async {
    final String? url = args['url'] as String?;
    final BuildContext? context = _context;
    if (url == null || context == null) return null;
    final String? taskId = await context.read<DownloadProvider>().download(
          url: url,
          suggestedFileName: args['fileName'] as String?,
        );
    final BuildContext? after = _context;
    if (after != null && after.mounted) UiUtils.showSnack(after, 'Download started');
    return taskId;
  }

  Future<Object?> _downloadBase64(Map<String, dynamic> args) async {
    final String? data = args['data'] as String?;
    final BuildContext? context = _context;
    if (data == null || context == null) return false;
    final File? file = await context.read<DownloadProvider>().saveBase64(
          base64Data: data,
          fileName: args['fileName'] as String? ?? 'download',
          mimeType: args['mimeType'] as String?,
        );
    final BuildContext? after = _context;
    if (after != null && after.mounted) {
      UiUtils.showSnack(
        after,
        file == null ? 'Download failed' : 'Saved ${file.uri.pathSegments.last}',
        actionLabel: file == null ? null : 'Open',
        onAction: file == null ? null : () => services.downloads.openWithSystem(file.path),
      );
    }
    return file != null;
  }

  Future<Object?> _pushToken(Map<String, dynamic> _) async => <String, String?>{
        'fcm': services.push.token,
        'onesignal': services.oneSignal.subscriptionId,
      };

  Future<Object?> _biometric(Map<String, dynamic> args) => services.biometrics.authenticate(
        reason: args['reason'] as String? ?? 'Confirm your identity',
      );

  Future<Object?> _saveCredentials(Map<String, dynamic> args) async {
    final BuildContext? context = _context;
    if (context == null) return false;
    await context.read<AuthProvider>().onLoginSubmitted(
          args['username'] as String? ?? '',
          args['password'] as String? ?? '',
        );
    return true;
  }

  Future<Object?> _setReferralCode(Map<String, dynamic> args) async {
    await services.settings.setReferralCode((args['code'] as String?)?.trim());
    return true;
  }

  Future<Object?> _setUserId(Map<String, dynamic> args) async {
    final String id = (args['id'] as String? ?? '').trim();
    if (id.isNotEmpty) await services.oneSignal.login(id);
    return true;
  }
}
