import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/connectivity_service.dart';

/// Exposes online/offline state to the UI and counts reconnections so
/// WebViews can reload automatically when the connection returns.
class ConnectivityProvider extends ChangeNotifier {
  ConnectivityProvider(this._service) : _isOnline = _service.isOnline {
    _subscription = _service.onStatusChange.listen(_onChange);
  }

  final ConnectivityService _service;
  late final StreamSubscription<bool> _subscription;
  bool _isOnline;
  bool _checking = false;
  int _reconnectCount = 0;

  bool get isOnline => _isOnline;

  bool get isChecking => _checking;

  /// Incremented each time the device comes back online.
  int get reconnectCount => _reconnectCount;

  void _onChange(bool online) {
    if (online && !_isOnline) _reconnectCount++;
    _isOnline = online;
    notifyListeners();
  }

  /// Manual retry from the offline screen.
  Future<bool> retry() async {
    _checking = true;
    notifyListeners();
    final bool online = await _service.refresh();
    _checking = false;
    if (online && !_isOnline) _reconnectCount++;
    _isOnline = online;
    notifyListeners();
    return online;
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
