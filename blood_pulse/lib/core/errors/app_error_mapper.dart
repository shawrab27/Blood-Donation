// USER RULE - do not change: S3 AppError mapper converts any API error into one short human sentence. Never show raw JSON, ApiException, status codes or field names. Unknown -> "Something went wrong. Please try again."
import 'dart:convert';

/// Universal S3 Error Mapper for BloodPulse.
///
/// Converts any exception, error object, or raw server response into a single,
/// human-friendly sentence. Eliminates developer jargon, raw JSON payloads,
/// HTTP status codes, and model field names from reaching users.
class AppError {
  AppError._();

  static const String defaultMessage = 'Something went wrong. Please try again.';

  /// Maps any dynamic [error] to a short, clear, human-readable sentence.
  static String toHumanMessage(dynamic error, {bool isBangla = false}) {
    if (error == null) {
      return isBangla
          ? 'একটি সমস্যা হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।'
          : defaultMessage;
    }

    String raw = error.toString().trim();

    // 1. Check for specific known network or server states
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network unreachable') ||
        lower.contains('clientexception') ||
        lower.contains('no internet')) {
      return isBangla
          ? 'ইন্টারনেট সংযোগ নেই। আপনার নেটওয়ার্ক চেক করুন।'
          : 'Unable to connect. Please check your internet connection and try again.';
    }

    if (lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('deadline exceeded')) {
      return isBangla
          ? 'সার্ভারে সংযোগের সময় শেষ হয়েছে। আবার চেষ্টা করুন।'
          : 'Connection timed out. Please try again.';
    }

    if (lower.contains('server is waking up') || lower.contains('সার্ভার চালু হচ্ছে')) {
      return isBangla
          ? 'সার্ভার চালু হচ্ছে, কিছুক্ষণ অপেক্ষা করুন...'
          : 'Server is starting up. Please wait a moment and try again.';
    }

    // 2. Strip standard exception prefixes
    raw = _stripPrefixes(raw);

    // 3. Attempt to parse JSON structures (handles embedded JSON e.g. 'ApiException: {"detail": "..."} [401]')
    final extractedFromJson = _extractFromJsonString(raw);
    if (extractedFromJson != null && extractedFromJson.isNotEmpty) {
      raw = extractedFromJson;
    }

    // 4. Clean up any remaining field names, status codes, brackets
    raw = _cleanMessageString(raw);

    if (raw.isEmpty || _isTechnicalJargon(raw)) {
      return isBangla
          ? 'একটি সমস্যা হয়েছে। অনুগ্রহ করে আবার চেষ্টা করুন।'
          : defaultMessage;
    }

    // Ensure sentence ending and capitalization
    if (!raw.endsWith('.') && !raw.endsWith('!') && !raw.endsWith('?')) {
      raw = '$raw.';
    }

    return raw;
  }

  static String _stripPrefixes(String text) {
    var result = text;
    final prefixes = [
      'ApiException:',
      'Exception:',
      'Error:',
      'BadRequestException:',
      'ServerException:',
      'AuthException:',
      'FirebaseException:',
    ];
    for (final p in prefixes) {
      if (result.startsWith(p)) {
        result = result.substring(p.length).trim();
      }
    }
    return result;
  }

  static String? _extractFromJsonString(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      final jsonCandidate = text.substring(start, end + 1);
      try {
        final decoded = jsonDecode(jsonCandidate);
        final extracted = _extractFromDecoded(decoded);
        if (extracted != null && extracted.isNotEmpty) {
          return extracted;
        }
      } catch (_) {}
    }

    final listStart = text.indexOf('[');
    final listEnd = text.lastIndexOf(']');
    if (listStart != -1 && listEnd != -1 && listEnd > listStart) {
      final listCandidate = text.substring(listStart, listEnd + 1);
      try {
        final decoded = jsonDecode(listCandidate);
        final extracted = _extractFromDecoded(decoded);
        if (extracted != null && extracted.isNotEmpty) {
          return extracted;
        }
      } catch (_) {}
    }

    return null;
  }

  static String? _extractFromDecoded(dynamic decoded) {
    if (decoded is Map) {
      for (final key in ['detail', 'error', 'message', 'non_field_errors']) {
        if (decoded.containsKey(key)) {
          final val = decoded[key];
          if (val is String && val.isNotEmpty) return val;
          if (val is List && val.isNotEmpty) return val.first.toString();
        }
      }
      for (final val in decoded.values) {
        if (val is List && val.isNotEmpty) return val.first.toString();
        if (val is String && val.isNotEmpty) return val;
        if (val is Map) {
          final nested = _extractFromDecoded(val);
          if (nested != null) return nested;
        }
      }
    } else if (decoded is List && decoded.isNotEmpty) {
      final first = decoded.first;
      if (first is String) return first;
      if (first is Map) return _extractFromDecoded(first);
    }
    return null;
  }

  static String _cleanMessageString(String text) {
    var cleaned = text.trim();

    // Strip status codes like [400], [500], HTTP 404, etc.
    cleaned = cleaned.replaceAll(RegExp(r'\[\d{3}\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'HTTP\s+\d{3}', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'^\d{3}\s+'), '');

    // Strip field syntax e.g. "phone_number: ", "['...']"
    cleaned = cleaned.replaceAll(RegExp(r'^\w+:\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r"[\[\]'\{\}]"), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Capitalize first character
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    return cleaned;
  }

  static bool _isTechnicalJargon(String text) {
    final lower = text.toLowerCase();
    return lower.contains('<!doctype html>') ||
        lower.contains('traceback (most recent call last)') ||
        lower.contains('internal server error') ||
        lower.contains('syntaxerror') ||
        lower.contains('null check operator') ||
        lower.contains('typeerror') ||
        lower.contains('stacktrace');
  }
}
