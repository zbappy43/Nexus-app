import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../utils/app_logger.dart';
import 'local_notification_service.dart';

AppNotification _toAppNotification(RemoteMessage message) => AppNotification.fromPayload(
      id: message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}',
      title: message.notification?.title,
      body: message.notification?.body,
      imageUrl: message.notification?.android?.imageUrl,
      data: message.data,
    );

/// FCM background / terminated-state handler. Runs in its own isolate.
///
/// * Messages with a `notification` block are displayed by the system tray
///   automatically; they are only recorded in the inbox here.
/// * Data-only messages are recorded and displayed as a local notification.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } on Object {
    return;
  }
  final AppNotification notification = _toAppNotification(message);
  final NotificationRepository repository = NotificationRepository();
  final List<AppNotification> inbox = await repository.add(notification);
  if (message.notification == null && notification.title.isNotEmpty) {
    final int unread = inbox.where((AppNotification n) => !n.isRead).length;
    await LocalNotificationService().show(notification, badgeCount: unread);
  }
}

/// Firebase Cloud Messaging integration (foreground, background, taps, token).
class PushNotificationService {
  PushNotificationService({
    required LocalNotificationService localNotifications,
    required NotificationRepository repository,
  })  : _local = localNotifications,
        _repository = repository;

  final LocalNotificationService _local;
  final NotificationRepository _repository;

  final StreamController<String> _openUrl = StreamController<String>.broadcast();
  final StreamController<void> _inboxChanged = StreamController<void>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = <StreamSubscription<Object?>>[];

  bool _available = false;
  String? _token;

  /// Whether Firebase was configured (google-services.json present).
  bool get isAvailable => _available;

  /// Firebase Installation ID used as the FCM direct-send target.
  String? get token => _token;

  /// URLs to open after the user taps a push notification.
  Stream<String> get onOpenUrl => _openUrl.stream;

  /// Fires whenever a message was added to the inbox.
  Stream<void> get onInboxChanged => _inboxChanged.stream;

  /// Initialises Firebase. Returns `false` when the app was built without
  /// `google-services.json`; the rest of the app keeps working.
  Future<bool> initialize() async {
    try {
      await Firebase.initializeApp();
    } on Object catch (e) {
      AppLogger.debug('Firebase not configured: $e');
      _available = false;
      return false;
    }
    _available = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);

    _subscriptions
      ..add(FirebaseMessaging.onMessage.listen(_onForegroundMessage))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened))
      ..add(messaging.onRegistered.listen((String id) => _token = id));

    try {
      // Registration completes asynchronously; the id arrives via onRegistered.
      await messaging.register();
      await messaging.subscribeToTopic('all_users');
    } on Object catch (e) {
      AppLogger.debug('FCM token unavailable: $e');
    }
    return true;
  }

  /// URL of the push notification that launched the app from terminated state.
  Future<String?> initialMessageUrl() async {
    if (!_available) return null;
    final RemoteMessage? message = await FirebaseMessaging.instance.getInitialMessage();
    if (message == null) return null;
    await _repository.add(_toAppNotification(message));
    _inboxChanged.add(null);
    return _toAppNotification(message).url;
  }

  Future<void> requestPermission() async {
    if (!_available) return;
    await FirebaseMessaging.instance.requestPermission();
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final AppNotification notification = _toAppNotification(message);
    final List<AppNotification> inbox = await _repository.add(notification);
    _inboxChanged.add(null);
    if (notification.title.isEmpty && notification.body.isEmpty) return;
    final int unread = inbox.where((AppNotification n) => !n.isRead).length;
    await _local.show(notification, badgeCount: unread);
  }

  Future<void> _onMessageOpened(RemoteMessage message) async {
    final AppNotification notification = _toAppNotification(message);
    await _repository.add(notification.copyWith(isRead: true));
    _inboxChanged.add(null);
    final String? url = notification.url;
    if (url != null && url.isNotEmpty) _openUrl.add(url);
  }

  Future<void> dispose() async {
    for (final StreamSubscription<Object?> s in _subscriptions) {
      await s.cancel();
    }
    await _openUrl.close();
    await _inboxChanged.close();
  }
}
