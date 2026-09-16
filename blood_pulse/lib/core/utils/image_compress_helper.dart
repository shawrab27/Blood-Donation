import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Utility to compress images before upload / post creation.
/// Enforces: max 1080x720 resolution, WebP format, quality 80.
class ImageCompressHelper {
  const ImageCompressHelper._();

  /// Compresses a local file to WebP format (max 1080x720, quality 80).
  /// Returns the compressed file path, or the original path if compression is unsupported/fails.
  static Future<String> compressPostImage(String sourcePath) async {
    try {

      final file = File(sourcePath);
      if (!await file.exists()) return sourcePath;

      final targetPath = '${sourcePath}_compressed.webp';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        minWidth: 1080,
        minHeight: 720,
        quality: 80,
        format: CompressFormat.webp,
      );

      return result?.path ?? sourcePath;
    } catch (e) {
      debugPrint('[ImageCompressHelper] Error compressing image: $e');
      return sourcePath;
    }
  }

  /// Compresses image bytes directly to WebP (max 1080x720, quality 80).
  static Future<Uint8List> compressImageBytes(Uint8List list) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        list,
        minWidth: 1080,
        minHeight: 720,
        quality: 80,
        format: CompressFormat.webp,
      );
      return result;
    } catch (e) {
      debugPrint('[ImageCompressHelper] Error compressing bytes: $e');
      return list;
    }
  }
}
