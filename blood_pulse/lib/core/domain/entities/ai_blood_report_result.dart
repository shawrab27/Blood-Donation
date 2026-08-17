import '../enums/domain_enums.dart';

/// Research Feature 6 — AI Blood Report Result Entity
///
/// Stores structured output from BloodPulse's AI blood-report analyzer:
/// CBC (Complete Blood Count) parameter readings parsed from a lab report
/// image/PDF, plus the AI model's compatibility verdict.
///
/// Academic relevance:
///   Addresses the "manual haemoglobin pre-screening bottleneck" research gap
///   — measuring how AI-assisted CBC parsing reduces donor screening time by ≥60%
///   vs. manual clinic visits (H6 in the BloodPulse paper).
///
/// Clinical reference ranges (WHO adult norms):
///   Haemoglobin (Hb)  : Male 13.0–17.5 g/dL   | Female 12.0–15.5 g/dL
///   Platelet (PLT)    : 150,000–400,000 /μL
///   WBC (Leukocytes)  : 4,000–11,000 /μL
///   RBC (Erythrocytes): Male 4.5–5.9 M/μL       | Female 4.1–5.1 M/μL

/// Normal range specification for a single CBC parameter.
final class CbcNormalRange {
  const CbcNormalRange({
    required this.parameterName,
    required this.unit,
    required this.maleLower,
    required this.maleUpper,
    required this.femaleLower,
    required this.femaleUpper,
  });

  final String parameterName;
  final String unit;
  final double maleLower;
  final double maleUpper;
  final double femaleLower;
  final double femaleUpper;

  bool isInRange(double value, {required bool isMale}) {
    final double lower = isMale ? maleLower : femaleLower;
    final double upper = isMale ? maleUpper : femaleUpper;
    return value >= lower && value <= upper;
  }
}

/// Canonical WHO CBC reference ranges used by the AI analysis engine.
abstract final class CbcReferenceRanges {
  static const CbcNormalRange hemoglobin = CbcNormalRange(
    parameterName: 'Hemoglobin',
    unit: 'g/dL',
    maleLower:   13.0, maleUpper:   17.5,
    femaleLower: 12.0, femaleUpper: 15.5,
  );

  static const CbcNormalRange platelet = CbcNormalRange(
    parameterName: 'Platelet Count',
    unit: '/μL (×10³)',
    maleLower: 150, maleUpper: 400,
    femaleLower: 150, femaleUpper: 400,
  );

  static const CbcNormalRange wbc = CbcNormalRange(
    parameterName: 'White Blood Cell (WBC)',
    unit: '/μL (×10³)',
    maleLower: 4.0, maleUpper: 11.0,
    femaleLower: 4.0, femaleUpper: 11.0,
  );

  static const CbcNormalRange rbc = CbcNormalRange(
    parameterName: 'Red Blood Cell (RBC)',
    unit: 'M/μL',
    maleLower: 4.5, maleUpper: 5.9,
    femaleLower: 4.1, femaleUpper: 5.1,
  );
}

/// Full AI blood report analysis result for a single donor report submission.
final class AIBloodReportResult {
  const AIBloodReportResult({
    required this.reportId,
    required this.donorId,
    required this.analyzedAt,
    required this.verdict,
    required this.isMale,
    this.hemoglobinGdl,
    this.plateletPerMicroLiter,
    this.wbcPerMicroLiter,
    this.rbcMillionPerMicroLiter,
    this.aiModelVersion,
    this.ocrConfidenceScore,
    this.rawReportText,
    this.flaggedAbnormalParameters = const [],
    this.clinicianOverrideVerdict,
    this.clinicianNotes,
  });

  /// Unique report document ID.
  final String reportId;

  /// UID of the donor who submitted this report.
  final String donorId;

  /// UTC timestamp when AI analysis was completed.
  final DateTime analyzedAt;

  /// AI-derived compatibility verdict.
  final AICompatibilityVerdict verdict;

  /// Biological sex (affects reference ranges).
  final bool isMale;

  // ── CBC Parameter Readings ───────────────────────────────────────────────

  /// Hemoglobin in grams per decilitre (g/dL).
  final double? hemoglobinGdl;

  /// Platelet count in cells per microlitre (×10³/μL stored as raw value).
  final double? plateletPerMicroLiter;

  /// White Blood Cell count in cells per microlitre (×10³/μL).
  final double? wbcPerMicroLiter;

  /// Red Blood Cell count in millions per microlitre (M/μL).
  final double? rbcMillionPerMicroLiter;

