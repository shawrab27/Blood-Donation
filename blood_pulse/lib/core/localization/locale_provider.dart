import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kLocalePrefKey = 'bp_selected_locale';

enum AppLanguage { english, bangla }

/// Riverpod state notifier managing active application Locale and persisting selection.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _loadPersistedLocale();
  }

  Future<void> _loadPersistedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_kLocalePrefKey);
      if (languageCode != null && (languageCode == 'en' || languageCode == 'bn')) {
        state = Locale(languageCode);
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale locale) async {
    if (state == locale) return;
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLocalePrefKey, locale.languageCode);
    } catch (_) {}
  }

  void setEnglish() => setLocale(const Locale('en'));
  void setBangla() => setLocale(const Locale('bn'));

  Future<void> toggleLanguage() async {
    final next = state.languageCode == 'en' ? const Locale('bn') : const Locale('en');
    await setLocale(next);
  }

  AppLanguage get current =>
      state.languageCode == 'bn' ? AppLanguage.bangla : AppLanguage.english;
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
