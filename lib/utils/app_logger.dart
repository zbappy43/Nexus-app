import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Lightweight logger. Output is stripped from release builds.
abstract final class AppLogger {
  static void debug(String message, {String tag = 'Nexus'}) {
    if (kReleaseMode) return;
    developer.log(message, name: tag);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String tag = 'Nexus',
  }) {
    if (kReleaseMode) return;
    developer.log(message, name: tag, error: error, stackTrace: stackTrace, level: 1000);
  }
}
