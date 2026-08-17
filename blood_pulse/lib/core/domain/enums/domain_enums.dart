/// BloodPulse — Research Feature Shared Enums
///
/// All enum values documented with academic-publication-level descriptions
/// matching the 6 Research Gap Feature Models defined in PHASE 1.
library;

// ─────────────────────────────────────────────────────────────────────────────
// 1. IDENTITY VERIFICATION
// ─────────────────────────────────────────────────────────────────────────────

/// Verification lifecycle for donor/patient identity within the trust chain.
///
/// Research relevance: counterfeit-identity mitigation in p2p blood networks.
enum VerificationStatus {
  /// No identity check has been initiated.
  unverified,

  /// User has submitted NID data but OCR/backend validation is pending.
  pendingNID,

  /// NID number and biometric have been validated against BNEC database.
  nidVerified,

  /// A human admin has completed an out-of-band identity confirmation.
  adminVerified,
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. ORGANISATION FEDERATION
// ─────────────────────────────────────────────────────────────────────────────

/// Formal blood-donor organisation categories active in Bangladesh.
///
/// Research relevance: federated-network formation and inter-org referral
/// routing in the BloodPulse academic publication.
enum OrgFederationType {
  /// Badhan — university-based voluntary blood donors.
  badhan,

  /// Sandhani — medical-college-affiliated blood-donation union.
  sandhani,

  /// Ashar Alo — NGO-operated community blood bank network.
  asharAlo,

  /// Independent civilian with no formal org affiliation.
  independentCivilian,
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. HOSPITAL REFERRAL
// ─────────────────────────────────────────────────────────────────────────────

/// Current validation state of an EMR (Electronic Medical Record) linkage.
enum EmrValidationStatus {
  /// No EMR linkage has been attempted.
  notLinked,

  /// A hospital requisition token has been issued and is awaiting bed assignment.
  tokenIssued,

  /// Bed ID has been assigned; record is awaiting full EMR sync.
  bedAssigned,

  /// Full EMR data has been fetched and validated.
  emrValidated,

  /// Validation failed (invalid token, expired session, or hospital API error).
  validationFailed,
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. DONATION ELIGIBILITY
// ─────────────────────────────────────────────────────────────────────────────

/// Reason a donor's eligibility is currently locked.
///
/// Modelled from WHO and DGDA (Bangladesh) blood-donation guidelines.
enum EligibilityLockReason {
  /// Donor is within the mandatory 120-day (≈4-month) inter-donation gap.
  cooldownPeriod,

  /// Haemoglobin level is below WHO minimum (12.5 g/dL female / 13.0 g/dL male).
  lowHaemoglobin,

  /// Active medication or recent surgery flagged by eligibility engine.
  medicalDeferral,

  /// Donor has voluntarily paused availability.
  voluntaryPause,

  /// Donor is eligible — no lock is active.
  none,
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. AI BLOOD REPORT — COMPATIBILITY VERDICT
// ─────────────────────────────────────────────────────────────────────────────

/// AI-derived compatibility decision for a processed blood report.
enum AICompatibilityVerdict {
  /// Blood parameters are within normal clinical ranges; donation is safe.
  compatible,

  /// Parameters are borderline; manual re-evaluation recommended.
  borderline,

  /// Parameters indicate the donor/patient should not proceed.
  incompatible,

  /// The AI model could not produce a conclusive result (e.g., noisy scan).
  inconclusive,
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. TRUST SCORE — FRAUD RISK LEVEL
// ─────────────────────────────────────────────────────────────────────────────

/// Heuristic fraud-risk band derived from the TrustScore engine.
enum FraudRiskLevel {
  /// Score 75–100 — highly reliable, verified profile.
  low,

  /// Score 50–74 — moderate activity, minor unverified fields.
  moderate,

  /// Score 25–49 — significant trust gaps or inconsistency flags.
  high,

  /// Score 0–24 — strong fraud signals, manual review required.
  critical,
}
