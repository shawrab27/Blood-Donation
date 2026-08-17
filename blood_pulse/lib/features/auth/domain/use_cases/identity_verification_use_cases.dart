/// Feature: Identity Verification
/// Layer: Domain — Use Cases
///
/// Use cases for the Identity Verification feature.
/// Implementations are pure Dart — zero Flutter/Firebase dependencies.
library;

import '../../../../../../core/domain/entities/identity_verification.dart';
import '../../../../../../core/domain/enums/domain_enums.dart';
import '../../../../../../core/domain/repositories/identity_verification_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SubmitNIDUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Submits a donor's National ID (NID) document for automated OCR processing
/// and backend verification.
///
/// Sets the user's [VerificationStatus] to [VerificationStatus.pendingNID]
/// and returns the newly created [IdentityVerification] record.
final class SubmitNIDUseCase {
  const SubmitNIDUseCase(this._repository);

  final IdentityVerificationRepository _repository;

  /// [userId]  — UID of the user submitting the NID.
  /// [nidData] — Parsed NID payload from the OCR scanning pipeline.
  Future<IdentityVerification> call({
    required String userId,
    required NIDDataModel nidData,
  }) {
    return _repository.submitNID(userId: userId, nidData: nidData);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GetVerificationStatusUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Retrieves the current identity-verification state for a given user.
///
/// Returns the [IdentityVerification] record, or `null` if the user has
/// not yet initiated the verification flow.
final class GetVerificationStatusUseCase {
  const GetVerificationStatusUseCase(this._repository);

  final IdentityVerificationRepository _repository;

  Future<IdentityVerification?> call(String userId) {
    return _repository.getVerificationStatus(userId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AdminApproveVerificationUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Allows a platform admin to manually approve a pending verification record.
///
/// Advances the user's [VerificationStatus] to [VerificationStatus.adminVerified]
/// and records the [adminId] who authorised the approval.
final class AdminApproveVerificationUseCase {
  const AdminApproveVerificationUseCase(this._repository);

  final IdentityVerificationRepository _repository;

  /// [userId]  — UID of the user whose verification is being approved.
  /// [adminId] — UID of the approving admin (written to the audit trail).
  Future<IdentityVerification> call({
    required String userId,
    required String adminId,
  }) {
    return _repository.adminApproveVerification(
      userId: userId,
      adminId: adminId,
    );
  }
}
