import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported app locales.
enum AppLanguage { english, bangla }

/// Global locale provider — drives MaterialApp.locale.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>(
  (ref) => LocaleNotifier(),
);

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en'));

  void setEnglish() => state = const Locale('en');
  void setBangla()  => state = const Locale('bn');

  AppLanguage get current =>
      state.languageCode == 'bn' ? AppLanguage.bangla : AppLanguage.english;
}
