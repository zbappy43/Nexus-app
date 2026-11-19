import 'dart:ui' show Color;
import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_colors.dart';
import '../utils/app_logger.dart';
import 'permission_service.dart';

enum MediaSource { camera, gallery }

/// Options for [MediaService.pickImage].
class ImagePickOptions {
  const ImagePickOptions({
    this.source = MediaSource.gallery,
    this.crop = true,
    this.compress = true,
    this.square = false,
    this.quality = 80,
    this.maxDimension = 1600,
  });

  /// Parses options sent by the website through the JavaScript bridge.
  factory ImagePickOptions.fromJson(Map<String, dynamic> json) => ImagePickOptions(
        source: json['source'] == 'camera' ? MediaSource.camera : MediaSource.gallery,
        crop: json['crop'] as bool? ?? true,
        compress: json['compress'] as bool? ?? true,
        square: json['square'] as bool? ?? false,
        quality: ((json['quality'] as num?) ?? 80).toInt().clamp(10, 100),
        maxDimension: ((json['maxDimension'] as num?) ?? 1600).toInt().clamp(256, 4096),
      );

  final MediaSource source;
  final bool crop;
  final bool compress;
  final bool square;
  final int quality;
  final int maxDimension;
}

/// Gallery / camera picking with cropping (uCrop) and JPEG compression.
class MediaService {
  MediaService({required PermissionService permissions, ImagePicker? picker})
      : _permissions = permissions,
        _picker = picker ?? ImagePicker();

  final PermissionService _permissions;
  final ImagePicker _picker;
  final ImageCropper _cropper = ImageCropper();

  /// Returns the processed image file, or `null` if the user cancelled.
  Future<File?> pickImage(ImagePickOptions options) async {
    if (options.source == MediaSource.camera &&
        !await _permissions.ensure(AppPermission.camera)) {
      return null;
    }
    final XFile? picked = await _picker.pickImage(
      source: options.source == MediaSource.camera ? ImageSource.camera : ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (picked == null) return null;

    String path = picked.path;
    if (options.crop) {
      final String? cropped = await crop(path, square: options.square);
      if (cropped == null) return null;
      path = cropped;
    }
    if (options.compress) {
      path = await compress(path, quality: options.quality, maxDimension: options.maxDimension);
    }
    return File(path);
  }

  /// Opens the crop UI. Returns the cropped file path or `null` if cancelled.
  Future<String?> crop(String sourcePath, {bool square = false}) async {
    final CroppedFile? result = await _cropper.cropImage(
      sourcePath: sourcePath,
      aspectRatio: square ? const CropAspectRatio(ratioX: 1, ratioY: 1) : null,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: <PlatformUiSettings>[
        AndroidUiSettings(
          toolbarTitle: 'Crop image',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: const Color(0xFFFFFFFF),
          activeControlsWidgetColor: AppColors.accent,
          cropFrameColor: AppColors.accent,
          statusBarLight: false,
          lockAspectRatio: square,
          initAspectRatio: square ? CropAspectRatioPreset.square : CropAspectRatioPreset.original,
          aspectRatioPresets: <CropAspectRatioPresetData>[
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );
    return result?.path;
  }

  /// Compresses to JPEG, bounding the longest side by [maxDimension].
  /// Falls back to the original file if compression fails.
  Future<String> compress(String sourcePath, {int quality = 80, int maxDimension = 1600}) async {
    try {
      final Directory temp = await getTemporaryDirectory();
      final String target =
          '${temp.path}/nexus_${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
      final XFile? out = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        target,
        quality: quality,
        minWidth: maxDimension,
        minHeight: maxDimension,
      );
      return out?.path ?? sourcePath;
    } on Object catch (e, st) {
      AppLogger.error('Image compression failed', error: e, stackTrace: st);
      return sourcePath;
    }
  }
}
