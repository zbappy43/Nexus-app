/// Keys, channel names and other non-configurable constants.
abstract final class StorageKeys {
  static const String themeMode = 'settings.theme_mode';
  static const String biometricEnabled = 'settings.biometric_enabled';
  static const String rememberLogin = 'settings.remember_login';
  static const String autoLogin = 'settings.auto_login';
  static const String notificationsEnabled = 'settings.notifications_enabled';
  static const String onboardingPermissionsAsked = 'settings.permissions_asked';
  static const String referralCode = 'user.referral_code';
  static const String notificationInbox = 'notifications.inbox';
  static const String skippedVersion = 'update.skipped_version';

  // Secure storage (encrypted) keys.
  static const String secureUsername = 'secure.login.username';
  static const String securePassword = 'secure.login.password';
  static const String secureFcmToken = 'secure.push.fcm_token';
}

abstract final class NativeChannels {
  static const String security = 'com.nexus.consumers/security';
  static const String deepLinks = 'com.nexus.consumers/deeplinks';
}

abstract final class NotificationChannels {
  static const String generalId = 'nexus_general';
  static const String generalName = 'General notifications';
  static const String generalDescription = 'Announcements, notices and account activity.';

  static const String downloadsId = 'nexus_downloads';
  static const String downloadsName = 'Downloads';
  static const String downloadsDescription = 'Download progress and completion.';

  /// Small icon drawable (android/app/src/main/res/drawable/ic_stat_notification.xml).
  static const String smallIcon = 'ic_stat_notification';
}

/// Names of JavaScript handlers exposed to the website through
/// `window.NexusApp` (see `assets/js/nexus_bridge.js`).
abstract final class JsHandlers {
  static const String scanQr = 'nexusScanQr';
  static const String pickImage = 'nexusPickImage';
  static const String share = 'nexusShare';
  static const String openPdf = 'nexusOpenPdf';
  static const String download = 'nexusDownload';
  static const String downloadBase64 = 'nexusDownloadBase64';
  static const String deviceInfo = 'nexusDeviceInfo';
  static const String pushToken = 'nexusPushToken';
  static const String biometric = 'nexusBiometric';
  static const String saveCredentials = 'nexusSaveCredentials';
  static const String setReferralCode = 'nexusSetReferralCode';
  static const String setUserId = 'nexusSetUserId';
  static const String logout = 'nexusLogout';
}
