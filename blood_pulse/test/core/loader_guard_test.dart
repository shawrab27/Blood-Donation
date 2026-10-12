// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Linter Guard: Zero direct CircularProgressIndicator usages in lib/', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue);

    final violations = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart') && !entity.path.endsWith('app_loader.dart')) {
        final content = entity.readAsStringSync();
        // Check for direct widget creation (excluding comment mentions)
        if (RegExp(r'\bCircularProgressIndicator\s*\(').hasMatch(content)) {
          violations.add(entity.path);
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'All CircularProgressIndicator instances must be replaced with AppLoader (Found in: $violations)',
    );
  });
}
