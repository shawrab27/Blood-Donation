// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

class AssistantMessage {
  final int? id;
  final bool isUser;
  final String text;
  final List<AssistantAction> actions;
  final String? action;
  final List<String> missingFields;
  final bool emergency;
  final bool needsHuman;
  final int? conversationId;
  final bool hasThumbsDown;

  AssistantMessage({
    this.id,
    this.conversationId,
    required this.isUser,
    required this.text,
    this.actions = const [],
    this.action,
    this.missingFields = const [],
    this.emergency = false,
    this.needsHuman = false,
    this.hasThumbsDown = false,
  });

  factory AssistantMessage.fromJson(Map<String, dynamic> json) {
    return AssistantMessage(
      id: json['message_id'],
      conversationId: json['conversation_id'],
      isUser: json['is_user'] ?? false,
      text: json['reply'] ?? json['text'] ?? '',
      actions: (json['actions'] as List<dynamic>?)
              ?.map((e) => AssistantAction.fromJson(e))
              .toList() ??
          [],
      action: json['action'] as String?,
      missingFields: (json['missing_fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      emergency: json['emergency'] ?? false,
      needsHuman: json['needs_human'] ?? false,
      hasThumbsDown: json['has_thumbs_down'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': id,
      'is_user': isUser,
      'text': text,
      'reply': text,
      'actions': actions.map((e) => e.toJson()).toList(),
      if (action != null) 'action': action,
      if (missingFields.isNotEmpty) 'missing_fields': missingFields,
      'emergency': emergency,
      'needs_human': needsHuman,
      'has_thumbs_down': hasThumbsDown,
    };
  }

  AssistantMessage copyWith({
    int? id,
    bool? isUser,
    String? text,
    List<AssistantAction>? actions,
    String? action,
    List<String>? missingFields,
    bool? emergency,
    bool? needsHuman,
    bool? hasThumbsDown,
  }) {
    return AssistantMessage(
      id: id ?? this.id,
      isUser: isUser ?? this.isUser,
      text: text ?? this.text,
      actions: actions ?? this.actions,
      action: action ?? this.action,
      missingFields: missingFields ?? this.missingFields,
      emergency: emergency ?? this.emergency,
      needsHuman: needsHuman ?? this.needsHuman,
      hasThumbsDown: hasThumbsDown ?? this.hasThumbsDown,
    );
  }
}

class AssistantAction {
  final String id;
  final String labelEn;
  final String labelBn;
  final String route;

  AssistantAction({
    required this.id,
    required this.labelEn,
    required this.labelBn,
    required this.route,
  });

  factory AssistantAction.fromJson(Map<String, dynamic> json) {
    return AssistantAction(
      id: json['id'] ?? '',
      labelEn: json['label_en'] ?? '',
      labelBn: json['label_bn'] ?? '',
      route: json['route'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label_en': labelEn,
      'label_bn': labelBn,
      'route': route,
    };
  }
}

class QuickAction {
  final String id;
  final String textEn;
  final String textBn;

  QuickAction({
    required this.id,
    required this.textEn,
    required this.textBn,
  });

  factory QuickAction.fromJson(Map<String, dynamic> json) {
    return QuickAction(
      id: json['id'] ?? '',
      textEn: json['text_en'] ?? '',
      textBn: json['text_bn'] ?? '',
    );
  }
}
