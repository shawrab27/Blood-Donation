import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/health_log_entity.dart';

class HealthCalculatorState {
  const HealthCalculatorState({
    required this.heightCm,
    required this.weightKg,
    required this.systolicBp,
    required this.diastolicBp,
    required this.pulseRateBpm,
    required this.hemoglobinLevel,
    required this.hydrationMl,
    this.lastDonationDate,
    required this.historyLogs,
  });

  final double heightCm;
  final double weightKg;
  final int systolicBp;
  final int diastolicBp;
  final int pulseRateBpm;
  final double hemoglobinLevel;
  final int hydrationMl;
  final DateTime? lastDonationDate;
  final List<HealthLogEntity> historyLogs;

  // ── Computed Calculations ────────────────────────────────────────────────

  double get bmi {
    if (heightCm <= 0) return 0.0;
    final hm = heightCm / 100.0;
    return weightKg / (hm * hm);
  }

  String get bmiCategory {
    final b = bmi;
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Normal Weight';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  double get estimatedBloodVolumeLiters {
    return weightKg * 0.07; // Nadler's estimation rule
  }

  bool get isWeightEligible => weightKg >= 50.0; // Mandatory 50kg requirement

  bool get isHemoglobinEligible => hemoglobinLevel >= 13.0; // Standard male threshold

  bool get isBpEligible =>
      (systolicBp >= 90 && systolicBp <= 140) && (diastolicBp >= 60 && diastolicBp <= 90);

  bool get isPulseEligible => pulseRateBpm >= 60 && pulseRateBpm <= 100;

  int get cooldownDaysRemaining {
    if (lastDonationDate == null) return 0;
    final nextEligible = lastDonationDate!.add(const Duration(days: 120));
    final diff = nextEligible.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isCooldownEligible => cooldownDaysRemaining <= 0;

  bool get overallEligibilityStatus =>
      isWeightEligible &&
      isHemoglobinEligible &&
      isBpEligible &&
      isPulseEligible &&
      isCooldownEligible;

  int get wellnessScore {
    int score = 50;
    if (isWeightEligible) score += 10;
    if (isHemoglobinEligible) score += 15;
    if (isBpEligible) score += 15;
    if (isPulseEligible) score += 10;
    if (bmi >= 18.5 && bmi <= 24.9) score += 10;
    return score.clamp(0, 100);
  }

  HealthCalculatorState copyWith({
    double? heightCm,
    double? weightKg,
    int? systolicBp,
    int? diastolicBp,
    int? pulseRateBpm,
    double? hemoglobinLevel,
    int? hydrationMl,
    DateTime? lastDonationDate,
    List<HealthLogEntity>? historyLogs,
  }) {
    return HealthCalculatorState(
      heightCm:           heightCm ?? this.heightCm,
      weightKg:           weightKg ?? this.weightKg,
      systolicBp:         systolicBp ?? this.systolicBp,
      diastolicBp:        diastolicBp ?? this.diastolicBp,
      pulseRateBpm:       pulseRateBpm ?? this.pulseRateBpm,
      hemoglobinLevel:    hemoglobinLevel ?? this.hemoglobinLevel,
      hydrationMl:        hydrationMl ?? this.hydrationMl,
      lastDonationDate:   lastDonationDate ?? this.lastDonationDate,
      historyLogs:        historyLogs ?? this.historyLogs,
    );
  }
}

class HealthCalculatorsNotifier extends StateNotifier<HealthCalculatorState> {
  HealthCalculatorsNotifier()
      : super(
          HealthCalculatorState(
            heightCm: 172.0,
            weightKg: 68.0,
            systolicBp: 120,
            diastolicBp: 80,
            pulseRateBpm: 72,
            hemoglobinLevel: 14.2,
            hydrationMl: 1500,
            lastDonationDate: DateTime.now().subtract(const Duration(days: 78)), // 78 days ago => 42 remaining
            historyLogs: _sampleLogs,
          ),
        );

  static final List<HealthLogEntity> _sampleLogs = [
    HealthLogEntity(
      logId: 'h1',
      uid: 'user1',
      timestamp: DateTime.now().subtract(const Duration(days: 7)),
      heightCm: 172.0,
      weightKg: 68.0,
      bmiValue: 23.0,
      bmiCategory: 'Normal Weight',
      systolicBp: 120,
      diastolicBp: 80,
      pulseRateBpm: 72,
      hemoglobinLevel: 14.2,
      hydrationMl: 2000,
      isWeightEligible: true,
      isHemoglobinEligible: true,
      isBpEligible: true,
      isPulseEligible: true,
      isCooldownEligible: false,
      cooldownDaysRemaining: 49,
      overallEligibilityStatus: false,
      wellnessScore: 92,
      notes: 'Weekly routine vitals check',
    ),
  ];

  void updateMetrics({
    double? heightCm,
    double? weightKg,
    int? systolicBp,
    int? diastolicBp,
    int? pulseRateBpm,
    double? hemoglobinLevel,
    int? hydrationMl,
    DateTime? lastDonationDate,
  }) {
    state = state.copyWith(
      heightCm: heightCm,
      weightKg: weightKg,
      systolicBp: systolicBp,
      diastolicBp: diastolicBp,
      pulseRateBpm: pulseRateBpm,
      hemoglobinLevel: hemoglobinLevel,
      hydrationMl: hydrationMl,
      lastDonationDate: lastDonationDate,
    );
  }

  void saveCurrentLog({String? notes}) {
    final newLog = HealthLogEntity(
      logId: 'h_${DateTime.now().millisecondsSinceEpoch}',
      uid: 'current_user',
      timestamp: DateTime.now(),
      heightCm: state.heightCm,
      weightKg: state.weightKg,
      bmiValue: state.bmi,
      bmiCategory: state.bmiCategory,
      systolicBp: state.systolicBp,
      diastolicBp: state.diastolicBp,
      pulseRateBpm: state.pulseRateBpm,
      hemoglobinLevel: state.hemoglobinLevel,
      hydrationMl: state.hydrationMl,
      isWeightEligible: state.isWeightEligible,
      isHemoglobinEligible: state.isHemoglobinEligible,
      isBpEligible: state.isBpEligible,
      isPulseEligible: state.isPulseEligible,
      isCooldownEligible: state.isCooldownEligible,
      cooldownDaysRemaining: state.cooldownDaysRemaining,
      overallEligibilityStatus: state.overallEligibilityStatus,
      wellnessScore: state.wellnessScore,
      notes: notes ?? 'Logged from Health Calculators Suite',
    );

    state = state.copyWith(historyLogs: [newLog, ...state.historyLogs]);
  }
}

final healthCalculatorsProvider =
    StateNotifierProvider<HealthCalculatorsNotifier, HealthCalculatorState>(
  (ref) => HealthCalculatorsNotifier(),
);
