// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HydrationState {
  final int glasses;
  final int targetGlasses;
  final String dateKey;

  const HydrationState({
    this.glasses = 0,
    this.targetGlasses = 10,
    required this.dateKey,
  });

  int get totalMl => glasses * 250;
  int get targetMl => targetGlasses * 250;
  double get progress => (glasses / targetGlasses).clamp(0.0, 1.0);

  HydrationState copyWith({
    int? glasses,
    int? targetGlasses,
    String? dateKey,
  }) {
    return HydrationState(
      glasses: glasses ?? this.glasses,
      targetGlasses: targetGlasses ?? this.targetGlasses,
      dateKey: dateKey ?? this.dateKey,
    );
  }
}

class HydrationNotifier extends StateNotifier<HydrationState> {
  HydrationNotifier() : super(HydrationState(dateKey: _getDhakaTodayKey())) {
    _initFromStorage();
  }

  static const String _kDateKey = 'bp_hydration_date';
  static const String _kGlassesKey = 'bp_hydration_glasses';

  /// Computes current date string in Asia/Dhaka time (UTC+6)
  static String _getDhakaTodayKey() {
    final nowDhaka = DateTime.now().toUtc().add(const Duration(hours: 6));
    final y = nowDhaka.year.toString().padLeft(4, '0');
    final m = nowDhaka.month.toString().padLeft(2, '0');
    final d = nowDhaka.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _initFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getDhakaTodayKey();
      final savedDate = prefs.getString(_kDateKey);

      if (savedDate == today) {
        final savedGlasses = prefs.getInt(_kGlassesKey) ?? 0;
        state = state.copyWith(glasses: savedGlasses, dateKey: today);
      } else {
        // Local midnight reset (Asia/Dhaka)
        await prefs.setString(_kDateKey, today);
        await prefs.setInt(_kGlassesKey, 0);
        state = state.copyWith(glasses: 0, dateKey: today);
      }
    } catch (_) {
      // Graceful offline fallback
    }
  }

  Future<void> _checkAndResetIfNewDay() async {
    final today = _getDhakaTodayKey();
    if (state.dateKey != today) {
      state = state.copyWith(glasses: 0, dateKey: today);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kDateKey, today);
        await prefs.setInt(_kGlassesKey, 0);
      } catch (_) {}
    }
  }

  Future<void> addGlass() async {
    await _checkAndResetIfNewDay();
    final newCount = state.glasses + 1;
    state = state.copyWith(glasses: newCount);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDateKey, state.dateKey);
      await prefs.setInt(_kGlassesKey, newCount);
    } catch (_) {}
  }

  Future<void> removeGlass() async {
    await _checkAndResetIfNewDay();
    if (state.glasses <= 0) return;
    final newCount = state.glasses - 1;
    state = state.copyWith(glasses: newCount);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDateKey, state.dateKey);
      await prefs.setInt(_kGlassesKey, newCount);
    } catch (_) {}
  }

  Future<void> reset() async {
    final today = _getDhakaTodayKey();
    state = state.copyWith(glasses: 0, dateKey: today);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDateKey, today);
      await prefs.setInt(_kGlassesKey, 0);
    } catch (_) {}
  }
}

final hydrationProvider = StateNotifierProvider<HydrationNotifier, HydrationState>(
  (ref) => HydrationNotifier(),
);
