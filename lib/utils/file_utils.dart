/// Categories used for download icons and "open after download" behaviour.
enum FileKind { pdf, image, video, audio, spreadsheet, document, archive, apk, other }

abstract final class FileUtils {
  static const Map<String, String> _mimeByExtension = <String, String>{
    'pdf': 'application/pdf',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'bmp': 'image/bmp',
    'heic': 'image/heic',
    'svg': 'image/svg+xml',
    'mp4': 'video/mp4',
    'mkv': 'video/x-matroska',
    'webm': 'video/webm',
    '3gp': 'video/3gpp',
    'mov': 'video/quicktime',
    'avi': 'video/x-msvideo',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'ogg': 'audio/ogg',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'csv': 'text/csv',
    'doc': 'application/msword',
    'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt': 'text/plain',
    'zip': 'application/zip',
    'rar': 'application/vnd.rar',
    '7z': 'application/x-7z-compressed',
    'tar': 'application/x-tar',
    'gz': 'application/gzip',
    'apk': 'application/vnd.android.package-archive',
  };

  static final Map<String, String> _extensionByMime = <String, String>{
    for (final MapEntry<String, String> e in _mimeByExtension.entries.toList().reversed)
      e.value: e.key,
  }..addAll(const <String, String>{'image/jpeg': 'jpg', 'application/x-zip-compressed': 'zip'});

  /// File extensions that are treated as downloadable when a link is tapped.
  static const Set<String> downloadableExtensions = <String>{
    'pdf', 'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', //
    'mp4', 'mkv', 'webm', '3gp', 'mov', 'avi', 'mp3', 'wav', 'm4a', 'ogg', //
    'xls', 'xlsx', 'csv', 'doc', 'docx', 'ppt', 'pptx', 'txt', //
    'zip', 'rar', '7z', 'tar', 'gz', 'apk',
  };

  static String extensionOf(String nameOrUrl) {
    String path = nameOrUrl;
    final Uri? uri = Uri.tryParse(nameOrUrl);
    if (uri != null && uri.hasScheme) path = uri.path;
    final int slash = path.lastIndexOf('/');
    if (slash >= 0) path = path.substring(slash + 1);
    final int dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  static String? mimeTypeOf(String nameOrUrl) => _mimeByExtension[extensionOf(nameOrUrl)];

  static String? extensionForMime(String? mimeType) {
    if (mimeType == null) return null;
    return _extensionByMime[mimeType.split(';').first.trim().toLowerCase()];
  }

  static bool isDownloadableUrl(String url) =>
      downloadableExtensions.contains(extensionOf(url));

  static bool isPdf(String nameOrUrl, {String? mimeType}) =>
      extensionOf(nameOrUrl) == 'pdf' ||
      (mimeType?.toLowerCase().contains('application/pdf') ?? false);

  static FileKind kindOf(String fileName) {
    switch (extensionOf(fileName)) {
      case 'pdf':
        return FileKind.pdf;
      case 'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' || 'heic' || 'svg':
        return FileKind.image;
      case 'mp4' || 'mkv' || 'webm' || '3gp' || 'mov' || 'avi':
        return FileKind.video;
      case 'mp3' || 'wav' || 'm4a' || 'ogg':
        return FileKind.audio;
      case 'xls' || 'xlsx' || 'csv':
        return FileKind.spreadsheet;
      case 'doc' || 'docx' || 'ppt' || 'pptx' || 'txt':
        return FileKind.document;
      case 'zip' || 'rar' || '7z' || 'tar' || 'gz':
        return FileKind.archive;
      case 'apk':
        return FileKind.apk;
      default:
        return FileKind.other;
    }
  }

  /// Derives a file name from a URL, falling back to a timestamped name.
  static String fileNameFromUrl(String url, {String? mimeType}) {
    final Uri? uri = Uri.tryParse(url);
    String name = '';
    if (uri != null && uri.pathSegments.isNotEmpty) {
      name = Uri.decodeComponent(uri.pathSegments.last);
    }
    name = sanitize(name);
    if (name.isEmpty) name = 'file_${DateTime.now().millisecondsSinceEpoch}';
    if (extensionOf(name).isEmpty) {
      final String? ext = extensionForMime(mimeType);
      if (ext != null) name = '$name.$ext';
    }
    return name;
  }

  /// Parses `attachment; filename="report.pdf"; filename*=UTF-8''report.pdf`.
  static String? fileNameFromContentDisposition(String? header) {
    if (header == null || header.isEmpty) return null;
    final RegExp extended = RegExp(r"filename\*\s*=\s*([^']*)''([^;]+)", caseSensitive: false);
    final RegExpMatch? ext = extended.firstMatch(header);
    if (ext != null) {
      final String value = sanitize(Uri.decodeComponent(ext.group(2)!.trim()));
      if (value.isNotEmpty) return value;
    }
    final RegExp plain = RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false);
    final RegExpMatch? match = plain.firstMatch(header);
    if (match != null) {
      final String value = sanitize(match.group(1)!.trim());
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  /// Removes characters that are invalid in Android file names.
  static String sanitize(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();

  /// Human readable byte size (e.g. `2.4 MB`).
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const List<String> units = <String>['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
  }
}
