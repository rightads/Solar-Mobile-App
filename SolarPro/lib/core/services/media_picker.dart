import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// A file chosen by the user, ready for multipart upload.
class PickedMedia {
  final String name;
  final Uint8List bytes;
  /// Local file path when the platform provides one (needed for offline retry queues).
  final String? path;
  const PickedMedia(this.name, this.bytes, {this.path});

  int get sizeBytes => bytes.length;
}

/// Real camera / gallery / document pickers used by every upload in the app.
class MediaPicker {
  MediaPicker._();

  static const int maxBytes = 10 * 1024 * 1024;
  static final ImagePicker _picker = ImagePicker();

  static bool get _hasCamera => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Lets the user take or choose up to [max] photos.
  static Future<List<PickedMedia>> pickPhotos(BuildContext context, {int max = 1}) async {
    ImageSource? source = ImageSource.gallery;
    if (_hasCamera) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined, color: AppColors.ink900),
                  title: const Text('Take a photo'),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppColors.ink900),
                  title: Text(max > 1 ? 'Choose from gallery (up to $max)' : 'Choose from gallery'),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        ),
      );
      if (source == null) return [];
    }
    final List<XFile> files;
    if (source == ImageSource.camera) {
      final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2400);
      files = shot == null ? [] : [shot];
    } else if (max > 1) {
      files = (await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2400, limit: max)).take(max).toList();
    } else {
      final one = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2400);
      files = one == null ? [] : [one];
    }
    final out = <PickedMedia>[];
    for (final f in files) {
      final bytes = await f.readAsBytes();
      if (bytes.length > maxBytes) {
        throw Exception('${f.name} is larger than 10 MB.');
      }
      out.add(PickedMedia(f.name, bytes, path: kIsWeb ? null : f.path));
    }
    return out;
  }

  /// Lets the user choose a PDF or image document.
  static Future<PickedMedia?> pickDocument() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
    );
    if (files.isEmpty) return null;
    final file = files.first;
    final bytes = await file.xFile.readAsBytes();
    if (bytes.length > maxBytes) throw Exception('${file.name} is larger than 10 MB.');
    return PickedMedia(file.name, bytes, path: kIsWeb ? null : file.path);
  }
}
