import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../repositories/notification_repository.dart';
import '../services/local_notification_service.dart';
import '../services/onesignal_service.dart';
import '../services/push_notification_service.dart';
import '../services/storage_service.dart';

/// In-app notification inbox and unread badge.
/// [refresh] is also called by the shell whenever the app resumes.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    required NotificationRepository repository,
    required PushNotificationService push,
    required OneSignalService oneSignal,
    required LocalNotificationService local,
    required StorageService storage,
  })  : _repository = repository,
        _local = local,
        _storage = storage {
    _subscriptions
      ..add(push.onInboxChanged.listen((_) => refresh()))
      ..add(oneSignal.onInboxChanged.listen((_) => refresh()));
    unawaited(refresh());
  }

  final NotificationRepository _repository;
  final LocalNotificationService _local;
  final StorageService _storage;
  final List<StreamSubscription<void>> _subscriptions = <StreamSubscription<void>>[];

  List<AppNotification> _items = const <AppNotification>[];

  List<AppNotification> get items => _items;

  int get unreadCount => _items.where((AppNotification n) => !n.isRead).length;

  /// Re-reads the inbox (also picks up messages stored by the background isolate).
  Future<void> refresh() async {
    await _storage.reload();
    _items = await _repository.getAll();
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    _items = await _repository.markRead(id);
    notifyListeners();
  }

  Future<void> markAllRead() async {
    _items = await _repository.markAllRead();
    await _local.clearAll();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _items = await _repository.remove(id);
    notifyListeners();
  }

  Future<void> clear() async {
    await _repository.clear();
    await _local.clearAll();
    _items = const <AppNotification>[];
    notifyListeners();
  }

  @override
  void dispose() {
    for (final StreamSubscription<void> s in _subscriptions) {
      unawaited(s.cancel());
    }
    super.dispose();
  }
}

