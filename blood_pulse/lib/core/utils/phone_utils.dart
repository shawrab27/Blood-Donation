// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

/// Bangladeshi Mobile Operators:
/// 013, 014, 015, 016, 017, 018, 019
/// Canonical E.164 format: +8801XXXXXXXXX (14 characters)
final RegExp _bdMobileRegExp = RegExp(r'^(?:\+?880|0)?(1[3-9]\d{8})$');

/// Normalizes any Bangladeshi mobile phone number into canonical format:
/// +8801XXXXXXXXX
///
/// Accepts:
///   - '01XXXXXXXXX' (11 digits)
///   - '8801XXXXXXXXX' (13 digits)
///   - '+8801XXXXXXXXX' (14 chars)
///   - '1XXXXXXXXX' (10 digits)
///   - Numbers with spaces, hyphens, or parentheses
///
/// Returns null if the number is empty or not a valid BD mobile number.
String? normalizePhoneNumber(String? rawPhone) {
  if (rawPhone == null || rawPhone.trim().isEmpty) return null;

  final cleaned = rawPhone.trim();
  final hasPlus = cleaned.startsWith('+');
  final digits = cleaned.replaceAll(RegExp(r'\D'), '');

  final candidate = hasPlus ? '+$digits' : digits;
  final match = _bdMobileRegExp.firstMatch(candidate);
  if (match == null) return null;

  final core10 = match.group(1);
  return '+880$core10';
}

/// Returns true if [rawPhone] is a valid Bangladeshi mobile number.
bool isValidBdMobile(String? rawPhone) {
  return normalizePhoneNumber(rawPhone) != null;
}

/// Masks a phone number to prevent leaking PII.
/// Shows only the last 3 digits: e.g. '***...046'
String maskPhoneNumber(String? rawPhone) {
  if (rawPhone == null || rawPhone.isEmpty) return '***';
  final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 3) {
    return '***...${digits.substring(digits.length - 3)}';
  }
  return '***';
}
