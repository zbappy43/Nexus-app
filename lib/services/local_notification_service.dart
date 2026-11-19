import 'dart:async';
import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../models/app_notification.dart';
import '../utils/app_logger.dart';

/// Displays notifications on the device (foreground FCM messages, data-only
/// messages, download events) and reports taps.
class LocalNotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<String> _taps = StreamController<String>.broadcast();
  Future<void>? _initialization;

  /// Emits the URL attached to a tapped notification.
  Stream<String> get onTapUrl => _taps.stream;

  static const AndroidNotificationChannel generalChannel = AndroidNotificationChannel(
    NotificationChannels.generalId,
    NotificationChannels.generalName,
    description: NotificationChannels.generalDescription,
    importance: Importance.high,
    showBadge: true,
  );

  static const AndroidNotificationChannel downloadsChannel = AndroidNotificationChannel(
    NotificationChannels.downloadsId,
    NotificationChannels.downloadsName,
    description: NotificationChannels.downloadsDescription,
    importance: Importance.low,
    showBadge: false,
  );

  /// Safe to call repeatedly / concurrently.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(NotificationChannels.smallIcon),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(generalChannel);
    await android?.createNotificationChannel(downloadsChannel);
  }

  void _onResponse(NotificationResponse response) {
    final String? url = urlFromPayload(response.payload);
    if (url != null) _taps.add(url);
  }

  static String? urlFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(payload);
      if (decoded is Map && decoded['url'] is String) {
        final String url = decoded['url'] as String;
        return url.isEmpty ? null : url;
      }
    } on FormatException {
      return payload.startsWith('http') ? payload : null;
    }
    return null;
  }

  /// URL of the notification that cold-started the app, if any.
  Future<String?> launchUrl() async {
    final NotificationAppLaunchDetails? details =
        await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return urlFromPayload(details.notificationResponse?.payload);
  }

  Future<bool> requestPermission() async {
    final AndroidFlutterLocalNotificationsPlugin? android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  /// Shows [notification]; [badgeCount] is the unread count shown on
  /// launchers that support numeric badges.
  Future<void> show(AppNotification notification, {int? badgeCount}) async {
    try {
      await initialize();
      await _plugin.show(
        id: notification.id.hashCode & 0x7fffffff,
        title: notification.title,
        body: notification.body,
        payload: jsonEncode(<String, String?>{'url': notification.url, 'id': notification.id}),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            generalChannel.id,
            generalChannel.name,
            channelDescription: generalChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            color: AppColors.primary,
            icon: NotificationChannels.smallIcon,
            number: badgeCount,
            channelShowBadge: true,
            styleInformation: BigTextStyleInformation(
              notification.body,
              contentTitle: notification.title,
            ),
          ),
        ),
      );
    } on Object catch (e, st) {
      AppLogger.error('Failed to show notification', error: e, stackTrace: st);
    }
  }

  Future<void> clearAll() => _plugin.cancelAll();
}
