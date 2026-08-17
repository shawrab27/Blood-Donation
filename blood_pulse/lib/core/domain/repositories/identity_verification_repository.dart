import '../entities/identity_verification.dart';
import '../enums/domain_enums.dart';

/// Abstract repository contract for identity verification operations.
///
/// Implementations live in `lib/features/auth/data/repositories/`.
/// This interface belongs to the domain layer and has ZERO dependencies
/// on Firebase, HTTP, or any infrastructure package.
abstract interface class IdentityVerificationRepository {
  // ── Create / Submit ──────────────────────────────────────────────────────

  /// Submits a new NID document for verification processing.
  ///
  /// Creates or replaces the [IdentityVerification] record for [userId],
  /// setting status to [VerificationStatus.pendingNID].
  ///
  /// [userId]  — UID of the user submitting the NID.
  /// [nidData] — Parsed NID payload from OCR or manual entry.
  Future<IdentityVerification> submitNID({
    required String userId,
    required NIDDataModel nidData,
  });

  // ── Read ─────────────────────────────────────────────────────────────────

  /// Returns the current [IdentityVerification] for [userId].
  ///
  /// Returns `null` if the user has not yet initiated verification.
  Future<IdentityVerification?> getVerificationStatus(String userId);

  /// Returns all pending verifications awaiting admin review.
  ///
  /// Useful for admin dashboards and batch processing queues.
  Future<List<IdentityVerification>> getPendingVerifications();

  // ── Update / Admin ────────────────────────────────────────────────────────

  /// Approves a verification record and advances status to
  /// [VerificationStatus.adminVerified].
  ///
  /// [userId]          — UID of the user being verified.
  /// [adminId]         — UID of the admin approving the verification.
  Future<IdentityVerification> adminApproveVerification({
    required String userId,
    required String adminId,
  });

  /// Rejects a verification record and resets status to
  /// [VerificationStatus.unverified].
  ///
  /// [userId]          — UID of the user being rejected.
  /// [rejectionReason] — Human-readable explanation for the rejection.
  Future<IdentityVerification> adminRejectVerification({
    required String userId,
    required String rejectionReason,
  });

  /// Marks a verification as NID-system verified (automated pipeline result).
  ///
  /// Advances status to [VerificationStatus.nidVerified].
  Future<IdentityVerification> markNIDVerified(String userId);

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Removes the verification record for [userId].
  ///
  /// Used when a user account is permanently deleted. Throws [StateError]
  /// if no record exists for the given [userId].
  Future<void> deleteVerification(String userId);

  // ── Watch / Stream ────────────────────────────────────────────────────────

  /// Returns a live stream of the [IdentityVerification] for [userId].
  ///
  /// Emits a new value whenever the document changes in the backend.
  /// Emits `null` if the record does not exist.
  Stream<IdentityVerification?> watchVerificationStatus(String userId);
}
