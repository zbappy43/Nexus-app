import 'package:material_ui/material_ui.dart';

import '../repositories/settings_repository.dart';

/// System / Light / Dark theme selection.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider(this._settings) : _mode = _settings.themeMode;

  final SettingsRepository _settings;
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _settings.setThemeMode(mode);
  }
}
