import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/models/health_log_model.dart';
import 'package:blood_pulse/providers/health_calculator_provider.dart';

void main() {
  group('HealthCalculator Unit Tests', () {
    test('BMI calculation formula: weightKg / (heightM)^2', () {
      const state = HealthCalculatorState(heightCm: 170.0, weightKg: 68.0);
      // 68 / (1.7 * 1.7) = 23.5294...
      expect(state.bmi, closeTo(23.53, 0.01));
      expect(state.isBmiOptimal, isTrue);
    });

    test('Weight eligibility threshold: weightKg >= 50.0 kg', () {
      const eligibleState = HealthCalculatorState(weightKg: 52.0);
      expect(eligibleState.isWeightEligible, isTrue);

      const ineligibleState = HealthCalculatorState(weightKg: 46.5);
      expect(ineligibleState.isWeightEligible, isFalse);
    });

    test('HealthLogModel weight eligibility getter', () {
      final log = HealthLogModel(
        logId: 'log_1',
        uid: 'usr_1',
        timestamp: DateTime.now(),
        heightCm: 175.0,
        weightKg: 55.0,
        bmiValue: 17.96,
        pulseRateBpm: 72,
        bloodPressure: '120/80',
        hydrationMl: 2000,
        hemoglobinLevel: 14.5,
      );

      expect(log.isWeightEligible, isTrue);
    });
  });
}
