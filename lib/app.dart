import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'constants/app_config.dart';
import 'core/di/app_services.dart';
import 'providers/app_stage_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/download_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'screens/auth/force_update_screen.dart';
import 'screens/auth/lock_screen.dart';
import 'screens/settings/permissions_screen.dart';
import 'screens/shell/main_shell.dart';
import 'screens/splash/splash_screen.dart';
import 'themes/app_theme.dart';

/// Root widget: dependency graph (MultiProvider) + MaterialApp.
class NexusApp extends StatelessWidget {
  const NexusApp({required this.services, super.key});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: services),
        ChangeNotifierProvider<AppStageProvider>(create: (_) => AppStageProvider()),
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider(services.settings)),
        ChangeNotifierProvider<ConnectivityProvider>(
          create: (_) => ConnectivityProvider(services.connectivity),
        ),
        ChangeNotifierProvider<NavigationProvider>(create: (_) => NavigationProvider()),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(
            settings: services.settings,
            auth: services.auth,
            biometrics: services.biometrics,
            webSession: services.webSession,
            oneSignal: services.oneSignal,
          ),
        ),
        ChangeNotifierProvider<UpdateProvider>(
          create: (_) => UpdateProvider(
            service: services.updates,
            deviceInfo: services.deviceInfo,
            settings: services.settings,
            launcher: services.launcher,
          ),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(
            repository: services.notificationsRepo,
            push: services.push,
            oneSignal: services.oneSignal,
            local: services.localNotifications,
            storage: services.storage,
          ),
        ),
        ChangeNotifierProvider<DownloadProvider>(
          create: (_) => DownloadProvider(
            service: services.downloads,
            webSession: services.webSession,
            permissions: services.permissions,
          ),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (BuildContext context, ThemeProvider theme, _) => MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          builder: (BuildContext context, Widget? child) => _SecurityLayers(child: child),
          home: const _StageRouter(),
        ),
      ),
    );
  }
}

/// Splash → (first launch) permissions → main shell.
class _StageRouter extends StatelessWidget {
  const _StageRouter();

  @override
  Widget build(BuildContext context) {
    final AppStageProvider stage = context.watch<AppStageProvider>();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: switch (stage.stage) {
        AppStage.splash => const SplashScreen(key: ValueKey<String>('splash')),
        AppStage.permissions => PermissionsScreen(
            key: const ValueKey<String>('permissions'),
            onContinue: () async {
              final AppServices services = context.read<AppServices>();
              await services.settings.setPermissionsAsked();
              await services.push.requestPermission();
              stage.finishPermissions();
            },
          ),
        AppStage.ready => MainShell(
            key: const ValueKey<String>('shell'),
            initialUrl: stage.initialUrl,
          ),
      },
    );
  }
}

/// Layers drawn above every route: force update, biometric lock and the
/// screen-recording shield.
class _SecurityLayers extends StatelessWidget {
  const _SecurityLayers({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bool ready = context.select<AppStageProvider, bool>((AppStageProvider s) => s.isReady);
    final bool forceUpdate =
        context.select<UpdateProvider, bool>((UpdateProvider u) => u.isForceUpdate);
    final bool locked = context.select<AuthProvider, bool>((AuthProvider a) => a.isLocked);
    final ValueNotifier<bool> recording = context.read<AppServices>().security.isBeingRecorded;

    return Stack(
      children: <Widget>[
        ?child,
        if (ready && locked && !forceUpdate) const Positioned.fill(child: LockScreen()),
        if (ready && forceUpdate) const Positioned.fill(child: ForceUpdateScreen()),
        ValueListenableBuilder<bool>(
          valueListenable: recording,
          builder: (BuildContext context, bool isRecording, _) => isRecording
              ? const Positioned.fill(child: _RecordingShield())
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _RecordingShield extends StatelessWidget {
  const _RecordingShield();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.videocam_off_rounded, color: Colors.white, size: 64),
              SizedBox(height: 16),
              Text(
                'Screen recording detected.\nContent is hidden for your security.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
