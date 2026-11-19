import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../core/di/app_services.dart';
import '../../core/errors/app_exception.dart';
import '../../providers/download_provider.dart';
import '../../utils/file_utils.dart';
import '../../utils/ui_utils.dart';
import '../../widgets/status_view.dart';

/// In-app PDF viewer with pinch / double-tap zoom, zoom buttons, page
/// navigation and full-text search.
///
/// Opens either a local [filePath] or a remote [url]; remote files are fetched
/// with the WebView's cookies so authenticated statements work.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, this.url, this.filePath, this.title})
      : assert(url != null || filePath != null, 'Provide url or filePath');

  static Route<void> route({String? url, String? filePath, String? title}) =>
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerScreen(url: url, filePath: filePath, title: title),
      );

  final String? url;
  final String? filePath;
  final String? title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _controller = PdfViewerController();
  final TextEditingController _searchField = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  PdfTextSearchResult _searchResult = PdfTextSearchResult();

  File? _file;
  String? _error;
  double _downloadProgress = 0;
  bool _searching = false;
  int _pageNumber = 1;
  int _pageCount = 0;

  String get _title {
    if (widget.title != null && widget.title!.isNotEmpty) return widget.title!;
    final String source = widget.filePath ?? widget.url ?? 'Document.pdf';
    return FileUtils.fileNameFromUrl(source);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _searchResult.removeListener(_onSearchChanged);
    _controller.dispose();
    _searchField.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _downloadProgress = 0;
    });
    if (widget.filePath != null) {
      setState(() => _file = File(widget.filePath!));
      return;
    }
    final AppServices services = context.read<AppServices>();
    try {
      final Directory temp = await getTemporaryDirectory();
      final File target = File(
        '${temp.path}/pdf_cache/${DateTime.now().millisecondsSinceEpoch}_${FileUtils.sanitize(_title)}',
      );
      final Map<String, String> headers = await services.webSession.authHeadersFor(widget.url!);
      await services.http.download(
        widget.url!,
        target,
        headers: headers,
        onProgress: (double p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
      );
      if (mounted) setState(() => _file = target);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) setState(() => _error = 'Unable to open this document.');
    }
  }

  void _startSearch() {
    setState(() => _searching = true);
    _searchFocus.requestFocus();
  }

  void _stopSearch() {
    _searchResult.clear();
    _searchField.clear();
    setState(() => _searching = false);
  }

  void _runSearch(String query) {
    _searchResult.removeListener(_onSearchChanged);
    if (query.trim().isEmpty) {
      _searchResult.clear();
      setState(() {});
      return;
    }
    _searchResult = _controller.searchText(query.trim())..addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {});
    if (_searchResult.isSearchCompleted && !_searchResult.hasResult) {
      UiUtils.showSnack(context, 'No matches for "${_searchField.text.trim()}"');
    }
  }

  void _zoom(double delta) {
    _controller.zoomLevel = (_controller.zoomLevel + delta).clamp(1.0, 5.0);
  }

  Future<void> _share() async {
    final File? file = _file;
    if (file == null) return;
    await context.read<AppServices>().share.shareFile(file.path, text: _title);
  }

  Future<void> _saveToDownloads() async {
    final File? file = _file;
    if (file == null) return;
    final DownloadProvider downloads = context.read<DownloadProvider>();
    final AppServices services = context.read<AppServices>();
    final File saved = await services.downloads.saveBytes(
      _title.toLowerCase().endsWith('.pdf') ? _title : '$_title.pdf',
      await file.readAsBytes(),
    );
    await downloads.refresh();
    if (mounted) UiUtils.showSnack(context, 'Saved to Downloads: ${saved.uri.pathSegments.last}');
  }

  PreferredSizeWidget _buildAppBar() {
    if (_searching) {
      final bool hasResult = _searchResult.hasResult;
      return AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _stopSearch),
        title: TextField(
          controller: _searchField,
          focusNode: _searchFocus,
          textInputAction: TextInputAction.search,
          style: const TextStyle(color: Colors.white),
          cursorColor: Colors.white,
          decoration: const InputDecoration(
            hintText: 'Search in document',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onSubmitted: _runSearch,
        ),
        actions: <Widget>[
          if (hasResult)
            Center(
              child: Text(
                '${_searchResult.currentInstanceIndex}/${_searchResult.totalInstanceCount}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            tooltip: 'Previous match',
            icon: const Icon(Icons.keyboard_arrow_up_rounded),
            onPressed: hasResult ? _searchResult.previousInstance : null,
          ),
          IconButton(
            tooltip: 'Next match',
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            onPressed: hasResult ? _searchResult.nextInstance : null,
          ),
        ],
      );
    }
    return AppBar(
      title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: <Widget>[
        IconButton(
          tooltip: 'Search',
          icon: const Icon(Icons.search_rounded),
          onPressed: _file == null ? null : _startSearch,
        ),
        PopupMenuButton<String>(
          onSelected: (String value) {
            switch (value) {
              case 'share':
                unawaited(_share());
              case 'save':
                unawaited(_saveToDownloads());
            }
          },
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(
              value: 'share',
              child: ListTile(leading: Icon(Icons.share_rounded), title: Text('Share')),
            ),
            PopupMenuItem<String>(
              value: 'save',
              child: ListTile(leading: Icon(Icons.download_rounded), title: Text('Save to Downloads')),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final File? file = _file;
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _searching) _stopSearch();
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _error != null
            ? StatusView.error(onReload: _load, details: _error)
            : file == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        SizedBox.square(
                          dimension: 56,
                          child: CircularProgressIndicator(
                            value: _downloadProgress > 0 ? _downloadProgress : null,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(_downloadProgress > 0
                            ? 'Loading ${(_downloadProgress * 100).round()}%'
                            : 'Opening document…'),
                      ],
                    ),
                  )
                : SfPdfViewer.file(
                    file,
                    controller: _controller,
                    maxZoomLevel: 5,
                    enableDoubleTapZooming: true,
                    canShowScrollHead: true,
                    canShowPaginationDialog: true,
                    onDocumentLoaded: (PdfDocumentLoadedDetails details) =>
                        setState(() => _pageCount = details.document.pages.count),
                    onPageChanged: (PdfPageChangedDetails details) =>
                        setState(() => _pageNumber = details.newPageNumber),
                    onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) =>
                        setState(() => _error = details.description),
                  ),
        floatingActionButton: file == null || _error != null
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FloatingActionButton.small(
                    heroTag: 'pdf_zoom_in',
                    tooltip: 'Zoom in',
                    onPressed: () => _zoom(0.5),
                    child: const Icon(Icons.zoom_in_rounded),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'pdf_zoom_out',
                    tooltip: 'Zoom out',
                    onPressed: () => _zoom(-0.5),
                    child: const Icon(Icons.zoom_out_rounded),
                  ),
                ],
              ),
        bottomNavigationBar: file == null || _pageCount == 0
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Page $_pageNumber of $_pageCount',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
      ),
    );
  }
}
