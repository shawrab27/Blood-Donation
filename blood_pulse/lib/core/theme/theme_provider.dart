import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemePrefKey = 'bp_selected_theme_mode';

/// Riverpod StateNotifier managing the application's active ThemeMode
/// (System, Light, Dark) and persisting the user's choice to SharedPreferences.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadPersistedTheme();
  }

  Future<void> _loadPersistedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_kThemePrefKey);
      if (savedTheme != null) {
        switch (savedTheme) {
          case 'system':
            state = ThemeMode.system;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          case 'light':
          default:
            state = ThemeMode.light;
            break;
        }
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'light';
      if (mode == ThemeMode.system) val = 'system';
      if (mode == ThemeMode.dark) val = 'dark';
      await prefs.setString(_kThemePrefKey, val);
    } catch (_) {}
  }

  void setSystem() => setThemeMode(ThemeMode.system);
  void setLight() => setThemeMode(ThemeMode.light);
  void setDark() => setThemeMode(ThemeMode.dark);

  int get activeIndex {
    switch (state) {
      case ThemeMode.system:
        return 0;
      case ThemeMode.light:
        return 1;
      case ThemeMode.dark:
        return 2;
    }
  }

  void setByIndex(int index) {
    switch (index) {
      case 0:
        setSystem();
        break;
      case 1:
        setLight();
        break;
      case 2:
        setDark();
        break;
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
