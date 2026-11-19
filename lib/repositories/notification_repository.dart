import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../models/app_notification.dart';

/// Persists received notifications (the in-app inbox) so the bell icon can
/// show an unread badge and the user can revisit past messages.
///
/// Uses [SharedPreferences] directly so it also works from the FCM background
/// isolate, where the app's service graph does not exist.
class NotificationRepository {
  static const int _maxItems = 100;

  Future<List<AppNotification>> getAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return _decode(prefs.getString(StorageKeys.notificationInbox));
  }

  Future<int> unreadCount() async =>
      (await getAll()).where((AppNotification n) => !n.isRead).length;

  /// Adds (or replaces, by id) a notification at the top of the inbox.
  Future<List<AppNotification>> add(AppNotification notification) async {
    final List<AppNotification> items = await getAll();
    items
      ..removeWhere((AppNotification n) => n.id == notification.id)
      ..insert(0, notification);
    if (items.length > _maxItems) items.removeRange(_maxItems, items.length);
    await _save(items);
    return items;
  }

  Future<List<AppNotification>> markRead(String id) async {
    final List<AppNotification> items = (await getAll())
        .map((AppNotification n) => n.id == id ? n.copyWith(isRead: true) : n)
        .toList();
    await _save(items);
    return items;
  }

  Future<List<AppNotification>> markAllRead() async {
    final List<AppNotification> items =
        (await getAll()).map((AppNotification n) => n.copyWith(isRead: true)).toList();
    await _save(items);
    return items;
  }

  Future<List<AppNotification>> remove(String id) async {
    final List<AppNotification> items = (await getAll())
      ..removeWhere((AppNotification n) => n.id == id);
    await _save(items);
    return items;
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.notificationInbox);
  }

  Future<void> _save(List<AppNotification> items) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      StorageKeys.notificationInbox,
      jsonEncode(items.map((AppNotification n) => n.toJson()).toList()),
    );
  }

  List<AppNotification> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return <AppNotification>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <AppNotification>[];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AppNotification.fromJson)
          .toList();
    } on FormatException {
      return <AppNotification>[];
    }
  }
}
