// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';

/// Single source of truth configuration constants for BloodPulse.
class AppConfig {
  AppConfig._();

  /// Donor cooldown period in days (fixed, non-negotiable medical standard).
  static const int donorCooldownDays = 90;

  /// Application branding
  static const String appName = 'BloodPulse';
  static const String appSubtitle = 'Every Drop Connects Life';

  /// Primary Brand Colors (Stitch UI Spec)
  static const Color primaryColor = Color(0xFFC30121);
  static const Color secondaryColor = Color(0xFF2B2B2B);
  static const Color tertiaryColor = Color(0xFF0D68AA);
  static const Color neutralColor = Color(0xFF8E7D7F);
  static const Color surfaceColor = Color(0xFFFFF8F7);
  static const Color surfaceWarmColor = Color(0xFFFDF3F3);

  /// API Base URL (Render / Vercel proxy)
  static const String defaultApiBaseUrl = 'https://blood-donation-liard.vercel.app';
  static const String renderDirectUrl = 'https://bloodpulse-backend.onrender.com';

  /// Emergency response thresholds
  static const int maxWaveSteps = 8;
  static const int waveRadiusIncrementKm = 5;
  static const int standbyEscalationMinutes = 10;
  static const int standbyCohortCount = 5;

  /// Gamification (Passive Donor XP - Non-competitive)
  static const int xpShareApp = 50;
  static const int xpReadGuide = 25;
  static const int xpUpdateProfile = 10;
  static const int xpSendMessage = 5;

  /// Badge thresholds based on donation count
  static String getBadgeTier(int donationCount) {
    if (donationCount >= 6) return 'Gold Lifesaver';
    if (donationCount >= 3) return 'Silver Lifesaver';
    if (donationCount >= 1) return 'Bronze Lifesaver';
    return 'Altruist';
  }
}
