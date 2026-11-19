import 'package:material_ui/material_ui.dart';

import '../../widgets/nexus_web_view.dart';

/// Hosts a window opened by the website (`window.open`, `target="_blank"`,
/// OAuth / payment pop-ups). Closes itself when the page calls `window.close()`.
class PopupWebViewScreen extends StatefulWidget {
  const PopupWebViewScreen({required this.windowId, super.key});

  static Route<void> route({required int windowId}) => MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PopupWebViewScreen(windowId: windowId),
      );

  final int windowId;

  @override
  State<PopupWebViewScreen> createState() => _PopupWebViewScreenState();
}

class _PopupWebViewScreenState extends State<PopupWebViewScreen> {
  String _title = '';

  void _close() {
    if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: _close,
        ),
        title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: NexusWebView(
        windowId: widget.windowId,
        onTitleChanged: (String title) => setState(() => _title = title),
        onCloseWindow: _close,
      ),
    );
  }
}
