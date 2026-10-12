// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'package:flutter/material.dart';

/// Mobile implementation — renders a local file as an image.
Widget fileImageWidget(String path) {
  return Image.file(
    File(path),
    fit: BoxFit.cover,
    width: double.infinity,
    height: 110,
    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
  );
}
