import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Installed app version and device details (for the About screen, the web
/// bridge and the WebView user agent).
class DeviceInfoService {
  DeviceInfoService._(this.packageInfo, this.androidInfo);

  static Future<DeviceInfoService> create() async {
    final PackageInfo package = await PackageInfo.fromPlatform();
    final AndroidDeviceInfo android = await DeviceInfoPlugin().androidInfo;
    return DeviceInfoService._(package, android);
  }

  final PackageInfo packageInfo;
  final AndroidDeviceInfo androidInfo;

  String get appVersion => packageInfo.version;

  String get buildNumber => packageInfo.buildNumber;

  String get fullVersion => '${packageInfo.version} (${packageInfo.buildNumber})';

  int get sdkInt => androidInfo.version.sdkInt;

  String get deviceName => '${androidInfo.manufacturer} ${androidInfo.model}';

  /// Suffix appended to the WebView user agent so the website can detect the app.
  String get userAgentSuffix => 'NexusConsumersApp/${packageInfo.version} (Android ${androidInfo.version.release})';

  Map<String, Object?> toJson() => <String, Object?>{
        'platform': 'android',
        'appVersion': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
        'packageName': packageInfo.packageName,
        'androidVersion': androidInfo.version.release,
        'sdkInt': androidInfo.version.sdkInt,
        'manufacturer': androidInfo.manufacturer,
        'model': androidInfo.model,
        'isPhysicalDevice': androidInfo.isPhysicalDevice,
      };
}
