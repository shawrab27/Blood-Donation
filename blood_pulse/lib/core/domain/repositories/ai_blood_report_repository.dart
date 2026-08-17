import '../entities/ai_blood_report_result.dart';
import '../enums/domain_enums.dart';

/// Abstract repository contract for AI blood report operations.
///
/// Implementations live in `lib/features/lab_report/data/repositories/`.
/// This interface belongs to the domain layer and has ZERO dependencies
/// on Firebase, HTTP, or any infrastructure package.
abstract interface class AIBloodReportRepository {
  // ── Create / Submit ─────────────────────────────────────────────────────

  /// Submits a new lab report image/PDF for AI analysis.
  ///
  /// [donorId]   — UID of the submitting donor.
  /// [isMale]    — Biological sex for reference range selection.
  /// [imageData] — Raw bytes of the uploaded report image or PDF.
  ///
  /// Returns the pending [AIBloodReportResult] with [AICompatibilityVerdict.inconclusive]
  /// until the backend pipeline completes processing.
  Future<AIBloodReportResult> submitReportForAnalysis({
    required String donorId,
    required bool isMale,
    required List<int> imageData,
    String? rawReportText,
  });

  // ── Read ────────────────────────────────────────────────────────────────

  /// Fetches a single report result by its [reportId].
  ///
  /// Returns `null` if no report exists with that ID.
  Future<AIBloodReportResult?> getReportById(String reportId);

  /// Returns all AI report results for a given [donorId], most-recent first.
  Future<List<AIBloodReportResult>> getReportsByDonor(String donorId);

  /// Returns the most recent report for [donorId] with an effective verdict
  /// of [AICompatibilityVerdict.compatible], or `null` if none exists.
  Future<AIBloodReportResult?> getLatestCompatibleReport(String donorId);

  // ── Update / Clinician Override ─────────────────────────────────────────

  /// Records a clinician's manual override of the AI verdict.
  ///
  /// [reportId]         — Target report document ID.
  /// [overrideVerdict]  — The clinician's replacement verdict.
  /// [clinicianNotes]   — Free-text justification (required for audit trail).
  Future<AIBloodReportResult> applyClinicianOverride({
    required String reportId,
    required AICompatibilityVerdict overrideVerdict,
    required String clinicianNotes,
  });

  // ── Delete ──────────────────────────────────────────────────────────────

  /// Permanently deletes a report document by [reportId].
  ///
  /// Should only be called with admin-level privileges. Throws [StateError]
  /// if the report does not exist.
  Future<void> deleteReport(String reportId);

  // ── Watch / Stream ──────────────────────────────────────────────────────

  /// Returns a live stream of all reports for [donorId].
  ///
  /// Emits a new list whenever any report document changes in the backend.
  Stream<List<AIBloodReportResult>> watchReportsByDonor(String donorId);
}
