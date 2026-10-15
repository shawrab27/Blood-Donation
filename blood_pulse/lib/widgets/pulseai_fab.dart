// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Legacy Floating Action Button placeholder.
/// PulseAI is rendered globally across all screens via [PulseAiOverlay] in main.dart,
/// featuring the 4-pill speed-dial overlay (Chat, Analyse report, Find donors, Hide)
/// matching the canonical Stitch UI design.
class PulseAIFAB extends StatelessWidget {
  const PulseAIFAB({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
