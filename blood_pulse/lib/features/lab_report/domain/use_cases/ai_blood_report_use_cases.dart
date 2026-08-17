/// Feature: AI Blood Report Analyzer
/// Layer: Domain — Use Cases
///
/// Use cases for the AI Blood Report Analyzer feature.
/// Implementations are pure Dart — zero Flutter/Firebase dependencies.
library;

import '../../../../../../core/domain/entities/ai_blood_report_result.dart';
import '../../../../../../core/domain/enums/domain_enums.dart';
import '../../../../../../core/domain/repositories/ai_blood_report_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SubmitReportForAnalysisUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Submits a donor's lab report image/PDF to the AI analysis pipeline.
///
/// Returns a pending [AIBloodReportResult] with
/// [AICompatibilityVerdict.inconclusive] until the backend AI model
/// completes its CBC parameter extraction and compatibility assessment.
///
/// Academic relevance:
///   Addresses the "manual haemoglobin pre-screening bottleneck" research gap
///   (H6 in the BloodPulse paper) — measuring whether AI-assisted CBC parsing
///   reduces donor screening time by ≥60% vs. manual clinic visits.
final class SubmitReportForAnalysisUseCase {
  const SubmitReportForAnalysisUseCase(this._repository);

  final AIBloodReportRepository _repository;

  /// [donorId]      — UID of the donor submitting the report.
  /// [isMale]       — Biological sex (affects WHO CBC reference ranges).
  /// [imageData]    — Raw bytes of the uploaded lab report image or PDF.
  /// [rawReportText] — Optional pre-extracted OCR text for faster processing.
  Future<AIBloodReportResult> call({
    required String donorId,
    required bool isMale,
    required List<int> imageData,
    String? rawReportText,
  }) {
    return _repository.submitReportForAnalysis(
      donorId: donorId,
      isMale: isMale,
      imageData: imageData,
      rawReportText: rawReportText,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GetReportResultUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Retrieves a specific AI blood report result by its [reportId].
///
/// Useful for polling the status of a submitted report while the AI
/// pipeline is processing, or for displaying a historical result.
/// Returns `null` if no report exists with that ID.
final class GetReportResultUseCase {
  const GetReportResultUseCase(this._repository);

  final AIBloodReportRepository _repository;

  Future<AIBloodReportResult?> call(String reportId) {
    return _repository.getReportById(reportId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ClinicianOverrideVerdictUseCase
// ─────────────────────────────────────────────────────────────────────────────

/// Allows a licensed clinician to override the AI-derived compatibility
/// verdict for a specific report.
///
/// The clinician override is recorded separately from the original AI verdict
/// ([AIBloodReportResult.clinicianOverrideVerdict]) and always takes
/// precedence in [AIBloodReportResult.effectiveVerdict].
///
/// Academic relevance:
///   Models the human-in-the-loop override pathway specified in the
///   BloodPulse clinical-safety section, ensuring AI recommendations
///   never bypass trained medical judgement.
final class ClinicianOverrideVerdictUseCase {
  const ClinicianOverrideVerdictUseCase(this._repository);

  final AIBloodReportRepository _repository;

  /// [reportId]        — ID of the report being overridden.
  /// [overrideVerdict] — The clinician's replacement verdict.
  /// [clinicianNotes]  — Free-text justification (required for the audit trail).
  Future<AIBloodReportResult> call({
    required String reportId,
    required AICompatibilityVerdict overrideVerdict,
    required String clinicianNotes,
  }) {
    return _repository.applyClinicianOverride(
      reportId: reportId,
      overrideVerdict: overrideVerdict,
      clinicianNotes: clinicianNotes,
    );
  }
}
