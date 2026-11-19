import 'dart:async';

import '../providers/auth_provider.dart';
import '../providers/update_provider.dart';
import '../utils/app_logger.dart';
import 'di/app_services.dart';

/// Result of start-up initialisation.
class BootstrapResult {
  const BootstrapResult({required this.initialUrl, required this.showPermissionOnboarding});

  final String? initialUrl;
  final bool showPermissionOnboarding;
}

/// Initialises platform services while the splash screen is visible.
///
/// Every step is isolated: a failing integration (e.g. Firebase not
/// configured, Play services missing) is logged and skipped so the app always
/// starts.
abstract final class AppBootstrapper {
  static const Duration _updateCheckBudget = Duration(seconds: 6);

  static Future<BootstrapResult> run({
    required AppServices services,
    required AuthProvider auth,
    required UpdateProvider updates,
  }) async {
    await _step('security', services.security.applyDefaultPolicy);
    await _step('connectivity', services.connectivity.start);
    await _step('local notifications', services.localNotifications.initialize);
    await _step('downloads', services.downloads.initialize);
    await _step('firebase messaging', services.push.initialize);
    await _step('onesignal', services.oneSignal.initialize);
    await _step('auth', auth.load);

    // Version check gets a bounded budget; if it finishes later the UI still
    // reacts (force-update screen is driven by UpdateProvider).
    final Future<void> updateCheck = _step('update check', updates.check);
    await Future.any<void>(<Future<void>>[updateCheck, Future<void>.delayed(_updateCheckBudget)]);

    String? initialUrl;
    await _step('launch link', () async {
      initialUrl = await services.deepLinks.initialLink() ??
          await services.push.initialMessageUrl() ??
          await services.localNotifications.launchUrl();
    });

    final bool firstLaunch = !services.settings.permissionsAsked;
    if (!firstLaunch) {
      // Android 13+: make sure notifications stay allowed after upgrades.
      await _step('notification permission', () async {
        await services.localNotifications.requestPermission();
        await services.push.requestPermission();
      });
    }

    return BootstrapResult(initialUrl: initialUrl, showPermissionOnboarding: firstLaunch);
  }

  static Future<void> _step(String name, Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e, st) {
      AppLogger.error('Bootstrap step "$name" failed', error: e, stackTrace: st);
    }
  }
}
