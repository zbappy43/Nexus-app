import 'package:flutter/foundation.dart';

import '../constants/app_config.dart';
import '../utils/version_utils.dart';

/// Result of comparing the installed version with the remote version manifest.
enum UpdateRequirement { none, optional, required }

@immutable
class VersionInfo {
  const VersionInfo({
    required this.latestVersion,
    required this.minSupportedVersion,
    required this.storeUrl,
    this.message,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    final String latest = (json['latest_version'] ?? json['version'] ?? '0.0.0').toString();
    return VersionInfo(
      latestVersion: latest,
      minSupportedVersion: (json['min_supported_version'] ?? json['min_version'] ?? '0.0.0').toString(),
      message: json['message'] as String?,
      storeUrl: (json['store_url'] as String?)?.trim().isNotEmpty == true
          ? json['store_url'] as String
          : AppConfig.playStoreUrl,
    );
  }

  final String latestVersion;
  final String minSupportedVersion;
  final String? message;
  final String storeUrl;

  UpdateRequirement requirementFor(String installedVersion) {
    if (VersionUtils.compare(installedVersion, minSupportedVersion) < 0) {
      return UpdateRequirement.required;
    }
    if (VersionUtils.compare(installedVersion, latestVersion) < 0) {
      return UpdateRequirement.optional;
    }
    return UpdateRequirement.none;
  }
}
