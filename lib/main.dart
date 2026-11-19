import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'constants/app_colors.dart';
import 'core/di/app_services.dart';
import 'core/web/web_assets.dart';
import 'utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) FlutterError.presentError(details);
    AppLogger.error('Flutter error', error: details.exception, stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.error('Uncaught error', error: error, stackTrace: stack);
    return true;
  };
  if (kReleaseMode) {
    // Never show red error screens to users.
    ErrorWidget.builder = (FlutterErrorDetails details) => const ColoredBox(
          color: AppColors.lightBackground,
          child: Center(child: Icon(Icons.error_outline_rounded, color: AppColors.primary, size: 40)),
        );
  }

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final AppServices services = await AppServices.create();
  await WebAssets.load();

  runApp(NexusApp(services: services));
}
