import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../core/di/app_services.dart';
import '../../models/download_item.dart';
import '../../providers/download_provider.dart';
import '../../utils/file_utils.dart';
import '../../utils/ui_utils.dart';
import '../pdf/pdf_viewer_screen.dart';

/// Download manager: live progress, pause / resume / retry / cancel, open,
/// share and delete.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  static IconData iconFor(FileKind kind) => switch (kind) {
        FileKind.pdf => Icons.picture_as_pdf_rounded,
        FileKind.image => Icons.image_rounded,
        FileKind.video => Icons.movie_rounded,
        FileKind.audio => Icons.audiotrack_rounded,
        FileKind.spreadsheet => Icons.table_chart_rounded,
        FileKind.document => Icons.description_rounded,
        FileKind.archive => Icons.folder_zip_rounded,
        FileKind.apk => Icons.android_rounded,
        FileKind.other => Icons.insert_drive_file_rounded,
      };

  static Color colorFor(FileKind kind) => switch (kind) {
        FileKind.pdf => AppColors.error,
        FileKind.image => const Color(0xFF7B1FA2),
        FileKind.video => const Color(0xFF1565C0),
        FileKind.audio => const Color(0xFFEF6C00),
        FileKind.spreadsheet => AppColors.primary,
        FileKind.document => const Color(0xFF283593),
        FileKind.archive => const Color(0xFF6D4C41),
        FileKind.apk => const Color(0xFF2E7D32),
        FileKind.other => Colors.blueGrey,
      };

  static Future<void> openFile(BuildContext context, String path) async {
    if (FileUtils.isPdf(path)) {
      await Navigator.of(context).push<void>(PdfViewerScreen.route(filePath: path));
      return;
    }
    final bool opened = await context.read<DownloadProvider>().openWithSystem(path);
    if (!opened && context.mounted) {
      UiUtils.showSnack(context, 'No app installed to open this file');
    }
  }

  @override
  Widget build(BuildContext context) {
    final DownloadProvider downloads = context.watch<DownloadProvider>();
    final bool empty = downloads.items.isEmpty && downloads.savedFiles.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: RefreshIndicator(
        onRefresh: downloads.refresh,
        child: downloads.isLoading
            ? const Center(child: CircularProgressIndicator())
            : empty
                ? ListView(
                    children: <Widget>[
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
                      const Icon(Icons.download_for_offline_outlined, size: 88, color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'No downloads yet',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Files you download from the app appear here.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      for (final DownloadItem item in downloads.items) ...<Widget>[
                        _DownloadTile(item: item),
                        const SizedBox(height: 10),
                      ],
                      for (final File file in downloads.savedFiles) ...<Widget>[
                        _SavedFileTile(file: file),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  const _DownloadTile({required this.item});

  final DownloadItem item;

  @override
  Widget build(BuildContext context) {
    final DownloadProvider downloads = context.read<DownloadProvider>();
    final ThemeData theme = Theme.of(context);
    final String status = item.isComplete
        ? 'Completed'
        : item.isPaused
            ? 'Paused · ${item.progress}%'
            : item.isFailed
                ? 'Failed'
                : '${item.progress}%';

    return Card(
      child: InkWell(
        onTap: item.isComplete ? () => DownloadsScreen.openFile(context, item.filePath) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: DownloadsScreen.colorFor(item.kind).withValues(alpha: 0.12),
                    child: Icon(
                      DownloadsScreen.iconFor(item.kind),
                      color: DownloadsScreen.colorFor(item.kind),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          status,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: item.isFailed ? theme.colorScheme.error : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (item.isRunning)
                    IconButton(
                      tooltip: 'Pause',
                      icon: const Icon(Icons.pause_rounded),
                      onPressed: () => downloads.pause(item),
                    ),
                  if (item.isPaused)
                    IconButton(
                      tooltip: 'Resume',
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () => downloads.resume(item),
                    ),
                  if (item.isFailed)
                    IconButton(
                      tooltip: 'Retry',
                      icon: const Icon(Icons.replay_rounded),
                      onPressed: () => downloads.retry(item),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (String action) async {
                      switch (action) {
                        case 'open':
                          await DownloadsScreen.openFile(context, item.filePath);
                        case 'share':
                          await context.read<AppServices>().share.shareFile(item.filePath);
                        case 'cancel':
                          await downloads.cancel(item);
                        case 'delete':
                          await downloads.delete(item);
                      }
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      if (item.isComplete) ...const <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(value: 'open', child: Text('Open')),
                        PopupMenuItem<String>(value: 'share', child: Text('Share')),
                      ],
                      if (item.isRunning || item.isPaused)
                        const PopupMenuItem<String>(value: 'cancel', child: Text('Cancel')),
                      const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              if (item.isRunning || item.isPaused)
                Padding(
                  padding: const EdgeInsets.only(top: 10, right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: item.progress > 0 ? item.progress / 100 : null,
                      minHeight: 6,
                      color: AppColors.primary,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedFileTile extends StatelessWidget {
  const _SavedFileTile({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    final String name = file.uri.pathSegments.last;
    final FileKind kind = FileUtils.kindOf(name);
    final int size = file.existsSync() ? file.lengthSync() : 0;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        leading: CircleAvatar(
          backgroundColor: DownloadsScreen.colorFor(kind).withValues(alpha: 0.12),
          child: Icon(DownloadsScreen.iconFor(kind), color: DownloadsScreen.colorFor(kind)),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('Saved · ${FileUtils.formatBytes(size)}'),
        onTap: () => DownloadsScreen.openFile(context, file.path),
        trailing: PopupMenuButton<String>(
          onSelected: (String action) async {
            switch (action) {
              case 'share':
                await context.read<AppServices>().share.shareFile(file.path);
              case 'delete':
                await context.read<DownloadProvider>().deleteFile(file);
            }
          },
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'share', child: Text('Share')),
            PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

