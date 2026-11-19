import 'package:share_plus/share_plus.dart';

import '../constants/app_config.dart';
import '../utils/url_utils.dart';

/// System share sheet for pages, referral links, the app listing and files.
class ShareService {
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }

  Future<void> sharePage({required String url, String? title}) => shareText(
        title == null || title.trim().isEmpty ? url : '${title.trim()}\n$url',
        subject: title,
      );

  Future<void> shareReferral(String? referralCode) => shareText(
        'Join me on ${AppConfig.appName}! Sign up with my referral link:\n'
        '${UrlUtils.referralLink(referralCode)}',
        subject: 'Join ${AppConfig.appName}',
      );

  Future<void> shareApp() => shareText(
        'Get the ${AppConfig.appName} app on Google Play:\n${AppConfig.playStoreUrl}',
        subject: AppConfig.appName,
      );

  Future<void> shareFile(String path, {String? text}) async {
    await SharePlus.instance.share(ShareParams(files: <XFile>[XFile(path)], text: text));
  }
}
