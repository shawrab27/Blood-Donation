import 'package:flutter/material.dart';

/// BloodPulse Design Token — Color Palette
/// All values sourced from the PHASE 1 brief and Stitch design system.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary   = Color(0xFFC30121); // Deep Blood Red
  static const Color secondary = Color(0xFF2B2B2B); // Dark Slate
  static const Color tertiary  = Color(0xFF0D68AA); // Medical Tech Blue
  static const Color neutral   = Color(0xFF8E7D7F); // Warm Taupe

  // ── Surface / Background ───────────────────────────────────────────────────
  static const Color surface        = Color(0xFFFDF3F3); // Soft Off-White
  static const Color surfaceDark    = Color(0xFF121212);
  static const Color cardLight      = Colors.white;
  static const Color cardDark       = Color(0xFF1E1E1E);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color onPrimary      = Colors.white;
  static const Color textLight      = Color(0xFF1A1A1A);
  static const Color textDark       = Color(0xFFEFEFEF);
  static const Color textMuted      = Color(0xFF8E7D7F); // == neutral

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success        = Color(0xFF1B8A4E);
  static const Color warning        = Color(0xFFF57C00);
  static const Color error          = Color(0xFFD32F2F);
  static const Color info           = Color(0xFF0D68AA); // == tertiary

  // ── Utility ────────────────────────────────────────────────────────────────
  static const Color white          = Colors.white;
  static const Color black          = Colors.black;
  static const Color transparent    = Colors.transparent;

  // ── Glow / Shadow ──────────────────────────────────────────────────────────
  static const Color primaryGlow    = Color(0x55C30121); // 33 % opacity red
  static const Color primaryGlowSoft= Color(0x22C30121); // 13 % opacity red
}
