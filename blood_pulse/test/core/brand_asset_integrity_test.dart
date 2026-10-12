// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Brand Asset Integrity Tests', () {
    test('Official brand logo exists under assets/brand/ and matches locked hash', () {
      final brandFile = File('assets/brand/blood_pulse_logo.png');
      expect(brandFile.existsSync(), isTrue, reason: 'assets/brand/blood_pulse_logo.png must exist');

      final bytes = brandFile.readAsBytesSync();
      final hash = sha256.convert(bytes).toString();
      expect(hash, 'c316fef992a68ed13d87daaf32741d98f08cb3acc0a9a4a1a8ad6113bfcba4cc');
    });

    test('Header image asset Blood Pulse logo.jpg exists and matches locked hash', () {
      final headerLogo = File('assets/images/Blood Pulse logo.jpg');
      expect(headerLogo.existsSync(), isTrue, reason: 'assets/images/Blood Pulse logo.jpg must exist');

      final bytes = headerLogo.readAsBytesSync();
      final hash = sha256.convert(bytes).toString();
      expect(hash, 'b2025d4904e8b1f470604e72a84a3da8cb7d337cdd8be1b695f25866bb0a27d0');
    });
  });
}
