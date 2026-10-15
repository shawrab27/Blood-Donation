// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brand Asset Integrity Tests', () {
    test('Canonical accurate logo asset launcher_icon_transparent.png exists and matches locked hash', () {
      final logoFile = File('assets/images/launcher_icon_transparent.png');
      expect(logoFile.existsSync(), isTrue, reason: 'assets/images/launcher_icon_transparent.png must exist');

      final bytes = logoFile.readAsBytesSync();
      final hash = sha256.convert(bytes).toString();
      expect(hash, 'aa2b0d6b0d63701f89b2dfb376cd8e09aedd3e917f8dc320a088a6ec3380fa66');
    });
  });
}
