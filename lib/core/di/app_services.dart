import '../../repositories/auth_repository.dart';
import '../../repositories/notification_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../services/biometric_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/deep_link_service.dart';
import '../../services/device_info_service.dart';
import '../../services/download_service.dart';
import '../../services/launcher_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/media_service.dart';
import '../../services/onesignal_service.dart';
import '../../services/permission_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/security_service.dart';
import '../../services/share_service.dart';
import '../../services/storage_service.dart';
import '../../services/update_service.dart';
import '../../services/web_session_service.dart';
import '../network/secure_http_client.dart';

/// Composition root: creates every service and repository exactly once.
///
/// Only work that must finish before the first frame happens in [create];
/// network-bound initialisation runs later in `AppBootstrapper`.
class AppServices {
  AppServices._({
    required this.storage,
    required this.deviceInfo,
    required this.settings,
    required this.auth,
    required this.notificationsRepo,
    required this.connectivity,
    required this.security,
    required this.deepLinks,
    required this.launcher,
    required this.localNotifications,
    required this.push,
    required this.oneSignal,
    required this.downloads,
    required this.biometrics,
    required this.permissions,
    required this.updates,
    required this.media,
    required this.share,
    required this.webSession,
    required this.http,
  });

  static Future<AppServices> create() async {
    final StorageService storage = await StorageService.create();
    final DeviceInfoService deviceInfo = await DeviceInfoService.create();
    final NotificationRepository notificationsRepo = NotificationRepository();
    final LocalNotificationService localNotifications = LocalNotificationService();
    final PermissionService permissions = PermissionService();
    final SecureHttpClient http = SecureHttpClient();
    return AppServices._(
      storage: storage,
      deviceInfo: deviceInfo,
      settings: SettingsRepository(storage),
      auth: AuthRepository(storage),
      notificationsRepo: notificationsRepo,
      connectivity: ConnectivityService(),
      security: SecurityService(),
      deepLinks: DeepLinkService(),
      launcher: LauncherService(),
      localNotifications: localNotifications,
      push: PushNotificationService(
        localNotifications: localNotifications,
        repository: notificationsRepo,
      ),
      oneSignal: OneSignalService(repository: notificationsRepo),
      downloads: DownloadService(),
      biometrics: BiometricService(),
      permissions: permissions,
      updates: UpdateService(httpClient: http),
      media: MediaService(permissions: permissions),
      share: ShareService(),
      webSession: WebSessionService(),
      http: http,
    );
  }

  final StorageService storage;
  final DeviceInfoService deviceInfo;
  final SettingsRepository settings;
  final AuthRepository auth;
  final NotificationRepository notificationsRepo;
  final ConnectivityService connectivity;
  final SecurityService security;
  final DeepLinkService deepLinks;
  final LauncherService launcher;
  final LocalNotificationService localNotifications;
  final PushNotificationService push;
  final OneSignalService oneSignal;
  final DownloadService downloads;
  final BiometricService biometrics;
  final PermissionService permissions;
  final UpdateService updates;
  final MediaService media;
  final ShareService share;
  final WebSessionService webSession;
  final SecureHttpClient http;
}
