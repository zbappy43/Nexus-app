import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../constants/app_config.dart';

/// Emits `true` when the device has a working internet connection.
///
/// `connectivity_plus` only reports the network interface state, so every
/// change is confirmed with a DNS lookup of the website host. While offline the
/// service re-probes periodically to reconnect automatically even when the
/// interface state does not change (captive portals, flaky mobile data).
class ConnectivityService {
  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _retryTimer;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> start() async {
    _subscription ??= _connectivity.onConnectivityChanged.listen(_onInterfaceChanged);
    await refresh();
  }

  Future<bool> refresh() async {
    final List<ConnectivityResult> results = await _connectivity.checkConnectivity();
    return _evaluate(results);
  }

  Future<void> _onInterfaceChanged(List<ConnectivityResult> results) async {
    await _evaluate(results);
  }

  Future<bool> _evaluate(List<ConnectivityResult> results) async {
    final bool hasInterface =
        results.any((ConnectivityResult r) => r != ConnectivityResult.none);
    final bool online = hasInterface && await _hasInternet();
    _update(online);
    return online;
  }

  Future<bool> _hasInternet() async {
    final List<String> hosts = <String>[
      if (AppConfig.webHost.isNotEmpty) AppConfig.webHost,
      'google.com',
    ];
    for (final String host in hosts) {
      try {
        final List<InternetAddress> result =
            await InternetAddress.lookup(host).timeout(const Duration(seconds: 5));
        if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) return true;
      } on Object {
        continue;
      }
    }
    return false;
  }

  void _update(bool online) {
    if (online) {
      _retryTimer?.cancel();
      _retryTimer = null;
    } else {
      _retryTimer ??= Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    }
    if (online == _isOnline) return;
    _isOnline = online;
    _controller.add(online);
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    await _subscription?.cancel();
    await _controller.close();
  }
}
