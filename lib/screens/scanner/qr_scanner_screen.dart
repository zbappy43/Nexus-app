import 'dart:async';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../core/di/app_services.dart';
import '../../providers/navigation_provider.dart';
import '../../services/permission_service.dart';
import '../../utils/ui_utils.dart';
import '../../utils/url_utils.dart';
import '../../widgets/status_view.dart';

/// QR code and barcode scanner (camera or image from gallery).
///
/// With `returnResult: true` (used by `NexusApp.scanQr()`) the scanned value is
/// popped back to the caller; otherwise a result sheet offers copy / open / share.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key, this.returnResult = false});

  static Route<String> route({bool returnResult = false}) => MaterialPageRoute<String>(
        builder: (_) => QrScannerScreen(returnResult: returnResult),
      );

  final bool returnResult;

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoStart: false,
  );
  bool _handled = false;
  bool? _permissionGranted;

  @override
  void initState() {
    super.initState();
    unawaited(_init());
  }

  Future<void> _init() async {
    final bool granted =
        await context.read<AppServices>().permissions.ensure(AppPermission.camera);
    if (!mounted) return;
    setState(() => _permissionGranted = granted);
    if (granted) await _controller.start();
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final String? value = capture.barcodes
        .map((Barcode b) => b.rawValue ?? b.displayValue)
        .firstWhere((String? v) => v != null && v.isNotEmpty, orElse: () => null);
    if (value == null) return;
    _handled = true;
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    if (widget.returnResult) {
      Navigator.of(context).pop(value);
      return;
    }
    await _controller.stop();
    if (!mounted) return;
    await _showResult(value);
    _handled = false;
    if (mounted) await _controller.start();
  }

  Future<void> _scanFromGallery() async {
    final XFile? image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final BarcodeCapture? capture = await _controller.analyzeImage(image.path);
    if (!mounted) return;
    if (capture == null || capture.barcodes.isEmpty) {
      UiUtils.showSnack(context, 'No QR code or barcode found in this image');
      return;
    }
    await _onDetect(capture);
  }

  Future<void> _showResult(String value) async {
    final Uri? uri = Uri.tryParse(value);
    final bool isLink = uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
    final AppServices services = context.read<AppServices>();
    final NavigationProvider navigation = context.read<NavigationProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('Scan result', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              SelectableText(value, style: Theme.of(ctx).textTheme.bodyLarge),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  if (isLink)
                    FilledButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        if (UrlUtils.isFirstParty(uri)) {
                          Navigator.of(context).pop();
                          unawaited(navigation.openUrl(value));
                        } else {
                          unawaited(services.launcher.openExternal(value));
                        }
                      },
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: value));
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) UiUtils.showSnack(context, 'Copied to clipboard');
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share'),
                    onPressed: () => services.share.shareText(value),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double windowSize = size.width * 0.7;
    final Rect scanWindow = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - kToolbarHeight),
      width: windowSize,
      height: windowSize,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Scan QR / Barcode'),
        actions: <Widget>[
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (BuildContext context, MobileScannerState state, _) => IconButton(
              tooltip: 'Flashlight',
              onPressed: state.torchState == TorchState.unavailable ? null : _controller.toggleTorch,
              icon: Icon(
                state.torchState == TorchState.on
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: switch (_permissionGranted) {
        null => const Center(child: CircularProgressIndicator()),
        false => StatusView(
            icon: Icons.no_photography_rounded,
            title: 'Camera permission needed',
            message: 'Allow camera access to scan QR codes and barcodes, or scan from a photo.',
            actionLabel: 'Open settings',
            onAction: () => context.read<AppServices>().permissions.openSettings(),
            secondaryLabel: 'Scan from gallery',
            onSecondary: _scanFromGallery,
          ),
        true => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              MobileScanner(
                controller: _controller,
                scanWindow: scanWindow,
                onDetect: _onDetect,
                errorBuilder: (BuildContext context, MobileScannerException error) => Center(
                  child: Text(
                    'Camera unavailable (${error.errorCode.name})',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              CustomPaint(painter: _ScannerOverlay(scanWindow)),
              Positioned(
                left: 24,
                right: 24,
                bottom: 48,
                child: Column(
                  children: <Widget>[
                    const Text(
                      'Align the code inside the frame',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: _scanFromGallery,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Scan from gallery'),
                    ),
                  ],
                ),
              ),
            ],
          ),
      },
    );
  }
}

class _ScannerOverlay extends CustomPainter {
  _ScannerOverlay(this.window);

  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect hole = RRect.fromRectAndRadius(window, const Radius.circular(20));
    final Path background = Path()..addRect(Offset.zero & size);
    final Path cutout = Path()..addRRect(hole);
    canvas.drawPath(
      Path.combine(PathOperation.difference, background, cutout),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    final Paint corner = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const double len = 32;
    final Rect r = window;
    for (final (Offset p, Offset h, Offset v) in <(Offset, Offset, Offset)>[
      (r.topLeft, const Offset(len, 0), const Offset(0, len)),
      (r.topRight, const Offset(-len, 0), const Offset(0, len)),
      (r.bottomLeft, const Offset(len, 0), const Offset(0, -len)),
      (r.bottomRight, const Offset(-len, 0), const Offset(0, -len)),
    ]) {
      canvas
        ..drawLine(p, p + h, corner)
        ..drawLine(p, p + v, corner);
    }
  }

  @override
  bool shouldRepaint(_ScannerOverlay oldDelegate) => oldDelegate.window != window;
}
