import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:blood_pulse/core/utils/pii_redactor.dart';
import 'package:blood_pulse/services/api_client.dart';
import 'package:blood_pulse/services/ai_trust_detector_service.dart';
import 'package:blood_pulse/services/encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  group('BloodPulse End-to-End Core Pipeline Smoke Tests', () {
    // ─────────────────────────────────────────────────────────────────────────
    // Step A: ApiClient JWT Authorization Header
    // ─────────────────────────────────────────────────────────────────────────
    test('Step A: ApiClient attaches JWT Authorization headers to authenticated requests', () async {
      String? capturedAuthHeader;
      final mockClient = MockClient((request) async {
        capturedAuthHeader = request.headers['Authorization'];
        return http.Response('{"status": "ok"}', 200);
      });

      const secureStorage = FlutterSecureStorage();
      final apiClient = ApiClient(
        baseUrl: 'http://localhost:8000',
        client: mockClient,
        secureStorage: secureStorage,
      );

      // Save mock token
      await apiClient.saveTokens(
        access: 'mock_jwt_access_token_xyz123',
        refresh: 'mock_jwt_refresh_token_abc789',
      );

      // Execute GET request
      final response = await apiClient.get('api/v1/profile/');

      expect(response.statusCode, 200);
      expect(capturedAuthHeader, isNotNull);
      expect(capturedAuthHeader, equals('Bearer mock_jwt_access_token_xyz123'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Step B: PiiRedactor on Bangladeshi Phone (+88017...), NID, & Email
    // ─────────────────────────────────────────────────────────────────────────
    test('Step B: PiiRedactor masks Bangladeshi phone, NID, and email from medical reports', () {
      const mockReport = '''
      DHAKA MEDICAL COLLEGE HOSPITAL
      Patient: Md. Rahim Ali
      Contact: +8801712345678, Alternative: 01898765432
      NID Number: 19951234567890123 (Old NID: 1234567890)
      Doctor Email: dr.karim@dmch-transfusion.gov.bd
      Diagnosis: Severe Anemia. Hemoglobin: 8.2 g/dL. Blood Group: B+
      ''';

      final redacted = PiiRedactor.redact(mockReport);

      // Verify PII is masked
      expect(redacted, contains('[REDACTED_PHONE]'));
      expect(redacted, contains('[REDACTED_NID]'));
      expect(redacted, contains('[REDACTED_EMAIL]'));

      // Verify raw sensitive numbers are NOT present
      expect(redacted.contains('+8801712345678'), isFalse);
      expect(redacted.contains('01898765432'), isFalse);
      expect(redacted.contains('19951234567890123'), isFalse);
      expect(redacted.contains('1234567890'), isFalse);
      expect(redacted.contains('dr.karim@dmch-transfusion.gov.bd'), isFalse);

      // Verify clinical non-PII data is retained
      expect(redacted, contains('Hemoglobin: 8.2 g/dL'));
      expect(redacted, contains('Blood Group: B+'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Step C: AI Trust Gate Permits Requests with trustScore >= 60
    // ─────────────────────────────────────────────────────────────────────────
    test('Step C: AI Trust Gate permits requests with trustScore >= 60 and blocks suspect ones', () {
      // 1. Authentic request with high trust score (85%)
      final authenticResult = AiTrustAnalysisResult(
        trustScore: 85,
        isVerified: true,
        detectedHospitalName: 'Dhaka Medical College Hospital',
        detectedDoctorName: 'Dr. S. Alim',
        detectedBloodGroup: 'O+',
        riskFlags: [],
        message: 'Authentic hospital prescription verified.',
      );

      expect(authenticResult.isApproved, isTrue);
      expect(authenticResult.trustScorePercentage, 85);
      expect(authenticResult.authenticityBadge, equals('AUTHENTIC MEDICAL REPORT'));

      // 2. Suspect / Tampered request with low trust score (45%)
      final suspectResult = AiTrustAnalysisResult(
        trustScore: 45,
        isVerified: false,
        detectedHospitalName: 'Unknown Clinic',
        detectedDoctorName: 'Unverified Signatory',
        detectedBloodGroup: 'AB-',
        riskFlags: ['Document altered / irregular seal'],
        message: 'Suspicious modifications detected.',
      );

      expect(suspectResult.isApproved, isFalse);
      expect(suspectResult.trustScorePercentage, 45);
      expect(suspectResult.authenticityBadge, equals('SUSPECT / UNVERIFIED REPORT'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Step D: Chat E2EE Ciphertext Encryption Pipeline
    // ─────────────────────────────────────────────────────────────────────────
    test('Step D: ChatService RSA+AES E2EE pipeline encrypts outgoing text to ciphertext', () async {
      final encryptionService = EncryptionService.instance;

      // 1. Ensure/Generate RSA Keypair
      final publicKeyPem = await encryptionService.ensureKeypairExists();
      expect(publicKeyPem, contains('BEGIN PUBLIC KEY'));

      // 2. Encrypt plaintext message with recipient public key
      const rawSecretMessage = 'Urgent: O+ transfusion required at DMCH Transfusion Ward 4!';
      final encryptedPayload = encryptionService.encrypt(
        plaintext: rawSecretMessage,
        recipientPublicKeyPem: publicKeyPem,
      );

      // Verify payload structures are secure ciphertext
      expect(encryptedPayload.ciphertext, isNotEmpty);
      expect(encryptedPayload.ciphertext, isNot(equals(rawSecretMessage)));
      expect(encryptedPayload.encryptedAesKey, isNotEmpty);
      expect(encryptedPayload.iv, isNotEmpty);
      expect(encryptedPayload.authTag, isNotEmpty);

      // 3. Decrypt ciphertext payload using stored private key
      final decryptedText = await encryptionService.decrypt(encryptedPayload);

      expect(decryptedText, equals(rawSecretMessage));
    });
  });
}

Future<void> secureStorageWrite(String privateKeyPem) async {
  const secureStorage = FlutterSecureStorage();
  await secureStorage.write(key: 'bp_rsa_private_key', value: privateKeyPem);
}
