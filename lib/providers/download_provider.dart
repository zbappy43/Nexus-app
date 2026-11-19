import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import '../models/download_item.dart';
import '../services/download_service.dart';
import '../services/permission_service.dart';
import '../services/web_session_service.dart';
import '../utils/app_logger.dart';
import '../utils/file_utils.dart';

/// Download manager state: active / finished downloads with live progress.
class DownloadProvider extends ChangeNotifier {
  DownloadProvider({
    required DownloadService service,
    required WebSessionService webSession,
    required PermissionService permissions,
  })  : _service = service,
        _webSession = webSession,
        _permissions = permissions {
    _subscription = _service.updates.listen(_onUpdate);
    unawaited(refresh());
  }

  final DownloadService _service;
  final WebSessionService _webSession;
  final PermissionService _permissions;
  late final StreamSubscription<DownloadUpdate> _subscription;

  final StreamController<DownloadItem> _completed = StreamController<DownloadItem>.broadcast();
  final Set<String> _startedThisSession = <String>{};

  List<DownloadItem> _items = const <DownloadItem>[];
  List<File> _savedFiles = const <File>[];
  bool _loading = true;

  List<DownloadItem> get items => _items;

  /// Files saved directly (data: / blob: downloads).
  List<File> get savedFiles => _savedFiles;

  bool get isLoading => _loading;

  int get activeCount => _items.where((DownloadItem i) => i.isRunning).length;

  /// Emits downloads started in this session once they complete, so the UI
  /// can offer "Open".
  Stream<DownloadItem> get onCompleted => _completed.stream;

  Future<void> refresh() async {
    try {
      _items = await _service.loadTasks();
      _savedFiles = await _service.looseFiles(_items);
    } on Object catch (e, st) {
      AppLogger.error('Loading downloads failed', error: e, stackTrace: st);
    }
    _loading = false;
    notifyListeners();
  }

  void _onUpdate(DownloadUpdate update) {
    final int index = _items.indexWhere((DownloadItem i) => i.taskId == update.taskId);
    if (index < 0) {
      unawaited(refresh());
      return;
    }
    final DownloadItem updated =
        _items[index].copyWith(status: update.status, progress: update.progress);
    _items = List<DownloadItem>.of(_items)..[index] = updated;
    notifyListeners();
    if (update.status == DownloadTaskStatus.complete &&
        _startedThisSession.remove(update.taskId)) {
      _completed.add(updated);
    }
  }

  /// Starts downloading [url] with the WebView's cookies.
  Future<String?> download({
    required String url,
    String? suggestedFileName,
    String? mimeType,
    String? contentDisposition,
    String? userAgent,
  }) async {
    await _permissions.ensure(AppPermission.notification);
    await _permissions.ensure(AppPermission.storage);
    final String fileName = (suggestedFileName?.trim().isNotEmpty ?? false)
        ? FileUtils.sanitize(suggestedFileName!.trim())
        : FileUtils.fileNameFromContentDisposition(contentDisposition) ??
            FileUtils.fileNameFromUrl(url, mimeType: mimeType);
    final Map<String, String> headers =
        await _webSession.authHeadersFor(url, userAgent: userAgent);
    final String? taskId =
        await _service.enqueue(url: url, fileName: fileName, headers: headers);
    if (taskId != null) _startedThisSession.add(taskId);
    await refresh();
    return taskId;
  }

  /// Saves a `data:` URL or base64 payload produced by the website.
  Future<File?> saveBase64({
    required String base64Data,
    required String fileName,
    String? mimeType,
  }) async {
    try {
      String data = base64Data;
      final int comma = data.indexOf(',');
      if (data.startsWith('data:') && comma > 0) data = data.substring(comma + 1);
      final Uint8List bytes = base64.decode(data);
      String name = FileUtils.sanitize(fileName);
      if (FileUtils.extensionOf(name).isEmpty) {
        final String? ext = FileUtils.extensionForMime(mimeType);
        if (ext != null) name = '$name.$ext';
      }
      final File file = await _service.saveBytes(name.isEmpty ? 'download' : name, bytes);
      await refresh();
      return file;
    } on FormatException catch (e) {
      AppLogger.error('Invalid base64 download', error: e);
      return null;
    }
  }

  Future<void> cancel(DownloadItem item) async {
    await _service.cancel(item.taskId);
    await refresh();
  }

  Future<void> pause(DownloadItem item) async {
    await _service.pause(item.taskId);
    await refresh();
  }

  Future<void> resume(DownloadItem item) async {
    final String? newId = await _service.resume(item.taskId);
    if (newId != null) _startedThisSession.add(newId);
    await refresh();
  }

  Future<void> retry(DownloadItem item) async {
    final String? newId = await _service.retry(item.taskId);
    if (newId != null) _startedThisSession.add(newId);
    await refresh();
  }

  Future<void> delete(DownloadItem item) async {
    await _service.remove(item.taskId);
    await refresh();
  }

  Future<void> deleteFile(File file) async {
    if (file.existsSync()) await file.delete();
    await refresh();
  }

  Future<bool> openWithSystem(String path) => _service.openWithSystem(path);

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(_completed.close());
    super.dispose();
  }
}
