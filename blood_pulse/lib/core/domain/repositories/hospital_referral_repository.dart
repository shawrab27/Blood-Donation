import '../entities/hospital_referral.dart';
import '../enums/domain_enums.dart';

/// Abstract repository contract for hospital referral operations.
///
/// Implementations live in `lib/features/blood_request/data/repositories/`.
/// This interface belongs to the domain layer and has ZERO dependencies
/// on Firebase, HTTP, or any infrastructure package.
abstract interface class HospitalReferralRepository {
  // ── Create ───────────────────────────────────────────────────────────────

  /// Issues a new [HospitalRequisitionToken] and creates a [HospitalReferral]
  /// linked to an existing blood request.
  ///
  /// [requestId]     — ID of the blood request this referral is associated with.
  /// [patientUserId] — UID of the patient creating the referral.
  /// [hospitalCode]  — BNMC-registered hospital code (e.g., "DMCH", "BSMMU").
  /// [hospitalName]  — Human-readable hospital name.
  ///
  /// Returns the newly created [HospitalReferral] with [EmrValidationStatus.tokenIssued].
  Future<HospitalReferral> issueRequisitionToken({
    required String requestId,
    required String patientUserId,
    required String hospitalCode,
    required String hospitalName,
    String? bloodGroupRequired,
    int unitsRequired = 1,
    String? attendingPhysicianName,
  });

  // ── Read ─────────────────────────────────────────────────────────────────

  /// Fetches a single [HospitalReferral] by its [referralId].
  ///
  /// Returns `null` if no referral exists with that ID.
  Future<HospitalReferral?> getReferralById(String referralId);

  /// Returns all referrals linked to the given blood [requestId].
  Future<List<HospitalReferral>> getReferralsByRequestId(String requestId);

  /// Returns all referrals for a specific [patientUserId], most-recent first.
  Future<List<HospitalReferral>> getReferralsByPatient(String patientUserId);

  // ── Update ───────────────────────────────────────────────────────────────

  /// Assigns a bed to an existing referral and advances its status to
  /// [EmrValidationStatus.bedAssigned].
  ///
  /// [referralId] — Target referral document ID.
  /// [bedId]      — Hospital bed identifier (e.g., "ICU-B-12").
  /// [wardName]   — Ward name (e.g., "Haematology", "ICU").
  Future<HospitalReferral> assignBed({
    required String referralId,
    required String bedId,
    required String wardName,
  });

  /// Validates the EMR linkage for a referral and advances its status to
  /// [EmrValidationStatus.emrValidated].
  ///
  /// [referralId]           — Target referral document ID.
  /// [patientHemoglobinLevel] — Hb value pulled from the hospital EMR.
  /// [additionalNotes]      — Optional clinical notes from the EMR.
  Future<HospitalReferral> validateEMR({
    required String referralId,
    double? patientHemoglobinLevel,
    String? additionalNotes,
  });

  /// Updates the EMR validation status to a specific [EmrValidationStatus].
  ///
  /// Use for setting [EmrValidationStatus.validationFailed] after an API error.
  Future<HospitalReferral> updateEmrStatus({
    required String referralId,
    required EmrValidationStatus status,
  });

  // ── Delete ───────────────────────────────────────────────────────────────

  /// Revokes a referral's requisition token and soft-deletes the referral.
  ///
  /// Throws [StateError] if the referral does not exist.
  Future<void> revokeReferral(String referralId);

  // ── Watch / Stream ────────────────────────────────────────────────────────

  /// Returns a live stream of all referrals for [patientUserId].
  ///
  /// Emits a new list whenever any referral document changes in the backend.
  Stream<List<HospitalReferral>> watchReferralsByPatient(String patientUserId);
}
