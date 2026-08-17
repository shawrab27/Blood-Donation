import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/services/ai_trust_detector_service.dart';

void main() {
  group('AI Trust Score Gatekeeper Unit Tests', () {
    test('Trust score >= 60% is approved for request publication', () {
      const result = AiTrustAnalysisResult(
        trustScore: 88,
        isVerified: true,
        detectedHospitalName: 'Dhaka Medical College Hospital',
        detectedDoctorName: 'Dr. Kabir',
        detectedBloodGroup: 'O+',
        riskFlags: [],
        message: 'Verified authentic report.',
      );

      expect(result.trustScorePercentage, equals(88));
      expect(result.isApproved, isTrue);
      expect(result.authenticityBadge, contains('AUTHENTIC'));
    });

    test('Trust score < 60% is rejected and flagged as high fraud risk', () {
      const result = AiTrustAnalysisResult(
        trustScore: 42,
        isVerified: false,
        detectedHospitalName: 'Unverified',
        detectedDoctorName: 'Unknown',
        detectedBloodGroup: 'Unknown',
        riskFlags: ['Missing hospital stamp'],
        message: 'High risk of unverified request.',
      );

      expect(result.trustScorePercentage, equals(42));
      expect(result.isApproved, isFalse);
      expect(result.authenticityBadge, contains('SUSPECT'));
    });

    test('AiTrustDetectorService analyzeDocuments simulation', () async {
      final authenticResult = await AiTrustDetectorService.analyzeDocuments(
        patientName: 'Safiqul Islam',
        selectedBloodGroup: 'O+',
        simulateFake: false,
      );

      expect(authenticResult.isApproved, isTrue);
      expect(authenticResult.trustScore, greaterThanOrEqualTo(60));

      final fakeResult = await AiTrustDetectorService.analyzeDocuments(
        patientName: 'Unverified Patient',
        selectedBloodGroup: 'AB-',
        simulateFake: true,
      );

      expect(fakeResult.isApproved, isFalse);
      expect(fakeResult.trustScore, lessThan(60));
    });
  });
}
