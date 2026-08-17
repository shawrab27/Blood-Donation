import '../enums/domain_enums.dart';

/// Research Feature 3 — Organisation Federation Entity
///
/// Models a donor's affiliation with a recognised blood-donation organisation
/// operating in Bangladesh, plus the full metadata of the org itself.
///
/// Academic relevance:
///   Measures inter-organisational request routing efficiency — a key variable
///   in the federated-network chapter of the BloodPulse academic paper.

/// Metadata for a registered federated organisation.
final class FederatedOrgModel {
  const FederatedOrgModel({
    required this.orgId,
    required this.type,
    required this.displayName,
    required this.chapter,
    this.logoAssetPath,
    this.contactEmail,
    this.contactPhone,
    this.verifiedMemberCount = 0,
    this.isActive = true,
  });

  /// Unique org identifier (e.g., "badhan_buet_2024").
  final String orgId;

  /// Organisation category from the federation taxonomy.
  final OrgFederationType type;

  /// Human-readable name shown in UI (e.g., "Badhan – BUET Chapter").
  final String displayName;

  /// Chapter or campus name (e.g., "BUET", "DMCH", "Community – Dhaka North").
  final String chapter;

  /// Path to local org logo asset (optional).
  final String? logoAssetPath;

  final String? contactEmail;
  final String? contactPhone;

  /// Total number of verified member-donors under this org.
  final int verifiedMemberCount;

  /// Whether this org is currently accepting new member registrations.
  final bool isActive;

  /// Display label combining type and chapter.
  String get fullLabel => '$displayName · $chapter';

  FederatedOrgModel copyWith({
    String? orgId,
    OrgFederationType? type,
    String? displayName,
    String? chapter,
    String? logoAssetPath,
    String? contactEmail,
    String? contactPhone,
    int? verifiedMemberCount,
    bool? isActive,
  }) {
    return FederatedOrgModel(
      orgId:               orgId               ?? this.orgId,
      type:                type                ?? this.type,
      displayName:         displayName         ?? this.displayName,
      chapter:             chapter             ?? this.chapter,
      logoAssetPath:       logoAssetPath       ?? this.logoAssetPath,
      contactEmail:        contactEmail        ?? this.contactEmail,
      contactPhone:        contactPhone        ?? this.contactPhone,
      verifiedMemberCount: verifiedMemberCount ?? this.verifiedMemberCount,
      isActive:            isActive            ?? this.isActive,
    );
  }

  @override
  String toString() => 'FederatedOrgModel($orgId, type: $type)';
}

/// A donor's membership record within a [FederatedOrgModel].
final class OrgFederation {
  const OrgFederation({
    required this.userId,
    required this.org,
    required this.membershipId,
    required this.joinedAt,
    this.role = 'member',
    this.isVerifiedByOrg = false,
  });

  /// UID of the donor.
  final String userId;

  /// The organisation this membership belongs to.
  final FederatedOrgModel org;

  /// Org-issued membership card number / ID string.
  final String membershipId;

  /// Date the donor joined this organisation.
  final DateTime joinedAt;

  /// Role within the org (e.g., "member", "coordinator", "chapter_head").
  final String role;

  /// Whether the org's coordinator has confirmed this membership.
  final bool isVerifiedByOrg;

  OrgFederation copyWith({
    String? userId,
    FederatedOrgModel? org,
    String? membershipId,
    DateTime? joinedAt,
    String? role,
    bool? isVerifiedByOrg,
  }) {
    return OrgFederation(
      userId:          userId          ?? this.userId,
      org:             org             ?? this.org,
      membershipId:    membershipId    ?? this.membershipId,
      joinedAt:        joinedAt        ?? this.joinedAt,
      role:            role            ?? this.role,
      isVerifiedByOrg: isVerifiedByOrg ?? this.isVerifiedByOrg,
    );
  }

  @override
  String toString() =>
      'OrgFederation(userId: $userId, org: ${org.orgId}, role: $role)';
}

/// Convenience lookup: maps [OrgFederationType] → canonical display name.
abstract final class OrgFederationMapping {
  static const Map<OrgFederationType, String> displayNames = {
    OrgFederationType.badhan:              'Badhan',
    OrgFederationType.sandhani:            'Sandhani',
    OrgFederationType.asharAlo:            'Ashar Alo',
    OrgFederationType.independentCivilian: 'Independent Civilian',
  };

  static const Map<OrgFederationType, String> descriptions = {
    OrgFederationType.badhan:
        'University-based voluntary blood donor organisation',
    OrgFederationType.sandhani:
        'Medical college–affiliated blood-donation union',
    OrgFederationType.asharAlo:
        'NGO-operated community blood bank network',
    OrgFederationType.independentCivilian:
        'Individual civilian with no formal organisational affiliation',
  };

  static String nameFor(OrgFederationType type) =>
      displayNames[type] ?? type.name;

  static String descriptionFor(OrgFederationType type) =>
      descriptions[type] ?? '';
}
