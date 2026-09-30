// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPulseAiVisibleKey = 'pulse_ai_fab_visible';

class PulseAiVisibilityNotifier extends StateNotifier<bool> {
  PulseAiVisibilityNotifier() : super(true) {
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isVisible = prefs.getBool(_kPulseAiVisibleKey) ?? true;
      state = isVisible;
    } catch (_) {
      // Default to visible if error loading
      state = true;
    }
  }

  Future<void> setVisible(bool visible) async {
    state = visible;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPulseAiVisibleKey, visible);
    } catch (_) {}
  }

  Future<void> toggle() => setVisible(!state);
}

final pulseAiVisibilityProvider =
    StateNotifierProvider<PulseAiVisibilityNotifier, bool>((ref) {
  return PulseAiVisibilityNotifier();
});
