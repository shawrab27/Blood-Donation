/// Feature: Donation Eligibility Engine
/// Layer: Domain — Use Cases
///
/// Use cases for the Donation Eligibility Engine feature.
/// Implementations are pure Dart — zero Flutter/Firebase dependencies.
library;

import '../../../../../../core/domain/entities/donation_eligibility_engine.dart';
import '../../../../../../core/domain/enums/domain_enums.dart';
import '../../../../../../providers/profile_countdown_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EvaluateEligibilityUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Computes a full eligibility snapshot for a donor using the
/// [DonationEligibilityEngine] business rules.
///
/// Applies the WHO-mandated 120-day inter-donation cooldown, haemoglobin
/// thresholds, medical deferral flags, and voluntary-pause state.
///
/// This is a pure domain use case — it delegates evaluation to the
/// [DonationEligibilityEngine.evaluate] factory and requires no I/O.
final class EvaluateEligibilityUseCase {
  const EvaluateEligibilityUseCase();

  /// Returns a computed [DonationEligibilityEngine] snapshot.
  ///
  /// [donorId]           — UID of the donor being evaluated.
  /// [lastDonationDate]  — UTC date of the most recent confirmed donation;
  ///                       pass `null` if the donor has never donated.
  /// [hemoglobinLevel]   — Latest Hb reading in g/dL from AI report or manual
  ///                       entry; pass `null` to skip Hb gating.
  /// [isMale]            — Affects WHO minimum Hb threshold.
  /// [hasMedicalDeferral] — True if a physician has flagged a deferral.
  /// [isVoluntarilyPaused] — True if the donor manually paused availability.
  DonationEligibilityEngine call({
    required String donorId,
    DateTime? lastDonationDate,
    double? hemoglobinLevel,
    bool isMale = true,
    bool hasMedicalDeferral = false,
    bool isVoluntarilyPaused = false,
  }) {
    return DonationEligibilityEngine.evaluate(
      donorId: donorId,
      lastDonationDate: lastDonationDate,
      hemoglobinLevel: hemoglobinLevel,
      isMale: isMale,
      hasMedicalDeferral: hasMedicalDeferral,
      isVoluntarilyPaused: isVoluntarilyPaused,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UpdateLastDonationDateUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Records a confirmed donation date for a donor and triggers a countdown
/// reset in the local profile state.
///
/// This use case writes to the [ProfileCountdownNotifier] (Riverpod provider)
/// so the 120-day countdown widget updates immediately without a full reload.
final class UpdateLastDonationDateUseCase {
  const UpdateLastDonationDateUseCase(this._notifier);

  final ProfileCountdownNotifier _notifier;

  /// [donationDate] — The confirmed UTC date the donation was performed.
  void call(DateTime donationDate) {
    _notifier.recordDonation(donationDate);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ToggleVoluntaryPauseUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Re-evaluates and updates a donor's eligibility by toggling their voluntary
/// pause state.
///
/// When [isPaused] is `true`, the donor's [EligibilityLockReason] will be set
/// to [EligibilityLockReason.voluntaryPause] regardless of other signals
/// (except medical deferral which always takes precedence).
final class ToggleVoluntaryPauseUseCase {
  const ToggleVoluntaryPauseUseCase();

  /// Returns the updated [DonationEligibilityEngine] snapshot after toggling.
  ///
  /// [current]  — The donor's current eligibility snapshot.
  /// [isPaused] — The desired voluntary-pause state.
  DonationEligibilityEngine call({
    required DonationEligibilityEngine current,
    required bool isPaused,
  }) {
    return DonationEligibilityEngine.evaluate(
      donorId: current.donorId,
      lastDonationDate: current.lastDonationDate,
      hemoglobinLevel: current.hemoglobinLevel,
      isMale: current.isMale,
      hasMedicalDeferral: current.hasMedicalDeferral,
      isVoluntarilyPaused: isPaused,
    );
  }
}
