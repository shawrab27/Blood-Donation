/// Health Log Entity representing vital health metrics, BMI, and donation eligibility logs.
class HealthLogEntity {
  const HealthLogEntity({
    required this.logId,
    required this.uid,
    required this.timestamp,
    required this.heightCm,
    required this.weightKg,
    required this.bmiValue,
    required this.bmiCategory,
    required this.systolicBp,
    required this.diastolicBp,
    required this.pulseRateBpm,
    required this.hemoglobinLevel,
    required this.hydrationMl,
    required this.isWeightEligible,
    required this.isHemoglobinEligible,
    required this.isBpEligible,
    required this.isPulseEligible,
    required this.isCooldownEligible,
    required this.cooldownDaysRemaining,
    required this.overallEligibilityStatus,
    required this.wellnessScore,
    this.notes,
  });

  final String logId;
  final String uid;
  final DateTime timestamp;
  final double heightCm;
  final double weightKg;
  final double bmiValue;
  final String bmiCategory; // 'Underweight', 'Normal', 'Overweight', 'Obese'
  final int systolicBp;
  final int diastolicBp;
  final int pulseRateBpm;
  final double hemoglobinLevel;
  final int hydrationMl;
  final bool isWeightEligible; // ≥ 50 kg requirement
  final bool isHemoglobinEligible; // ≥ 13.0 g/dL (M) / ≥ 12.5 g/dL (F)
  final bool isBpEligible; // 90/60 - 140/90
  final bool isPulseEligible; // 60 - 100 bpm
  final bool isCooldownEligible; // 120-day rule
  final int cooldownDaysRemaining;
  final bool overallEligibilityStatus;
  final int wellnessScore; // 0 - 100
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'logId': logId,
      'uid': uid,
      'timestamp': timestamp.toIso8601String(),
      'heightCm': heightCm,
      'weightKg': weightKg,
      'bmiValue': bmiValue,
      'bmiCategory': bmiCategory,
      'systolicBp': systolicBp,
      'diastolicBp': diastolicBp,
      'pulseRateBpm': pulseRateBpm,
      'hemoglobinLevel': hemoglobinLevel,
      'hydrationMl': hydrationMl,
      'isWeightEligible': isWeightEligible,
      'isHemoglobinEligible': isHemoglobinEligible,
      'isBpEligible': isBpEligible,
      'isPulseEligible': isPulseEligible,
      'isCooldownEligible': isCooldownEligible,
      'cooldownDaysRemaining': cooldownDaysRemaining,
      'overallEligibilityStatus': overallEligibilityStatus,
      'wellnessScore': wellnessScore,
      'notes': notes,
    };
  }

  factory HealthLogEntity.fromJson(Map<String, dynamic> json) {
    return HealthLogEntity(
      logId: json['logId'] as String,
      uid: json['uid'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      heightCm: (json['heightCm'] as num).toDouble(),
      weightKg: (json['weightKg'] as num).toDouble(),
      bmiValue: (json['bmiValue'] as num).toDouble(),
      bmiCategory: json['bmiCategory'] as String,
      systolicBp: json['systolicBp'] as int,
      diastolicBp: json['diastolicBp'] as int,
      pulseRateBpm: json['pulseRateBpm'] as int,
      hemoglobinLevel: (json['hemoglobinLevel'] as num).toDouble(),
      hydrationMl: json['hydrationMl'] as int,
      isWeightEligible: json['isWeightEligible'] as bool,
      isHemoglobinEligible: json['isHemoglobinEligible'] as bool,
      isBpEligible: json['isBpEligible'] as bool,
      isPulseEligible: json['isPulseEligible'] as bool,
      isCooldownEligible: json['isCooldownEligible'] as bool,
      cooldownDaysRemaining: json['cooldownDaysRemaining'] as int,
      overallEligibilityStatus: json['overallEligibilityStatus'] as bool,
      wellnessScore: json['wellnessScore'] as int,
      notes: json['notes'] as String?,
    );
  }
}
