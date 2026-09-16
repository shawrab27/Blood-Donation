class BloodScienceArticle {
  final int id;
  final String title;
  final String content;
  final String? image;

  BloodScienceArticle({
    required this.id,
    required this.title,
    required this.content,
    this.image,
  });

  factory BloodScienceArticle.fromJson(Map<String, dynamic> json) {
    return BloodScienceArticle(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      image: json['image'],
    );
  }
}

class CompatibilityRule {
  final int id;
  final String bloodGroup;
  final String canGiveTo;
  final String canReceiveFrom;

  CompatibilityRule({
    required this.id,
    required this.bloodGroup,
    required this.canGiveTo,
    required this.canReceiveFrom,
  });

  factory CompatibilityRule.fromJson(Map<String, dynamic> json) {
    return CompatibilityRule(
      id: json['id'],
      bloodGroup: json['blood_group'],
      canGiveTo: json['can_give_to'],
      canReceiveFrom: json['can_receive_from'],
    );
  }
}

class DonationGuideSection {
  final int id;
  final String category;
  final String title;
  final String content;

  DonationGuideSection({
    required this.id,
    required this.category,
    required this.title,
    required this.content,
  });

  factory DonationGuideSection.fromJson(Map<String, dynamic> json) {
    return DonationGuideSection(
      id: json['id'],
      category: json['category'],
      title: json['title'],
      content: json['content'],
    );
  }
}

class EmergencyContact {
  final int id;
  final String name;
  final String phoneNumber;
  final String description;
  final bool is24Hours;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.description,
    required this.is24Hours,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phone_number'],
      description: json['description'] ?? '',
      is24Hours: json['is_24_hours'] ?? true,
    );
  }
}

class RecoveryTimelineStep {
  final int id;
  final int hourMark;
  final String title;
  final String description;
  final String activityGuideline;
  final String avoidList;

  RecoveryTimelineStep({
    required this.id,
    required this.hourMark,
    required this.title,
    required this.description,
    required this.activityGuideline,
    required this.avoidList,
  });

  factory RecoveryTimelineStep.fromJson(Map<String, dynamic> json) {
    return RecoveryTimelineStep(
      id: json['id'],
      hourMark: json['hour_mark'],
      title: json['title'],
      description: json['description'],
      activityGuideline: json['activity_guideline'] ?? '',
      avoidList: json['avoid_list'] ?? '',
    );
  }
}

// AI Report Analysis Models
class AiReportResult {
  final String summary;
  final List<String> dietaryActionPlan;
  final List<TestResultItem> results;

  AiReportResult({
    required this.summary,
    required this.dietaryActionPlan,
    required this.results,
  });

  factory AiReportResult.fromJson(Map<String, dynamic> json) {
    return AiReportResult(
      summary: json['summary'] ?? '',
      dietaryActionPlan: List<String>.from(json['dietary_action_plan'] ?? []),
      results: (json['results'] as List?)
              ?.map((e) => TestResultItem.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class TestResultItem {
  final String testName;
  final String value;
  final String unit;
  final String referenceRange;
  final String status;

  TestResultItem({
    required this.testName,
    required this.value,
    required this.unit,
    required this.referenceRange,
    required this.status,
  });

  factory TestResultItem.fromJson(Map<String, dynamic> json) {
    return TestResultItem(
      testName: json['test_name'] ?? '',
      value: json['value'] ?? '',
      unit: json['unit'] ?? '',
      referenceRange: json['reference_range'] ?? '',
      status: json['status'] ?? 'Unknown',
    );
  }
}
