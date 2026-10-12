// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brand Asset Integrity Tests', () {
    test('Untouched original artwork preserved under assets/brand/original/ and matches locked hash', () {
      final originalFile = File('assets/brand/original/blood_pulse_logo_original.jpg');
      expect(originalFile.existsSync(), isTrue, reason: 'assets/brand/original/blood_pulse_logo_original.jpg must exist');

      final bytes = originalFile.readAsBytesSync();
      final hash = sha256.convert(bytes).toString();
      expect(hash, 'aaab5df4f36bf4ca795b7ef8a8a2e74a7b29af8ca6bd01a63f62430239882b6f');
    });

    test('Header image asset Blood Pulse logo.jpg matches untouched original hash', () {
      final headerLogo = File('assets/images/Blood Pulse logo.jpg');
      expect(headerLogo.existsSync(), isTrue, reason: 'assets/images/Blood Pulse logo.jpg must exist');

      final bytes = headerLogo.readAsBytesSync();
      final hash = sha256.convert(bytes).toString();
      expect(hash, 'aaab5df4f36bf4ca795b7ef8a8a2e74a7b29af8ca6bd01a63f62430239882b6f');
    });

    test('Launcher-only variant blood_pulse_logo.png exists and matches locked hash', () {
      final launcherFile = File('assets/brand/blood_pulse_logo.png');
      expect(launcherFile.existsSync(), isTrue, reason: 'assets/brand/blood_pulse_logo.png must exist');

      final bytes = launcherFile.readAsBytesSync();
      final hash = sha256.convert(bytes).toString();
      expect(hash, 'c316fef992a68ed13d87daaf32741d98f08cb3acc0a9a4a1a8ad6113bfcba4cc');
    });
  });
}
