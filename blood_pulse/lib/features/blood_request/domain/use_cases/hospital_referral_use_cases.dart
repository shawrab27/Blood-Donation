/// Feature: Hospital Referral
/// Layer: Domain — Use Cases
///
/// Use cases for the Hospital Referral feature.
/// Implementations are pure Dart — zero Flutter/Firebase dependencies.
library;

import '../../../../../../core/domain/entities/hospital_referral.dart';
import '../../../../../../core/domain/enums/domain_enums.dart';
import '../../../../../../core/domain/repositories/hospital_referral_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IssueRequisitionTokenUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Issues a new hospital requisition token and creates the initial
/// [HospitalReferral] record linked to an active blood request.
///
/// Sets EMR status to [EmrValidationStatus.tokenIssued].
final class IssueRequisitionTokenUseCase {
  const IssueRequisitionTokenUseCase(this._repository);

  final HospitalReferralRepository _repository;

  Future<HospitalReferral> call({
    required String requestId,
    required String patientUserId,
    required String hospitalCode,
    required String hospitalName,
    String? bloodGroupRequired,
    int unitsRequired = 1,
    String? attendingPhysicianName,
  }) {
    return _repository.issueRequisitionToken(
      requestId: requestId,
      patientUserId: patientUserId,
      hospitalCode: hospitalCode,
      hospitalName: hospitalName,
      bloodGroupRequired: bloodGroupRequired,
      unitsRequired: unitsRequired,
      attendingPhysicianName: attendingPhysicianName,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ValidateEMRUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Validates the Electronic Medical Record (EMR) for an existing hospital
/// referral and advances its status to [EmrValidationStatus.emrValidated].
///
/// Called after the hospital's API confirms the EMR data is consistent
/// with the issued requisition token.
final class ValidateEMRUseCase {
  const ValidateEMRUseCase(this._repository);

  final HospitalReferralRepository _repository;

  /// [referralId]            — ID of the target referral.
  /// [patientHemoglobinLevel] — Patient Hb level from the EMR (in g/dL).
  /// [additionalNotes]       — Optional clinical notes from the EMR system.
  Future<HospitalReferral> call({
    required String referralId,
    double? patientHemoglobinLevel,
    String? additionalNotes,
  }) {
    return _repository.validateEMR(
      referralId: referralId,
      patientHemoglobinLevel: patientHemoglobinLevel,
      additionalNotes: additionalNotes,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AssignBedUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Assigns a physical hospital bed to an existing referral and advances
/// the EMR status to [EmrValidationStatus.bedAssigned].
final class AssignBedUseCase {
  const AssignBedUseCase(this._repository);

  final HospitalReferralRepository _repository;

  /// [referralId] — ID of the target referral.
  /// [bedId]      — Hospital bed identifier (e.g., "ICU-B-12").
  /// [wardName]   — Ward name (e.g., "Haematology", "Surgery").
  Future<HospitalReferral> call({
    required String referralId,
    required String bedId,
    required String wardName,
  }) {
    return _repository.assignBed(
      referralId: referralId,
      bedId: bedId,
      wardName: wardName,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GetReferralStatusUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Retrieves the current [HospitalReferral] for a given [referralId].
///
/// Returns `null` if no referral exists with that ID.
final class GetReferralStatusUseCase {
  const GetReferralStatusUseCase(this._repository);

  final HospitalReferralRepository _repository;

  Future<HospitalReferral?> call(String referralId) {
    return _repository.getReferralById(referralId);
  }
}
