import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';

import '../utils/file_utils.dart';

/// UI model of a file managed by the download manager.
@immutable
class DownloadItem {
  const DownloadItem({
    required this.taskId,
    required this.url,
    required this.fileName,
    required this.savedDir,
    required this.status,
    required this.progress,
    required this.createdAt,
  });

  factory DownloadItem.fromTask(DownloadTask task) {
    final String name = (task.filename?.isNotEmpty ?? false)
        ? task.filename!
        : FileUtils.fileNameFromUrl(task.url);
    return DownloadItem(
      taskId: task.taskId,
      url: task.url,
      fileName: name,
      savedDir: task.savedDir,
      status: task.status,
      progress: task.progress.clamp(0, 100),
      createdAt: DateTime.fromMillisecondsSinceEpoch(task.timeCreated),
    );
  }

  final String taskId;
  final String url;
  final String fileName;
  final String savedDir;
  final DownloadTaskStatus status;
  final int progress;
  final DateTime createdAt;

  String get filePath => '$savedDir/$fileName';

  FileKind get kind => FileUtils.kindOf(fileName);

  bool get isRunning =>
      status == DownloadTaskStatus.running || status == DownloadTaskStatus.enqueued;

  bool get isComplete => status == DownloadTaskStatus.complete;

  bool get isFailed =>
      status == DownloadTaskStatus.failed || status == DownloadTaskStatus.canceled;

  bool get isPaused => status == DownloadTaskStatus.paused;

  DownloadItem copyWith({DownloadTaskStatus? status, int? progress}) => DownloadItem(
        taskId: taskId,
        url: url,
        fileName: fileName,
        savedDir: savedDir,
        status: status ?? this.status,
        progress: (progress ?? this.progress).clamp(0, 100),
        createdAt: createdAt,
      );
}
