import 'dart:async';

import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';

import '../constants/app_config.dart';
import '../core/network/secure_http_client.dart';
import '../models/version_info.dart';
import '../utils/app_logger.dart';

/// Outcome of a Google Play in-app update attempt.
enum PlayUpdateOutcome { notAvailable, started, downloadedReadyToInstall, declined, failed }

/// Version checking against the website manifest and Google Play In-App Updates.
class UpdateService {
  UpdateService({SecureHttpClient? httpClient}) : _http = httpClient ?? SecureHttpClient();

  final SecureHttpClient _http;

  /// Fetches the remote version manifest (see [AppConfig.versionCheckUrl]).
  /// Returns `null` when the manifest is unreachable or malformed, so the app
  /// never blocks users because of a server problem.
  Future<VersionInfo?> fetchVersionInfo() async {
    try {
      final Map<String, dynamic> json = await _http.getJson(AppConfig.versionCheckUrl);
      return VersionInfo.fromJson(json);
    } on Object catch (e) {
      AppLogger.debug('Version manifest unavailable: $e');
      return null;
    }
  }

  /// Queries Google Play for an update. Only works for Play-installed builds.
  Future<AppUpdateInfo?> checkPlayUpdate() async {
    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      return info.updateAvailability == UpdateAvailability.updateAvailable ||
              info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress
          ? info
          : null;
    } on PlatformException catch (e) {
      // ERROR_APP_NOT_OWNED / ERROR_API_NOT_AVAILABLE for sideloaded builds.
      AppLogger.debug('Play in-app update unavailable: ${e.code}');
      return null;
    }
  }

  /// Full-screen blocking update handled by Google Play.
  Future<PlayUpdateOutcome> performImmediateUpdate() async {
    try {
      final AppUpdateResult result = await InAppUpdate.performImmediateUpdate();
      return switch (result) {
        AppUpdateResult.success => PlayUpdateOutcome.started,
        AppUpdateResult.userDeniedUpdate => PlayUpdateOutcome.declined,
        AppUpdateResult.inAppUpdateFailed => PlayUpdateOutcome.failed,
      };
    } on PlatformException {
      return PlayUpdateOutcome.failed;
    }
  }

  /// Background download while the user keeps using the app.
  Future<PlayUpdateOutcome> startFlexibleUpdate() async {
    try {
      final AppUpdateResult result = await InAppUpdate.startFlexibleUpdate();
      return switch (result) {
        AppUpdateResult.success => PlayUpdateOutcome.downloadedReadyToInstall,
        AppUpdateResult.userDeniedUpdate => PlayUpdateOutcome.declined,
        AppUpdateResult.inAppUpdateFailed => PlayUpdateOutcome.failed,
      };
    } on PlatformException {
      return PlayUpdateOutcome.failed;
    }
  }

  /// Installs a downloaded flexible update (restarts the app).
  Future<void> completeFlexibleUpdate() async {
    try {
      await InAppUpdate.completeFlexibleUpdate();
    } on PlatformException catch (e) {
      AppLogger.debug('completeFlexibleUpdate failed: ${e.code}');
    }
  }

  Stream<InstallStatus> get installStatus => InAppUpdate.installUpdateListener;
}
