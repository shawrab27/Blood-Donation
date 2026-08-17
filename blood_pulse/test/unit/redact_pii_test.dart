import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/services/ai_trust_detector_service.dart';

void main() {
  test('Redacts PII correctly and prints to console', () {
    final rawText = '''
Medical Report
Patient Name: John Doe
Patient Phone: 01712345678 or +8801987654321
Patient NID: 1982345678901
Patient Email: john.doe@example.com
Hospital: Dhaka City Hospital
Blood Group required: AB+
Diagnosis: Needs immediate transfusion.
''';

    final redacted = AiTrustDetectorService.redactPII(rawText);

    // Assertions to ensure the leak is closed
    expect(redacted.contains('01712345678'), isFalse);
    expect(redacted.contains('+8801987654321'), isFalse);
    expect(redacted.contains('1982345678901'), isFalse);
    expect(redacted.contains('john.doe@example.com'), isFalse);

    expect(redacted.contains('[REDACTED_PHONE]'), isTrue);
    expect(redacted.contains('[REDACTED_NID]'), isTrue);
    expect(redacted.contains('[REDACTED_EMAIL]'), isTrue);
  });
}
