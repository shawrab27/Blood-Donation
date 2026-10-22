// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.


import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:blood_pulse/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_client.dart';
import 'core/router_notifier.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'core/localization/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/app_router.dart';
import 'core/constants.dart';
import 'features/assistant/presentation/widgets/pulseai_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();



  try {
    await Future.wait([
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      () async {
        await Hive.initFlutter();
        await Hive.openBox('notifications_box');
      }(),
    ]);
  } catch (e) {
    debugPrint('Startup initialization warning: ');
  }

  // Pre-load session tokens and check 24h launch cooldown
  try {
    await ApiClient().getAccessToken();
    final prefs = await SharedPreferences.getInstance();
    final lastOpenMs = prefs.getInt('bp_last_open_time');
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt('bp_last_open_time', nowMs);

    if (lastOpenMs != null && (nowMs - lastOpenMs) < const Duration(hours: 24).inMilliseconds) {
      RouterNotifier.skipIntroToLogin = true;
    }
  } catch (e) {
    debugPrint('[main] Session pre-load error: $e');
  }

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  runApp(
    const ProviderScope(
      child: BloodPulseApp(),
    ),
  );

  try {
    FcmService.instance.initialize().catchError((e) {
      debugPrint('FCM async initialization warning: ');
    });
  } catch (e) {
    debugPrint('FCM synchronous initialization warning: ');
  }
}

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class BloodPulseApp extends ConsumerWidget {
  const BloodPulseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
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
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(appRouterProvider),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => PulseAiOverlay(child: child ?? const SizedBox()),
    );
  }
}

