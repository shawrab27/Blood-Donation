/// Feature: Trust Score
/// Layer: Domain — Use Cases
///
/// Use cases for the Trust Score feature.
/// Implementations are pure Dart — zero Flutter/Firebase dependencies.
library;

import '../../../../../../core/domain/entities/trust_score_model.dart';
import '../../../../../../core/domain/enums/domain_enums.dart';
import '../../../../../../core/domain/repositories/trust_score_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CalculateTrustScoreUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Computes a fresh composite trust score from raw signal inputs and
/// persists it via [TrustScoreRepository].
///
/// Score weights (total: 100 pts):
///   NID verification     → 30 pts
///   Phone verification   → 10 pts
///   Email verification   →  5 pts
///   Donation history     → 20 pts (capped at 20 donations)
///   Request fulfilment   → 15 pts
///   Account longevity    → 10 pts (capped at 365 days)
///   Fraud penalty        → −15 pts per confirmed report (floored at 0)
final class CalculateTrustScoreUseCase {
  const CalculateTrustScoreUseCase(this._repository);

  final TrustScoreRepository _repository;

  Future<TrustScoreModel> call({
    required String userId,
    required bool isNIDVerified,
    required bool isPhoneVerified,
    required bool isEmailVerified,
    required int totalDonationsConfirmed,
    required int totalRequestsPosted,
    required int totalRequestsFulfilled,
    required int reportedFraudCount,
    required int accountAgeInDays,
    List<String> fraudFlags = const [],
  }) {
    return _repository.calculateAndSave(
      userId: userId,
      isNIDVerified: isNIDVerified,
      isPhoneVerified: isPhoneVerified,
      isEmailVerified: isEmailVerified,
      totalDonationsConfirmed: totalDonationsConfirmed,
      totalRequestsPosted: totalRequestsPosted,
      totalRequestsFulfilled: totalRequestsFulfilled,
      reportedFraudCount: reportedFraudCount,
      accountAgeInDays: accountAgeInDays,
      fraudFlags: fraudFlags,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GetTrustScoreUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Retrieves the most recently persisted [TrustScoreModel] for a given user.
///
/// Returns `null` if no score has been calculated for this [userId] yet.
/// Use [CalculateTrustScoreUseCase] first to create an initial score.
final class GetTrustScoreUseCase {
  const GetTrustScoreUseCase(this._repository);

  final TrustScoreRepository _repository;

  Future<TrustScoreModel?> call(String userId) {
    return _repository.getTrustScore(userId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ReportFraudUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Records a community fraud report against a user and triggers an automatic
/// trust-score recalculation.
///
/// Each confirmed fraud report subtracts 15 points from the raw score.
/// Once a user's score drops below 25, their [FraudRiskLevel] is elevated
/// to [FraudRiskLevel.critical] and their requests are hidden from search.
final class ReportFraudUseCase {
  const ReportFraudUseCase(this._repository);

  final TrustScoreRepository _repository;

  /// [reportedUserId] — UID of the user being reported for fraud.
  /// [flagLabel]      — Machine-readable fraud signal label to append
  ///                    (e.g., "fake_donation_claim", "multiple_city_switch").
  Future<TrustScoreModel> call({
    required String reportedUserId,
    String? flagLabel,
  }) async {
    if (flagLabel != null) {
      await _repository.appendFraudFlag(
        userId: reportedUserId,
        flagLabel: flagLabel,
      );
    }
    return _repository.recordFraudReport(reportedUserId);
  }
}
