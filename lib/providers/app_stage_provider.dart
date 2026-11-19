import 'package:flutter/foundation.dart';

/// Top-level lifecycle of the UI.
enum AppStage { splash, permissions, ready }

class AppStageProvider extends ChangeNotifier {
  AppStage _stage = AppStage.splash;
  String? _initialUrl;

  AppStage get stage => _stage;

  bool get isReady => _stage == AppStage.ready;

  /// Deep link / notification URL that launched the app.
  String? get initialUrl => _initialUrl;

  void finishSplash({required bool showPermissions, String? initialUrl}) {
    _initialUrl = initialUrl;
    _stage = showPermissions ? AppStage.permissions : AppStage.ready;
    notifyListeners();
  }

  void finishPermissions() {
    _stage = AppStage.ready;
    notifyListeners();
  }
}
