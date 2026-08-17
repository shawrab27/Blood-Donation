import '../enums/domain_enums.dart';

/// Research Feature 5 — Donation Eligibility Engine
///
/// Pure business logic that determines whether a donor is currently eligible
/// to donate, calculates the exact days remaining in their 120-day cooldown
/// window, and produces a locked/available availability state.
///
/// Academic relevance:
///   Addresses the WHO-guideline compliance research gap — measuring automatic
///   cooldown enforcement impact on donor haemoglobin safety outcomes.
///
/// References:
///   • WHO Blood Donor Selection Guidelines (2012), Section 4.3
///   • DGDA Bangladesh Blood Transfusion Regulation (2002), Rule 6(2)

/// The 120-day (≈4-month) mandatory inter-donation interval.
const Duration kDonationCooldown = Duration(days: 120);

/// Minimum haemoglobin levels in g/dL per WHO guidelines.
const double kMinHemoglobinFemale = 12.5;
const double kMinHemoglobinMale   = 13.0;

/// Immutable model representing the eligibility state snapshot for a donor.
final class DonationEligibilityEngine {
  const DonationEligibilityEngine({
    required this.donorId,
    required this.lastDonationDate,
    required this.lockReason,
    this.hemoglobinLevel,
    this.isMale = true,
    this.hasMedicalDeferral = false,
    this.isVoluntarilyPaused = false,
    this.calculatedAt,
  });

  /// UID of the donor.
  final String donorId;

  /// UTC date of the donor's most recent confirmed blood donation.
  /// Null if the donor has never donated.
  final DateTime? lastDonationDate;

  /// The active lock reason (or [EligibilityLockReason.none] if eligible).
  final EligibilityLockReason lockReason;

  /// Latest haemoglobin reading in g/dL (from AI report or manual entry).
  final double? hemoglobinLevel;

  /// True for male donors (affects minimum haemoglobin threshold).
  final bool isMale;

  /// True if a physician has flagged a medical deferral.
  final bool hasMedicalDeferral;

  /// True if the donor manually toggled themselves as unavailable.
  final bool isVoluntarilyPaused;

  /// When this eligibility snapshot was computed.
  final DateTime? calculatedAt;

  // ── Computed Properties ──────────────────────────────────────────────────

  /// True if the donor is currently eligible to donate.
  bool get isEligible => lockReason == EligibilityLockReason.none;

  /// True if the donor's availability should be locked in the UI.
  bool get isAutoLocked => !isEligible;

  /// Exact number of days remaining in the cooldown window.
  ///
  /// Returns 0 if the cooldown has elapsed or [lastDonationDate] is null.
  int get cooldownDaysRemaining {
    if (lastDonationDate == null) return 0;
    final DateTime eligibleAfter =
        lastDonationDate!.add(kDonationCooldown);
    final Duration remaining =
        eligibleAfter.difference(DateTime.now());
    return remaining.isNegative ? 0 : remaining.inDays;
  }

  /// Next eligible donation date; null if no prior donation.
  DateTime? get nextEligibleDate =>
      lastDonationDate?.add(kDonationCooldown);

  /// Formatted countdown string for UI display (e.g., "45 days remaining").
  String get countdownLabel {
    final int days = cooldownDaysRemaining;
    if (days == 0) return isEligible ? 'Eligible to donate' : 'Ineligible';
    return '$days ${days == 1 ? 'day' : 'days'} remaining';
  }

  /// Progress fraction (0.0 → 1.0) of the cooldown elapsed.
  ///
  /// Returns 1.0 (fully elapsed) if no prior donation.
  double get cooldownProgress {
    if (lastDonationDate == null) return 1.0;
    final DateTime eligibleAfter = lastDonationDate!.add(kDonationCooldown);
    final Duration elapsed = DateTime.now().difference(lastDonationDate!);
    final Duration total = eligibleAfter.difference(lastDonationDate!);
    return (elapsed.inSeconds / total.inSeconds).clamp(0.0, 1.0);
  }

  // ── Factory / Static Constructor ─────────────────────────────────────────

  /// Evaluates all eligibility signals and returns a fully-computed snapshot.
  factory DonationEligibilityEngine.evaluate({
    required String donorId,
    DateTime? lastDonationDate,
    double? hemoglobinLevel,
    bool isMale = true,
    bool hasMedicalDeferral = false,
    bool isVoluntarilyPaused = false,
  }) {
    EligibilityLockReason lock = EligibilityLockReason.none;

    // Priority order: medical > voluntary > haemoglobin > cooldown
    if (hasMedicalDeferral) {
      lock = EligibilityLockReason.medicalDeferral;
    } else if (isVoluntarilyPaused) {
      lock = EligibilityLockReason.voluntaryPause;
    } else if (hemoglobinLevel != null) {
      final double minHb =
          isMale ? kMinHemoglobinMale : kMinHemoglobinFemale;
      if (hemoglobinLevel < minHb) {
        lock = EligibilityLockReason.lowHaemoglobin;
      }
    }

    if (lock == EligibilityLockReason.none && lastDonationDate != null) {
      if (DateTime.now().isBefore(lastDonationDate.add(kDonationCooldown))) {
        lock = EligibilityLockReason.cooldownPeriod;
      }
    }

    return DonationEligibilityEngine(
      donorId:             donorId,
      lastDonationDate:    lastDonationDate,
      lockReason:          lock,
      hemoglobinLevel:     hemoglobinLevel,
      isMale:              isMale,
      hasMedicalDeferral:  hasMedicalDeferral,
      isVoluntarilyPaused: isVoluntarilyPaused,
      calculatedAt:        DateTime.now(),
    );
  }

  DonationEligibilityEngine copyWith({
    String? donorId,
    DateTime? lastDonationDate,
    EligibilityLockReason? lockReason,
    double? hemoglobinLevel,
    bool? isMale,
    bool? hasMedicalDeferral,
    bool? isVoluntarilyPaused,
    DateTime? calculatedAt,
  }) {
    return DonationEligibilityEngine(
      donorId:             donorId             ?? this.donorId,
      lastDonationDate:    lastDonationDate    ?? this.lastDonationDate,
      lockReason:          lockReason          ?? this.lockReason,
      hemoglobinLevel:     hemoglobinLevel     ?? this.hemoglobinLevel,
      isMale:              isMale              ?? this.isMale,
      hasMedicalDeferral:  hasMedicalDeferral  ?? this.hasMedicalDeferral,
      isVoluntarilyPaused: isVoluntarilyPaused ?? this.isVoluntarilyPaused,
      calculatedAt:        calculatedAt        ?? this.calculatedAt,
    );
  }

  @override
  String toString() =>
      'DonationEligibilityEngine(donorId: $donorId, eligible: $isEligible, '
      'daysRemaining: $cooldownDaysRemaining, lock: $lockReason)';
}
