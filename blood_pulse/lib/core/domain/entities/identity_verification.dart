import '../enums/domain_enums.dart';

/// Research Feature 1 — Identity Verification Entity
///
/// Represents the full identity-verification state of a BloodPulse user.
/// Used as the source-of-truth for trust gating across the platform:
/// donors with [VerificationStatus.unverified] cannot be shown in emergency search results.
///
/// Academic relevance:
///   Addresses the "counterfeit donor profile" research gap identified in the
///   BloodPulse publication — measuring NID-gated verification impact on
///   response-time quality in p2p blood networks.

/// Immutable NID (National ID) data collected during verification flow.
final class NIDDataModel {
  const NIDDataModel({
    required this.nidNumber,
    required this.fullNameBengali,
    required this.fullNameEnglish,
    required this.dateOfBirth,
    required this.fatherName,
    required this.motherName,
    required this.permanentAddress,
    this.photoBase64,
    this.ocrConfidenceScore,
  });

  /// 17-digit NID number as string (leading zeros preserved).
  final String nidNumber;

  /// Full name as printed on the NID card (Bangla script).
  final String fullNameBengali;

  /// Full name in Latin characters from NID card.
  final String fullNameEnglish;

  /// Date of birth parsed from NID card.
  final DateTime dateOfBirth;

  /// Father's name from NID card.
  final String fatherName;

  /// Mother's name from NID card.
  final String motherName;

  /// Permanent address string (district / thana / village).
  final String permanentAddress;

  /// Base64-encoded JPEG of the NID card photo (optional; used for face match).
  final String? photoBase64;

  /// OCR confidence 0.0–1.0 returned by the document-scanning pipeline.
  final double? ocrConfidenceScore;

  NIDDataModel copyWith({
    String? nidNumber,
    String? fullNameBengali,
    String? fullNameEnglish,
    DateTime? dateOfBirth,
    String? fatherName,
    String? motherName,
    String? permanentAddress,
    String? photoBase64,
    double? ocrConfidenceScore,
  }) {
    return NIDDataModel(
      nidNumber:         nidNumber         ?? this.nidNumber,
      fullNameBengali:   fullNameBengali   ?? this.fullNameBengali,
      fullNameEnglish:   fullNameEnglish   ?? this.fullNameEnglish,
      dateOfBirth:       dateOfBirth       ?? this.dateOfBirth,
      fatherName:        fatherName        ?? this.fatherName,
      motherName:        motherName        ?? this.motherName,
      permanentAddress:  permanentAddress  ?? this.permanentAddress,
      photoBase64:       photoBase64       ?? this.photoBase64,
      ocrConfidenceScore: ocrConfidenceScore ?? this.ocrConfidenceScore,
    );
  }

  @override
  String toString() =>
      'NIDDataModel(nidNumber: $nidNumber, name: $fullNameEnglish, dob: $dateOfBirth)';
}

/// Top-level identity-verification aggregate for a BloodPulse user.
final class IdentityVerification {
  const IdentityVerification({
    required this.userId,
    required this.status,
    this.nidData,
    this.verifiedAt,
    this.verifiedByAdminId,
    this.rejectionReason,
  });

  /// UID of the user this verification belongs to.
  final String userId;

  /// Current lifecycle status in the verification pipeline.
  final VerificationStatus status;

  /// NID payload; populated once the user submits their NID scan.
  final NIDDataModel? nidData;

  /// Timestamp of the most recent successful verification transition.
  final DateTime? verifiedAt;

  /// Admin UID who approved [VerificationStatus.adminVerified]; null otherwise.
  final String? verifiedByAdminId;

  /// Human-readable reason provided if verification was rejected.
  final String? rejectionReason;

  /// Whether this user can be shown as a verified donor in search results.
  bool get isFullyVerified =>
      status == VerificationStatus.nidVerified ||
      status == VerificationStatus.adminVerified;

  IdentityVerification copyWith({
    String? userId,
    VerificationStatus? status,
    NIDDataModel? nidData,
    DateTime? verifiedAt,
    String? verifiedByAdminId,
    String? rejectionReason,
  }) {
    return IdentityVerification(
      userId:             userId             ?? this.userId,
      status:             status             ?? this.status,
      nidData:            nidData            ?? this.nidData,
      verifiedAt:         verifiedAt         ?? this.verifiedAt,
      verifiedByAdminId:  verifiedByAdminId  ?? this.verifiedByAdminId,
      rejectionReason:    rejectionReason    ?? this.rejectionReason,
    );
  }

  @override
  String toString() =>
      'IdentityVerification(userId: $userId, status: $status)';
}
