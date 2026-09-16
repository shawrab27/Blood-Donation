import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:blood_pulse/l10n/app_localizations.dart';
import 'core/localization/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/app_router.dart';
import 'core/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize async services safely in parallel with a strict timeout
  Future<void> initServices() async {
    try {
      await Hive.initFlutter().timeout(const Duration(seconds: 2));
      await Hive.openBox('notifications_box').timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Hive initialization warning: $e');
    }

    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('Firebase initialization warning: $e');
    }
  }

  // Fire services init in background
  initServices();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(
    const ProviderScope(
      child: BloodPulseApp(),
    ),
  );
}

class BloodPulseApp extends ConsumerWidget {
  const BloodPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      locale: currentLocale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
