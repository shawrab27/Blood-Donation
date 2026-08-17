import 'package:flutter_riverpod/flutter_riverpod.dart';

class HealthCalculatorState {
  const HealthCalculatorState({
    this.heightCm = 170.0,
    this.weightKg = 68.0,
    this.systolicBp = 120,
    this.diastolicBp = 80,
    this.pulseBpm = 72,
    this.hydrationMl = 1800.0,
    this.hemoglobinLevel = 14.2,
    this.lastDonationDate,
  });

  final double heightCm;
  final double weightKg;
  final int systolicBp;
  final int diastolicBp;
  final int pulseBpm;
  final double hydrationMl;
  final double hemoglobinLevel;
  final DateTime? lastDonationDate;

  /// BMI formula: weight / height_m^2
  double get bmi {
    if (heightCm <= 0) return 0.0;
    final heightM = heightCm / 100.0;
    return weightKg / (heightM * heightM);
  }

  /// Minimum weight threshold check (>= 50 kg requirement)
  bool get isWeightEligible => weightKg >= 50.0;

  /// BMI optimal range check (18.5 - 24.9)
  bool get isBmiOptimal => bmi >= 18.5 && bmi <= 24.9;

  /// Hydration target progress (0.0 to 1.0 based on 2500 mL goal)
  double get hydrationProgress {
    final progress = hydrationMl / 2500.0;
    return progress > 1.0 ? 1.0 : progress;
  }

  /// 120-Day Donation Countdown Days Remaining
  int get cooldownDaysRemaining {
    if (lastDonationDate == null) return 0;
    final nextEligible = lastDonationDate!.add(const Duration(days: 120));
    final diff = nextEligible.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isPhysiologicallyFit => isWeightEligible && isBmiOptimal && cooldownDaysRemaining == 0;

  HealthCalculatorState copyWith({
    double? heightCm,
    double? weightKg,
    int? systolicBp,
    int? diastolicBp,
    int? pulseBpm,
    double? hydrationMl,
    double? hemoglobinLevel,
    DateTime? lastDonationDate,
  }) {
    return HealthCalculatorState(
      heightCm:         heightCm ?? this.heightCm,
      weightKg:         weightKg ?? this.weightKg,
      systolicBp:       systolicBp ?? this.systolicBp,
      diastolicBp:      diastolicBp ?? this.diastolicBp,
      pulseBpm:         pulseBpm ?? this.pulseBpm,
      hydrationMl:      hydrationMl ?? this.hydrationMl,
      hemoglobinLevel:  hemoglobinLevel ?? this.hemoglobinLevel,
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
    );
  }
}

class HealthCalculatorNotifier extends StateNotifier<HealthCalculatorState> {
  HealthCalculatorNotifier() : super(const HealthCalculatorState());

  void updateMetrics({
    double? heightCm,
    double? weightKg,
    int? systolicBp,
    int? diastolicBp,
    int? pulseBpm,
    double? hydrationMl,
    double? hemoglobinLevel,
    DateTime? lastDonationDate,
  }) {
    state = state.copyWith(
      heightCm: heightCm,
      weightKg: weightKg,
      systolicBp: systolicBp,
      diastolicBp: diastolicBp,
      pulseBpm: pulseBpm,
      hydrationMl: hydrationMl,
      hemoglobinLevel: hemoglobinLevel,
      lastDonationDate: lastDonationDate,
    );
  }

  void addHydration(double amountMl) {
    state = state.copyWith(hydrationMl: state.hydrationMl + amountMl);
  }
}

final healthCalculatorProvider = StateNotifierProvider<HealthCalculatorNotifier, HealthCalculatorState>((ref) {
  return HealthCalculatorNotifier();
});
