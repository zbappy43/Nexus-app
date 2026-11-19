import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

import '../models/version_info.dart';
import '../repositories/settings_repository.dart';
import '../services/device_info_service.dart';
import '../services/launcher_service.dart';
import '../services/update_service.dart';

/// Version check, optional/forced update and Google Play in-app updates.
///
/// Decision order:
/// 1. Website manifest says the installed version is below
///    `min_supported_version` → **force update** (blocking screen).
/// 2. Google Play reports a high-priority update (priority ≥ 4) or one older
///    than 7 days → **immediate** in-app update.
/// 3. Any other update (manifest or Play) → optional dialog; accepting starts a
///    **flexible** in-app update (or opens the Play Store for sideloaded builds).
class UpdateProvider extends ChangeNotifier {
  UpdateProvider({
    required UpdateService service,
    required DeviceInfoService deviceInfo,
    required SettingsRepository settings,
    required LauncherService launcher,
  })  : _service = service,
        _deviceInfo = deviceInfo,
        _settings = settings,
        _launcher = launcher;

  final UpdateService _service;
  final DeviceInfoService _deviceInfo;
  final SettingsRepository _settings;
  final LauncherService _launcher;
  StreamSubscription<InstallStatus>? _installSubscription;

  VersionInfo? _versionInfo;
  AppUpdateInfo? _playInfo;
  UpdateRequirement _requirement = UpdateRequirement.none;
  bool _optionalPromptPending = false;
  bool _flexibleDownloaded = false;
  bool _busy = false;

  UpdateRequirement get requirement => _requirement;
  VersionInfo? get versionInfo => _versionInfo;
  bool get isForceUpdate => _requirement == UpdateRequirement.required;
  bool get flexibleUpdateDownloaded => _flexibleDownloaded;
  bool get isBusy => _busy;
  String get installedVersion => _deviceInfo.appVersion;
  String? get latestVersion =>
      _versionInfo?.latestVersion ?? _playInfo?.availableVersionCode?.toString();

  String? get message => _versionInfo?.message;

  /// `true` once per check when the optional dialog should be shown.
  bool consumeOptionalPrompt() {
    final bool pending = _optionalPromptPending;
    _optionalPromptPending = false;
    return pending;
  }

  Future<void> check() async {
    _installSubscription ??= _service.installStatus.listen(
      (InstallStatus status) {
        if (status == InstallStatus.downloaded) {
          _flexibleDownloaded = true;
          notifyListeners();
        }
      },
      // Not available for builds that were not installed from Google Play.
      onError: (Object _) {},
    );

    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _service.fetchVersionInfo(),
      _service.checkPlayUpdate(),
    ]);
    _versionInfo = results[0] as VersionInfo?;
    _playInfo = results[1] as AppUpdateInfo?;

    _requirement = _versionInfo?.requirementFor(installedVersion) ?? UpdateRequirement.none;
    if (_requirement == UpdateRequirement.none && _playInfo != null) {
      _requirement = UpdateRequirement.optional;
    }

    if (_requirement == UpdateRequirement.optional) {
      if (_shouldRunImmediatePlayUpdate()) {
        notifyListeners();
        await _service.performImmediateUpdate();
        return;
      }
      _optionalPromptPending = _settings.skippedVersion != latestVersion;
    }
    notifyListeners();
  }

  bool _shouldRunImmediatePlayUpdate() {
    final AppUpdateInfo? info = _playInfo;
    if (info == null || !info.immediateUpdateAllowed) return false;
    return info.updatePriority >= 4 || (info.clientVersionStalenessDays ?? 0) >= 7;
  }

  /// "Update now" from the optional dialog.
  Future<void> startOptionalUpdate() async {
    _busy = true;
    notifyListeners();
    final AppUpdateInfo? info = _playInfo;
    if (info != null && info.flexibleUpdateAllowed) {
      final PlayUpdateOutcome outcome = await _service.startFlexibleUpdate();
      if (outcome == PlayUpdateOutcome.downloadedReadyToInstall) _flexibleDownloaded = true;
      if (outcome == PlayUpdateOutcome.failed) await _openStore();
    } else {
      await _openStore();
    }
    _busy = false;
    notifyListeners();
  }

  /// "Update now" from the blocking force-update screen.
  Future<void> startForcedUpdate() async {
    _busy = true;
    notifyListeners();
    final AppUpdateInfo? info = _playInfo;
    final PlayUpdateOutcome outcome = info != null && info.immediateUpdateAllowed
        ? await _service.performImmediateUpdate()
        : PlayUpdateOutcome.notAvailable;
    if (outcome != PlayUpdateOutcome.started) await _openStore();
    _busy = false;
    notifyListeners();
  }

  Future<void> skipOptionalUpdate() async {
    final String? latest = latestVersion;
    if (latest != null) await _settings.setSkippedVersion(latest);
  }

  Future<void> installDownloadedUpdate() => _service.completeFlexibleUpdate();

  Future<void> _openStore() async {
    final String? url = _versionInfo?.storeUrl;
    if (url != null && !url.contains('play.google.com')) {
      await _launcher.openExternal(url);
    } else {
      await _launcher.openPlayStore();
    }
  }

  @override
  void dispose() {
    unawaited(_installSubscription?.cancel());
    super.dispose();
  }
}