  // ── AI Pipeline Metadata ─────────────────────────────────────────────────

  /// AI model version string (e.g., "bloodpulse-cbc-v2.1.0").
  final String? aiModelVersion;

  /// OCR confidence score 0.0–1.0 for the report image parsing step.
  final double? ocrConfidenceScore;

  /// Raw OCR-extracted text from the lab report (for audit trail).
  final String? rawReportText;

  /// List of parameter names flagged as outside normal range.
  final List<String> flaggedAbnormalParameters;

  // ── Clinician Override ───────────────────────────────────────────────────

  /// If a clinician manually overrides the AI verdict, stored here.
  final AICompatibilityVerdict? clinicianOverrideVerdict;

  /// Free-text notes from the overriding clinician.
  final String? clinicianNotes;

  // ── Computed Properties ──────────────────────────────────────────────────

  /// The effective (final) verdict: clinician override takes precedence.
  AICompatibilityVerdict get effectiveVerdict =>
      clinicianOverrideVerdict ?? verdict;

  /// True if the donor is cleared to participate in blood donation.
  bool get isClearedForDonation =>
      effectiveVerdict == AICompatibilityVerdict.compatible;

  /// True if haemoglobin is within the WHO normal range.
  bool get isHemoglobinNormal =>
      hemoglobinGdl != null &&
      CbcReferenceRanges.hemoglobin.isInRange(hemoglobinGdl!, isMale: isMale);

  /// True if platelet count is within the WHO normal range.
  bool get isPlateletNormal =>
      plateletPerMicroLiter != null &&
      CbcReferenceRanges.platelet.isInRange(plateletPerMicroLiter!, isMale: isMale);

  /// True if WBC count is within the WHO normal range.
  bool get isWbcNormal =>
      wbcPerMicroLiter != null &&
      CbcReferenceRanges.wbc.isInRange(wbcPerMicroLiter!, isMale: isMale);

  /// True if RBC count is within the WHO normal range.
  bool get isRbcNormal =>
      rbcMillionPerMicroLiter != null &&
      CbcReferenceRanges.rbc.isInRange(rbcMillionPerMicroLiter!, isMale: isMale);

  /// Count of abnormal CBC parameters detected.
  int get abnormalParameterCount => flaggedAbnormalParameters.length;

  AIBloodReportResult copyWith({
    String? reportId,
    String? donorId,
    DateTime? analyzedAt,
    AICompatibilityVerdict? verdict,
    bool? isMale,
    double? hemoglobinGdl,
    double? plateletPerMicroLiter,
    double? wbcPerMicroLiter,
    double? rbcMillionPerMicroLiter,
    String? aiModelVersion,
    double? ocrConfidenceScore,
    String? rawReportText,
    List<String>? flaggedAbnormalParameters,
    AICompatibilityVerdict? clinicianOverrideVerdict,
    String? clinicianNotes,
  }) {
    return AIBloodReportResult(
      reportId:                  reportId                  ?? this.reportId,
      donorId:                   donorId                   ?? this.donorId,
      analyzedAt:                analyzedAt                ?? this.analyzedAt,
      verdict:                   verdict                   ?? this.verdict,
      isMale:                    isMale                    ?? this.isMale,
      hemoglobinGdl:             hemoglobinGdl             ?? this.hemoglobinGdl,
      plateletPerMicroLiter:     plateletPerMicroLiter     ?? this.plateletPerMicroLiter,
      wbcPerMicroLiter:          wbcPerMicroLiter          ?? this.wbcPerMicroLiter,
      rbcMillionPerMicroLiter:   rbcMillionPerMicroLiter   ?? this.rbcMillionPerMicroLiter,
      aiModelVersion:            aiModelVersion            ?? this.aiModelVersion,
      ocrConfidenceScore:        ocrConfidenceScore        ?? this.ocrConfidenceScore,
      rawReportText:             rawReportText             ?? this.rawReportText,
      flaggedAbnormalParameters: flaggedAbnormalParameters ?? this.flaggedAbnormalParameters,
      clinicianOverrideVerdict:  clinicianOverrideVerdict  ?? this.clinicianOverrideVerdict,
      clinicianNotes:            clinicianNotes            ?? this.clinicianNotes,
    );
  }

  @override
  String toString() =>
      'AIBloodReportResult(reportId: $reportId, verdict: $effectiveVerdict, '
      'hb: $hemoglobinGdl g/dL, plt: $plateletPerMicroLiter /μL)';
}
