import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../constants/app_config.dart';
import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../utils/app_logger.dart';

/// OneSignal push integration.
///
/// Active only when `ONESIGNAL_APP_ID` is supplied at build time. OneSignal
/// displays its notifications itself; this service records them in the inbox,
/// routes taps to the WebView and links the device to the signed-in user.
class OneSignalService {
  OneSignalService({required NotificationRepository repository}) : _repository = repository;

  final NotificationRepository _repository;
  final StreamController<String> _openUrl = StreamController<String>.broadcast();
  final StreamController<void> _inboxChanged = StreamController<void>.broadcast();
  bool _initialized = false;

  bool get isEnabled => AppConfig.oneSignalAppId.isNotEmpty;

  Stream<String> get onOpenUrl => _openUrl.stream;

  Stream<void> get onInboxChanged => _inboxChanged.stream;

  Future<void> initialize() async {
    if (!isEnabled || _initialized) return;
    try {
      await OneSignal.Debug.setLogLevel(kReleaseMode ? OSLogLevel.none : OSLogLevel.warn);
      await OneSignal.initialize(AppConfig.oneSignalAppId);
      OneSignal.Notifications.addForegroundWillDisplayListener(
        (OSNotificationWillDisplayEvent event) {
          unawaited(_record(event.notification, read: false));
          // Let OneSignal display it while the app is in the foreground.
          event.notification.display();
        },
      );
      OneSignal.Notifications.addClickListener((OSNotificationClickEvent event) {
        unawaited(_record(event.notification, read: true));
        final String? url = event.notification.launchUrl ??
            event.notification.additionalData?['url'] as String?;
        if (url != null && url.isNotEmpty) _openUrl.add(url);
      });
      _initialized = true;
    } on Object catch (e, st) {
      AppLogger.error('OneSignal initialisation failed', error: e, stackTrace: st);
    }
  }

  Future<void> _record(OSNotification n, {required bool read}) async {
    final AppNotification notification = AppNotification.fromPayload(
      id: n.notificationId,
      title: n.title,
      body: n.body,
      imageUrl: n.bigPicture,
      data: <String, dynamic>{
        ...?n.additionalData,
        if (n.launchUrl != null) 'url': n.launchUrl,
      },
    );
    await _repository.add(notification.copyWith(isRead: read));
    _inboxChanged.add(null);
  }

  Future<void> requestPermission() async {
    if (!_initialized) return;
    await OneSignal.Notifications.requestPermission(true);
  }

  /// Associates this device with the website's user id (external id).
  Future<void> login(String externalUserId) async {
    if (!_initialized || externalUserId.isEmpty) return;
    await OneSignal.login(externalUserId);
  }

  Future<void> logout() async {
    if (!_initialized) return;
    await OneSignal.logout();
  }

  String? get subscriptionId => _initialized ? OneSignal.User.pushSubscription.id : null;
}
