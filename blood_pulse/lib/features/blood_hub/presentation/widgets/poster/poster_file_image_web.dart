// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Stub for web — poster photo from local file path is not available on web.
/// The caller (PosterPhotoTemplate) should gate this behind kIsWeb.
Widget fileImageWidget(String path) => const SizedBox.shrink();
