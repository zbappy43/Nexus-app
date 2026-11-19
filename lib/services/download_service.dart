import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../models/download_item.dart';
import '../utils/app_logger.dart';
import '../utils/file_utils.dart';

/// Progress event emitted by the background downloader.
class DownloadUpdate {
  const DownloadUpdate(this.taskId, this.status, this.progress);

  final String taskId;
  final DownloadTaskStatus status;
  final int progress;
}

const String _portName = 'nexus_downloader_send_port';

/// Called by flutter_downloader on its background isolate.
@pragma('vm:entry-point')
void downloadCallback(String id, int status, int progress) {
  IsolateNameServer.lookupPortByName(_portName)?.send(<Object>[id, status, progress]);
}

/// Background download manager with system notifications and progress.
///
/// Files are written to the app-specific external directory
/// (`Android/data/com.nexus.consumers/files/Download`), which needs no storage
/// permission on any Android version and is visible in file managers.
class DownloadService {
  final ReceivePort _port = ReceivePort();
  final StreamController<DownloadUpdate> _updates = StreamController<DownloadUpdate>.broadcast();
  Future<void>? _initialization;
  Directory? _directory;

  Stream<DownloadUpdate> get updates => _updates.stream;

  /// Safe to call repeatedly / concurrently: the plugin is initialised once.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await FlutterDownloader.initialize(debug: kDebugMode);
    IsolateNameServer.removePortNameMapping(_portName);
    IsolateNameServer.registerPortWithName(_port.sendPort, _portName);
    _port.listen((dynamic message) {
      if (message is List && message.length == 3) {
        _updates.add(DownloadUpdate(
          message[0] as String,
          DownloadTaskStatus.fromInt(message[1] as int),
          message[2] as int,
        ));
      }
    });
    await FlutterDownloader.registerCallback(downloadCallback, step: 2);
  }

  Future<Directory> downloadDirectory() async {
    if (_directory != null) return _directory!;
    final Directory base =
        await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final Directory dir = Directory('${base.path}/Download');
    if (!dir.existsSync()) await dir.create(recursive: true);
    return _directory = dir;
  }

  /// Returns a file name that does not overwrite an existing file.
  Future<String> uniqueFileName(String desired) async {
    final Directory dir = await downloadDirectory();
    final String clean = FileUtils.sanitize(desired).isEmpty ? 'download' : FileUtils.sanitize(desired);
    if (!File('${dir.path}/$clean').existsSync()) return clean;
    final String ext = FileUtils.extensionOf(clean);
    final String stem = ext.isEmpty ? clean : clean.substring(0, clean.length - ext.length - 1);
    for (int i = 1; i < 1000; i++) {
      final String candidate = ext.isEmpty ? '$stem ($i)' : '$stem ($i).$ext';
      if (!File('${dir.path}/$candidate').existsSync()) return candidate;
    }
    return '${DateTime.now().millisecondsSinceEpoch}_$clean';
  }

  /// Starts a background download with a progress notification.
  Future<String?> enqueue({
    required String url,
    required String fileName,
    Map<String, String> headers = const <String, String>{},
  }) async {
    await initialize();
    final Directory dir = await downloadDirectory();
    final String name = await uniqueFileName(fileName);
    return FlutterDownloader.enqueue(
      url: url,
      savedDir: dir.path,
      fileName: name,
      headers: headers,
      showNotification: true,
      openFileFromNotification: true,
      saveInPublicStorage: false,
    );
  }

  /// Saves in-memory bytes (data: / blob: URLs from the WebView).
  Future<File> saveBytes(String fileName, Uint8List bytes) async {
    final Directory dir = await downloadDirectory();
    final String name = await uniqueFileName(fileName);
    final File file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<List<DownloadItem>> loadTasks() async {
    await initialize();
    final List<DownloadTask> tasks = await FlutterDownloader.loadTasks() ?? <DownloadTask>[];
    final List<DownloadItem> items = tasks.map(DownloadItem.fromTask).toList()
      ..sort((DownloadItem a, DownloadItem b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// Files in the download directory that were saved without a task
  /// (base64 / blob downloads).
  Future<List<File>> looseFiles(Iterable<DownloadItem> tasks) async {
    final Directory dir = await downloadDirectory();
    final Set<String> known = tasks.map((DownloadItem t) => t.filePath).toSet();
    final List<File> files = dir
        .listSync()
        .whereType<File>()
        .where((File f) => !known.contains(f.path))
        .toList()
      ..sort((File a, File b) => b.statSync().modified.compareTo(a.statSync().modified));
    return files;
  }

  Future<void> cancel(String taskId) => FlutterDownloader.cancel(taskId: taskId);

  Future<void> pause(String taskId) => FlutterDownloader.pause(taskId: taskId);

  Future<String?> resume(String taskId) => FlutterDownloader.resume(taskId: taskId);

  Future<String?> retry(String taskId) => FlutterDownloader.retry(taskId: taskId);

  Future<void> remove(String taskId, {bool deleteFile = true}) =>
      FlutterDownloader.remove(taskId: taskId, shouldDeleteContent: deleteFile);

  /// Opens a file with the best installed app.
  Future<bool> openWithSystem(String path) async {
    try {
      final OpenResult result = await OpenFilex.open(path, type: FileUtils.mimeTypeOf(path));
      return result.type == ResultType.done;
    } on Object catch (e, st) {
      AppLogger.error('Unable to open $path', error: e, stackTrace: st);
      return false;
    }
  }

  void dispose() {
    IsolateNameServer.removePortNameMapping(_portName);
    _port.close();
    unawaited(_updates.close());
  }
}
