import '../enums/domain_enums.dart';

/// Research Feature 4 — Hospital Referral Entity
///
/// Models the chain of custody when a blood request is linked to a formal
/// hospital admission: from the initial Requisition Token issued by the
/// hospital's blood bank, through bed assignment, to full EMR validation.
///
/// Academic relevance:
///   Addresses the "unverified recipient" research gap — measuring whether
///   hospital-token gating reduces fraudulent blood requests by ≥40%
///   (H3 in the BloodPulse paper).

/// A Hospital Requisition Token issued by a registered hospital blood bank.
///
/// Tokens follow the format: `<HOSPITAL_CODE>-<YYYY>-<6-DIGIT-SERIAL>`
/// e.g. `DMCH-2025-004821`
final class HospitalRequisitionToken {
  const HospitalRequisitionToken({
    required this.tokenId,
    required this.hospitalCode,
    required this.hospitalName,
    required this.issuedAt,
    required this.expiresAt,
    this.isRevoked = false,
  });

  /// Unique token string (format: HOSPITAL_CODE-YYYY-SERIAL).
  final String tokenId;

  /// BNMC-registered hospital code (e.g., "DMCH", "SSMC", "BSMMU").
  final String hospitalCode;

  /// Human-readable hospital name.
  final String hospitalName;

  /// UTC timestamp when the token was issued.
  final DateTime issuedAt;

  /// Tokens expire after 72 hours to prevent stale requests.
  final DateTime expiresAt;

  /// True if the hospital has cancelled this requisition.
  final bool isRevoked;

  /// Whether the token is still valid at the current moment.
  bool get isValid => !isRevoked && DateTime.now().isBefore(expiresAt);

  /// Remaining validity duration; returns [Duration.zero] if expired.
  Duration get remainingValidity {
    final now = DateTime.now();
    return expiresAt.isAfter(now) ? expiresAt.difference(now) : Duration.zero;
  }

  @override
  String toString() =>
      'HospitalRequisitionToken($tokenId, valid: $isValid)';
}

/// Full hospital referral model — aggregates token + bed + EMR status.
final class HospitalReferral {
  const HospitalReferral({
    required this.referralId,
    required this.requestId,
    required this.patientUserId,
    required this.requisitionToken,
    required this.emrStatus,
    this.bedId,
    this.wardName,
    this.attendingPhysicianName,
    this.bloodGroupRequired,
    this.unitsRequired = 1,
    this.patientHemoglobinLevel,
    this.emrValidatedAt,
    this.additionalNotes,
  });

  /// Unique referral document ID.
  final String referralId;

  /// Foreign key to the blood request this referral is associated with.
  final String requestId;

  /// UID of the patient user account.
  final String patientUserId;

  /// The hospital-issued token that initiated this referral chain.
  final HospitalRequisitionToken requisitionToken;

  /// Current EMR validation lifecycle state.
  final EmrValidationStatus emrStatus;

  /// Hospital bed identifier (e.g., "ICU-B-12").
  final String? bedId;

  /// Ward name (e.g., "Haematology", "ICU", "Surgery").
  final String? wardName;

  /// Name of the attending physician who signed the requisition.
  final String? attendingPhysicianName;

  /// Blood group string (e.g., "B+", "O-", "AB+").
  final String? bloodGroupRequired;

  /// Number of blood units (bags) required.
  final int unitsRequired;

  /// Patient's latest haemoglobin reading in g/dL (from EMR).
  final double? patientHemoglobinLevel;

  /// UTC timestamp when EMR validation was completed.
  final DateTime? emrValidatedAt;

  /// Optional clinical notes from the referral form.
  final String? additionalNotes;

  /// True when a bed has been assigned AND EMR has been validated.
  bool get isFullyVerified =>
      bedId != null && emrStatus == EmrValidationStatus.emrValidated;

  HospitalReferral copyWith({
    String? referralId,
    String? requestId,
    String? patientUserId,
    HospitalRequisitionToken? requisitionToken,
    EmrValidationStatus? emrStatus,
    String? bedId,
    String? wardName,
    String? attendingPhysicianName,
    String? bloodGroupRequired,
    int? unitsRequired,
    double? patientHemoglobinLevel,
    DateTime? emrValidatedAt,
    String? additionalNotes,
  }) {
    return HospitalReferral(
      referralId:              referralId              ?? this.referralId,
      requestId:               requestId               ?? this.requestId,
      patientUserId:           patientUserId           ?? this.patientUserId,
      requisitionToken:        requisitionToken        ?? this.requisitionToken,
      emrStatus:               emrStatus               ?? this.emrStatus,
      bedId:                   bedId                   ?? this.bedId,
      wardName:                wardName                ?? this.wardName,
      attendingPhysicianName:  attendingPhysicianName  ?? this.attendingPhysicianName,
      bloodGroupRequired:      bloodGroupRequired      ?? this.bloodGroupRequired,
      unitsRequired:           unitsRequired           ?? this.unitsRequired,
      patientHemoglobinLevel:  patientHemoglobinLevel  ?? this.patientHemoglobinLevel,
      emrValidatedAt:          emrValidatedAt          ?? this.emrValidatedAt,
      additionalNotes:         additionalNotes         ?? this.additionalNotes,
    );
  }

  @override
  String toString() =>
      'HospitalReferral($referralId, emrStatus: $emrStatus, bed: $bedId)';
}
