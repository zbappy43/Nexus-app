import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../core/di/app_services.dart';
import '../../providers/download_provider.dart';
import '../../services/media_service.dart';
import '../../utils/file_utils.dart';
import '../../utils/ui_utils.dart';

/// Native photo tools: pick from gallery or camera, crop, compress, then
/// share or save. The same pipeline is available to the website through
/// `NexusApp.pickImage()`.
class ImageToolsScreen extends StatefulWidget {
  const ImageToolsScreen({super.key});

  @override
  State<ImageToolsScreen> createState() => _ImageToolsScreenState();
}

class _ImageToolsScreenState extends State<ImageToolsScreen> {
  File? _image;
  bool _crop = true;
  bool _compress = true;
  bool _square = false;
  double _quality = 80;
  bool _busy = false;

  Future<void> _pick(MediaSource source) async {
    setState(() => _busy = true);
    try {
      final File? file = await context.read<AppServices>().media.pickImage(
            ImagePickOptions(
              source: source,
              crop: _crop,
              compress: _compress,
              square: _square,
              quality: _quality.round(),
            ),
          );
      if (file != null && mounted) setState(() => _image = file);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final File? image = _image;
    if (image == null) return;
    final AppServices services = context.read<AppServices>();
    final DownloadProvider downloads = context.read<DownloadProvider>();
    final File saved = await services.downloads.saveBytes(
      'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      await image.readAsBytes(),
    );
    await downloads.refresh();
    if (mounted) UiUtils.showSnack(context, 'Saved ${saved.uri.pathSegments.last} to Downloads');
  }

  @override
  Widget build(BuildContext context) {
    final File? image = _image;
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Photo Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: Card(
              child: image == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.add_photo_alternate_outlined, size: 72, color: AppColors.primary),
                          const SizedBox(height: 12),
                          Text('Pick a photo to get started', style: theme.textTheme.titleMedium),
                        ],
                      ),
                    )
                  : InteractiveViewer(child: Image.file(image, fit: BoxFit.contain)),
            ),
          ),
          if (image != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${image.uri.pathSegments.last} · ${FileUtils.formatBytes(image.lengthSync())}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _pick(MediaSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: const Text('Camera'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _pick(MediaSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: <Widget>[
                SwitchListTile(
                  title: const Text('Crop after picking'),
                  value: _crop,
                  onChanged: (bool v) => setState(() => _crop = v),
                ),
                SwitchListTile(
                  title: const Text('Square crop (profile photo)'),
                  value: _square,
                  onChanged: _crop ? (bool v) => setState(() => _square = v) : null,
                ),
                SwitchListTile(
                  title: const Text('Compress'),
                  subtitle: const Text('Smaller files upload faster'),
                  value: _compress,
                  onChanged: (bool v) => setState(() => _compress = v),
                ),
                ListTile(
                  title: Text('Quality ${_quality.round()}%'),
                  subtitle: Slider(
                    value: _quality,
                    min: 30,
                    max: 100,
                    divisions: 14,
                    label: '${_quality.round()}%',
                    onChanged: _compress ? (double v) => setState(() => _quality = v) : null,
                  ),
                ),
              ],
            ),
          ),
          if (image != null) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => context.read<AppServices>().share.shareFile(image.path),
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
