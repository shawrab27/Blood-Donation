/// HealthLogModel representing vital calculation logs, BMI, and weight eligibility.
class HealthLogModel {
  const HealthLogModel({
    required this.logId,
    required this.uid,
    required this.timestamp,
    required this.heightCm,
    required this.weightKg,
    required this.bmiValue,
    required this.pulseRateBpm,
    required this.bloodPressure,
    required this.hydrationMl,
    required this.hemoglobinLevel,
  });

  final String logId;
  final String uid;
  final DateTime timestamp;
  final double heightCm;
  final double weightKg;
  final double bmiValue;
  final int pulseRateBpm;
  final String bloodPressure; // e.g. "120/80"
  final double hydrationMl;
  final double hemoglobinLevel;

  /// Helper evaluating minimum 50.0 kg weight requirement for blood donation safety.
  bool get isWeightEligible => weightKg >= 50.0;

  /// Evaluates whether BMI is within normal range (18.5 - 24.9).
  bool get isBmiOptimal => bmiValue >= 18.5 && bmiValue <= 24.9;

  HealthLogModel copyWith({
    String? logId,
    String? uid,
    DateTime? timestamp,
    double? heightCm,
    double? weightKg,
    double? bmiValue,
    int? pulseRateBpm,
    String? bloodPressure,
    double? hydrationMl,
    double? hemoglobinLevel,
  }) {
    return HealthLogModel(
      logId:           logId ?? this.logId,
      uid:             uid ?? this.uid,
      timestamp:       timestamp ?? this.timestamp,
      heightCm:        heightCm ?? this.heightCm,
      weightKg:        weightKg ?? this.weightKg,
      bmiValue:        bmiValue ?? this.bmiValue,
      pulseRateBpm:    pulseRateBpm ?? this.pulseRateBpm,
      bloodPressure:   bloodPressure ?? this.bloodPressure,
      hydrationMl:     hydrationMl ?? this.hydrationMl,
      hemoglobinLevel: hemoglobinLevel ?? this.hemoglobinLevel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'logId': logId,
      'uid': uid,
      'timestamp': timestamp.toIso8601String(),
      'heightCm': heightCm,
      'weightKg': weightKg,
      'bmiValue': bmiValue,
      'pulseRateBpm': pulseRateBpm,
      'bloodPressure': bloodPressure,
      'hydrationMl': hydrationMl,
      'hemoglobinLevel': hemoglobinLevel,
    };
  }

  factory HealthLogModel.fromMap(Map<String, dynamic> map) {
    return HealthLogModel(
      logId: map['logId'] as String,
      uid: map['uid'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      heightCm: (map['heightCm'] as num).toDouble(),
      weightKg: (map['weightKg'] as num).toDouble(),
      bmiValue: (map['bmiValue'] as num).toDouble(),
      pulseRateBpm: map['pulseRateBpm'] as int,
      bloodPressure: map['bloodPressure'] as String,
      hydrationMl: (map['hydrationMl'] as num).toDouble(),
      hemoglobinLevel: (map['hemoglobinLevel'] as num).toDouble(),
    );
  }
}
