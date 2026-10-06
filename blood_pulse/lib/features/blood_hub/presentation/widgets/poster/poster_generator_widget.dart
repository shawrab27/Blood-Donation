// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'poster_blank_template.dart';
import 'poster_photo_template.dart';
import 'poster_text_template.dart';

/// Reusable widget rendering the chosen BloodPulse emergency poster template.
/// Uses [RepaintBoundary] to support raster PNG export.
class PosterGeneratorWidget extends StatefulWidget {
  const PosterGeneratorWidget({
    super.key,
    required this.data,
    required this.templateType,
    this.repaintKey,
    this.isBangla = false,
  });

  final PosterData data;
  final PosterTemplateType templateType;
  final GlobalKey? repaintKey;
  final bool isBangla;

  @override
  PosterGeneratorWidgetState createState() => PosterGeneratorWidgetState();
}

class PosterGeneratorWidgetState extends State<PosterGeneratorWidget> {
  late GlobalKey _repaintKey;

  GlobalKey get effectiveRepaintKey => widget.repaintKey ?? _repaintKey;

  @override
  void initState() {
    super.initState();
    _repaintKey = GlobalKey();
  }

  /// Exports the current visual state of the poster into a high-res PNG file.
  Future<File> exportPNG({
    double pixelRatio = 3.0,
    Directory? targetDirectory,
  }) async {
    try {
      final boundary = effectiveRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Repaint boundary context is not attached yet.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('Failed to encode image to PNG format.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      Directory dir;
      if (targetDirectory != null) {
        dir = targetDirectory;
      } else {
        try {
          dir = await getTemporaryDirectory();
        } catch (_) {
          dir = Directory.systemTemp;
        }
      }
      final file = File(
        '${dir.path}/bloodpulse_poster_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('[ERROR] Poster PNG capture failed: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: effectiveRepaintKey,
      child: Material(
        color: Colors.transparent,
        child: _buildTemplateContent(),
      ),
    );
  }

  Widget _buildTemplateContent() {
    switch (widget.templateType) {
      case PosterTemplateType.withPhoto:
        return PosterPhotoTemplate(
          data: widget.data,
          isBangla: widget.isBangla,
        );
      case PosterTemplateType.textOnly:
        return PosterTextTemplate(
          data: widget.data,
          isBangla: widget.isBangla,
        );
      case PosterTemplateType.blank:
        return PosterBlankTemplate(
          data: widget.data,
          isBangla: widget.isBangla,
        );
    }
  }
}
