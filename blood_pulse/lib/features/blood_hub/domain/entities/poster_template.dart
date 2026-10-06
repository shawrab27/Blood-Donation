// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';

/// Types of emergency social media posters supported in BloodPulse.
enum PosterTemplateType {
  /// Template 1: Patient photo + Urgent red banner & clinical details.
  withPhoto,

  /// Template 2: Text-only high-contrast clean alert with giant blood group hero.
  textOnly,

  /// Template 3: Full-bleed crimson gradient story alert with custom editable text.
  blank,
}

/// Data payload required to render an emergency blood donation poster.
class PosterData {
  final String patientName;
  final String bloodGroup;
  final String location;
  final int unitsNeeded;
  final String urgencyLevel; // HIGH, MEDIUM, LOW, CRITICAL
  final String? photoPath;
  final Uint8List? photoBytes;
  final String condition;
  final String? hospitalName;
  final String? contactNumber;
  final String? dateNeeded;
  final String? customHeadline;
  final String? customMessage;

  const PosterData({
    required this.patientName,
    required this.bloodGroup,
    required this.location,
    required this.unitsNeeded,
    required this.urgencyLevel,
    this.photoPath,
    this.photoBytes,
    required this.condition,
    this.hospitalName,
    this.contactNumber,
    this.dateNeeded,
    this.customHeadline,
    this.customMessage,
  });

  /// Factory for empty or default placeholder data.
  factory PosterData.empty() {
    return const PosterData(
      patientName: 'Patient Name',
      bloodGroup: 'B+',
      location: 'Dhaka, Bangladesh',
      unitsNeeded: 1,
      urgencyLevel: 'HIGH',
      condition: 'Emergency Transfusion',
      hospitalName: 'Hospital / Clinic',
      contactNumber: '+880 1700-000000',
      dateNeeded: 'Today / আজ',
      customHeadline: 'URGENT BLOOD NEEDED',
      customMessage: 'A critical patient urgently needs blood. Please share and donate.',
    );
  }

  /// Immutably creates a modified clone of this [PosterData].
  PosterData copyWith({
    String? patientName,
    String? bloodGroup,
    String? location,
    int? unitsNeeded,
    String? urgencyLevel,
    String? photoPath,
    Uint8List? photoBytes,
    String? condition,
    String? hospitalName,
    String? contactNumber,
    String? dateNeeded,
    String? customHeadline,
    String? customMessage,
  }) {
    return PosterData(
      patientName: patientName ?? this.patientName,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      location: location ?? this.location,
      unitsNeeded: unitsNeeded ?? this.unitsNeeded,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      photoPath: photoPath ?? this.photoPath,
      photoBytes: photoBytes ?? this.photoBytes,
      condition: condition ?? this.condition,
      hospitalName: hospitalName ?? this.hospitalName,
      contactNumber: contactNumber ?? this.contactNumber,
      dateNeeded: dateNeeded ?? this.dateNeeded,
      customHeadline: customHeadline ?? this.customHeadline,
      customMessage: customMessage ?? this.customMessage,
    );
  }
}

/// Composite configuration class binding template type and data.
class PosterTemplateConfig {
  final PosterTemplateType type;
  final PosterData data;

  const PosterTemplateConfig({
    required this.type,
    required this.data,
  });
}
