// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

// USER RULE - do not change
// Language selection is only performed on the dedicated Language Screen or in Settings.
// Global EN/BN button on page headers is permanently disabled across all screens.
class LanguageToggleButton extends StatelessWidget {
  final Color? backgroundColor;
  const LanguageToggleButton({super.key, this.backgroundColor});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
