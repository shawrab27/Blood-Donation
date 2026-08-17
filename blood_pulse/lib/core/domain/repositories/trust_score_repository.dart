import '../entities/trust_score_model.dart';
import '../enums/domain_enums.dart';

/// Abstract repository contract for trust score read/write operations.
///
/// Implementations live in `lib/features/donor/data/repositories/`.
/// This interface belongs to the domain layer and has ZERO dependencies
/// on Firebase, HTTP, or any infrastructure package.
abstract interface class TrustScoreRepository {
  // ── Create / Calculate ───────────────────────────────────────────────────

  /// Computes a fresh trust score from raw signal inputs and persists it.
  ///
  /// Delegates computation to [TrustScoreCalculator.calculate] in the entity
  /// layer, then writes the result to the backend.
  Future<TrustScoreModel> calculateAndSave({
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
  });

  // ── Read ─────────────────────────────────────────────────────────────────

  /// Fetches the current [TrustScoreModel] for [userId].
  ///
  /// Returns `null` if no score has been calculated yet for this user.
  Future<TrustScoreModel?> getTrustScore(String userId);

  /// Returns all trust score records where [FraudRiskLevel] equals
  /// [riskLevel]. Useful for admin review dashboards.
  Future<List<TrustScoreModel>> getScoresByRiskLevel(FraudRiskLevel riskLevel);

  // ── Update ────────────────────────────────────────────────────────────────

  /// Appends a new fraud flag label to an existing score record.
  ///
  /// [userId]    — UID of the flagged user.
  /// [flagLabel] — Machine-readable flag string (e.g., "multiple_city_switch").
  Future<TrustScoreModel> appendFraudFlag({
    required String userId,
    required String flagLabel,
  });

  /// Increments [TrustScoreModel.reportedFraudCount] by 1 and triggers
  /// a score recalculation for [userId].
  Future<TrustScoreModel> recordFraudReport(String userId);

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Deletes the trust score record for [userId].
  ///
  /// Called when a user account is permanently removed.
  /// Throws [StateError] if no record exists.
  Future<void> deleteTrustScore(String userId);

  // ── Watch / Stream ────────────────────────────────────────────────────────

  /// Returns a live stream of the [TrustScoreModel] for [userId].
  ///
  /// Emits a new value whenever the score document changes in the backend.
  /// Emits `null` if the record does not yet exist.
  Stream<TrustScoreModel?> watchTrustScore(String userId);
}
