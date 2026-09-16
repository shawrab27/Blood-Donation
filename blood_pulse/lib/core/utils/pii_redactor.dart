/// Utility for on-device PII (Personally Identifiable Information) redaction.
/// Strips emails, phone numbers, and Bangladesh NID numbers before sending text off-device.
class PiiRedactor {
  const PiiRedactor._();

  /// On-device PII redaction helper to strip sensitive personal identification
  /// data (NID, phone numbers, email) before sending OCR text off-device.
  static String redactPII(String text) {
    var redacted = text;
    // Email redaction
    redacted = redacted.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      '[REDACTED_EMAIL]',
    );
    // Phone number redaction (+880XXXXXXXXXX or 01XXXXXXXXX)
    redacted = redacted.replaceAll(
      RegExp(r'(\+?880|0)1[3-9]\d{8}\b'),
      '[REDACTED_PHONE]',
    );
    // Bangladesh NID redaction (10, 13, or 17 consecutive digits)
    redacted = redacted.replaceAll(
      RegExp(r'\b\d{17}\b|\b\d{13}\b|\b\d{10}\b'),
      '[REDACTED_NID]',
    );
    return redacted;
  }

  /// Alias for [redactPII].
  static String redact(String text) => redactPII(text);
}
