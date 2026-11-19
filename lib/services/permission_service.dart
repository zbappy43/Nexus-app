import 'package:device_info_plus/device_info_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

/// Runtime permissions the app may request.
enum AppPermission {
  camera('Camera', 'Scan QR codes, take photos and join video calls.', Icons.photo_camera_outlined),
  microphone('Microphone', 'Record voice notes and join audio/video calls.', Icons.mic_none_rounded),
  storage('Storage', 'Save and open downloaded files on older Android versions.', Icons.folder_outlined),
  notification('Notifications', 'Receive notices, wallet and team updates.', Icons.notifications_none_rounded),
  location('Location', 'Share your location with features that need it.', Icons.location_on_outlined),
  bluetooth('Bluetooth', 'Connect to nearby printers and accessories.', Icons.bluetooth_rounded);

  const AppPermission(this.title, this.rationale, this.icon);

  final String title;
  final String rationale;
  final IconData icon;
}

/// Status shown in the permission screen.
enum AppPermissionState { granted, denied, permanentlyDenied, notRequired }

/// Maps [AppPermission]s to the correct Android permission for the running
/// SDK level and requests them.
class PermissionService {
  PermissionService({DeviceInfoPlugin? deviceInfo})
      : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  final DeviceInfoPlugin _deviceInfo;
  int? _sdkInt;

  Future<int> _sdk() async {
    if (_sdkInt != null) return _sdkInt!;
    final AndroidDeviceInfo info = await _deviceInfo.androidInfo;
    return _sdkInt = info.version.sdkInt;
  }

  /// Android permissions backing [permission] on this device; empty when the
  /// capability needs no runtime permission on this Android version.
  Future<List<Permission>> _platformPermissions(AppPermission permission) async {
    final int sdk = await _sdk();
    switch (permission) {
      case AppPermission.camera:
        return <Permission>[Permission.camera];
      case AppPermission.microphone:
        return <Permission>[Permission.microphone];
      case AppPermission.storage:
        // Android 13+: app-specific storage and the photo picker need no permission.
        return sdk >= 33 ? <Permission>[] : <Permission>[Permission.storage];
      case AppPermission.notification:
        return <Permission>[Permission.notification];
      case AppPermission.location:
        return <Permission>[Permission.locationWhenInUse];
      case AppPermission.bluetooth:
        return sdk >= 31
            ? <Permission>[Permission.bluetoothConnect, Permission.bluetoothScan]
            : <Permission>[];
    }
  }

  Future<AppPermissionState> status(AppPermission permission) async {
    final List<Permission> platform = await _platformPermissions(permission);
    if (platform.isEmpty) return AppPermissionState.notRequired;
    return _combine(<PermissionStatus>[for (final Permission p in platform) await p.status]);
  }

  Future<AppPermissionState> request(AppPermission permission) async {
    final List<Permission> platform = await _platformPermissions(permission);
    if (platform.isEmpty) return AppPermissionState.notRequired;
    final Map<Permission, PermissionStatus> result = await platform.request();
    return _combine(result.values.toList());
  }

  Future<bool> ensure(AppPermission permission) async {
    final AppPermissionState current = await status(permission);
    if (current == AppPermissionState.granted || current == AppPermissionState.notRequired) {
      return true;
    }
    if (current == AppPermissionState.permanentlyDenied) return false;
    final AppPermissionState after = await request(permission);
    return after == AppPermissionState.granted || after == AppPermissionState.notRequired;
  }

  /// Requests several permissions in one system dialog sequence.
  Future<void> requestAll(Iterable<AppPermission> permissions) async {
    final List<Permission> all = <Permission>[
      for (final AppPermission p in permissions) ...await _platformPermissions(p),
    ];
    if (all.isNotEmpty) await all.request();
  }

  Future<bool> openSettings() => openAppSettings();

  AppPermissionState _combine(List<PermissionStatus> statuses) {
    if (statuses.every((PermissionStatus s) => s.isGranted || s.isLimited)) {
      return AppPermissionState.granted;
    }
    if (statuses.any((PermissionStatus s) => s.isPermanentlyDenied || s.isRestricted)) {
      return AppPermissionState.permanentlyDenied;
    }
    return AppPermissionState.denied;
  }
}
