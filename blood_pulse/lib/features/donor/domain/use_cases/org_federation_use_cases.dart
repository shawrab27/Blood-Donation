/// Feature: Organisation Federation
/// Layer: Domain — Use Cases
///
/// Use cases for the Organisation Federation feature.
/// Implementations are pure Dart — zero Flutter/Firebase dependencies.
library;

import '../../../../../../core/domain/entities/org_federation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OrgMembershipRepository interface (local to this feature)
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal repository abstraction used by org-federation use cases.
/// The concrete implementation lives in `lib/features/donor/data/`.
abstract interface class OrgMembershipRepository {
  Future<OrgFederation> registerMembership({
    required String userId,
    required FederatedOrgModel org,
    required String membershipId,
    String role,
  });

  Future<OrgFederation?> getMembership({
    required String userId,
    required String orgId,
  });

  Future<OrgFederation> verifyMembership({
    required String userId,
    required String orgId,
  });

  Future<List<FederatedOrgModel>> getFederatedOrgs({bool activeOnly});
}

// ─────────────────────────────────────────────────────────────────────────────
// RegisterOrgMembershipUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Registers a donor as a member of a federated blood-donation organisation.
///
/// Creates an [OrgFederation] record with [isVerifiedByOrg] set to `false`
/// until a coordinator verifies the membership card.
final class RegisterOrgMembershipUseCase {
  const RegisterOrgMembershipUseCase(this._repository);

  final OrgMembershipRepository _repository;

  /// [userId]      — UID of the donor joining the organisation.
  /// [org]         — The [FederatedOrgModel] to join.
  /// [membershipId] — The physical membership card number issued by the org.
  /// [role]        — Role within the org (default: "member").
  Future<OrgFederation> call({
    required String userId,
    required FederatedOrgModel org,
    required String membershipId,
    String role = 'member',
  }) {
    return _repository.registerMembership(
      userId: userId,
      org: org,
      membershipId: membershipId,
      role: role,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VerifyOrgMembershipUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Marks an existing [OrgFederation] membership as verified by the
/// organisation coordinator ([isVerifiedByOrg] → `true`).
///
/// A verified membership boosts the donor's trust score and unlocks
/// the org-member badge on their profile.
final class VerifyOrgMembershipUseCase {
  const VerifyOrgMembershipUseCase(this._repository);

  final OrgMembershipRepository _repository;

  /// [userId] — UID of the donor whose membership is being confirmed.
  /// [orgId]  — Organisation ID whose coordinator is approving the membership.
  Future<OrgFederation> call({
    required String userId,
    required String orgId,
  }) {
    return _repository.verifyMembership(userId: userId, orgId: orgId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GetFederatedOrgsUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Returns the list of recognised federated blood-donation organisations.
///
/// Used to populate the org-selection picker in the Communities and
/// Profile screens.
final class GetFederatedOrgsUseCase {
  const GetFederatedOrgsUseCase(this._repository);

  final OrgMembershipRepository _repository;

  /// [activeOnly] — If `true`, returns only orgs currently accepting members.
  Future<List<FederatedOrgModel>> call({bool activeOnly = true}) {
    return _repository.getFederatedOrgs(activeOnly: activeOnly);
  }
}
