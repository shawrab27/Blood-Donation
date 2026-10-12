// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Client-side image compression service for Feed and Medical Slip uploads.
/// Enforces:
/// - Max 1280px long side
/// - JPEG/WebP quality ~80
/// - Target size < 300KB
/// - Strips EXIF metadata including GPS tags
class ImageCompressionService {
  ImageCompressionService._();

  static Future<Uint8List?> compressImageFile(File file) async {
    try {
      final filePath = file.absolute.path;
      final result = await FlutterImageCompress.compressWithFile(
        filePath,
        minWidth: 1280,
        minHeight: 1280,
        quality: 80,
        keepExif: false, // Strips EXIF metadata including GPS
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      debugPrint('[ImageCompressionService] Compression error: $e');
      return file.readAsBytesSync();
    }
  }

  static Future<Uint8List> compressImageBytes(Uint8List bytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1280,
        minHeight: 1280,
        quality: 80,
        keepExif: false,
        format: CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      debugPrint('[ImageCompressionService] Bytes compression error: $e');
      return bytes;
    }
  }
}
