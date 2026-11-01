// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// Single source of truth for deep linking and notification routing.
///
/// Handles routing payloads from:
/// - Firebase Cloud Messaging (foreground, background, terminated tap)
/// - Local notification center inbox tiles
/// - Push notification action clicks
class DeepLinkResolver {
  DeepLinkResolver._();

  static final DeepLinkResolver instance = DeepLinkResolver._();

  /// Resolve notification payload to route and navigate safely.
  void resolveAndNavigate(
    Map<String, dynamic> payload,
    BuildContext context,
  ) {
    if (!context.mounted) return;

    final type = (payload['type'] ?? payload['notification_type'] ?? '').toString().toUpperCase();
    final rawRequestId = payload['request_id'] ?? payload['requestId'] ?? payload['blood_request_id'];
    final rawJourneyId = payload['journey_id'] ?? payload['journeyId'] ?? payload['acceptance_id'] ?? payload['match_id'] ?? payload['matchId'];
    final rawOfferId = payload['offer_id'] ?? payload['offerId'];
    final rawFollowupId = payload['followup_id'] ?? payload['followupId'];
    final rawChatId = payload['chat_id'] ?? payload['chatId'] ?? payload['chat_room_id'] ?? payload['chatRoomId'] ?? payload['room_id'];

    debugPrint('[DeepLinkResolver] Routing type=$type, req=$rawRequestId, journey=$rawJourneyId, chat=$rawChatId, offer=$rawOfferId');

    // 1. Standby Offer
    if (type.contains('STANDBY') || rawOfferId != null) {
      final offerId = int.tryParse(rawOfferId?.toString() ?? '1') ?? 1;
      context.push('/standby/$offerId');
      return;
    }

    // 2. Chat Message
    if (type.contains('CHAT') || type.contains('MESSAGE')) {
      final senderName = payload['sender_name']?.toString() ??
          payload['senderName']?.toString() ??
          payload['title']?.toString().replaceAll('New message from ', '') ??
          'Emergency Contact';
      final bloodGroup = payload['blood_group']?.toString() ?? payload['bloodGroup']?.toString() ?? '';
      final recipientId = payload['sender_id']?.toString() ??
          payload['senderId']?.toString() ??
          payload['recipientId']?.toString() ??
          '';
      final roomId = rawChatId?.toString() ??
          (recipientId.isNotEmpty ? 'chat_$recipientId' : 'general_chat');

      context.push(
        '/chat',
        extra: {
          'chatRecipientName': senderName,
          'bloodGroup': bloodGroup,
          'chatRoomId': roomId,
          'recipientId': recipientId,
        },
      );
      return;
    }

    // 3. Thanks / Completion
    if (type.contains('THANKS') || type.contains('COMPLET')) {
      final matchId = int.tryParse(rawJourneyId?.toString() ?? '1') ?? 1;
      final donorName = payload['donor_name']?.toString() ?? payload['donorName']?.toString() ?? 'Valued Donor';
      context.push('/blood-hub/thanks', extra: {'matchId': matchId, 'donorName': donorName});
      return;
    }

    // 4. Follow-up
    if (type.contains('FOLLOWUP') || rawFollowupId != null) {
      final followupId = int.tryParse(rawFollowupId?.toString() ?? '1') ?? 1;
      context.push('/blood-hub/followup', extra: {'followupId': followupId});
      return;
    }

    // 5. Active Journey / Request Detail
    if (rawJourneyId != null && rawJourneyId.toString().isNotEmpty) {
      final jId = int.tryParse(rawJourneyId.toString()) ?? 1;
      context.push('/journeys/$jId');
      return;
    }

    if (rawRequestId != null && rawRequestId.toString().isNotEmpty) {
      final reqId = int.tryParse(rawRequestId.toString()) ?? 1;
      context.push('/journeys/$reqId');
      return;
    }

    // 6. Social Feed
    if (type.contains('FEED') || type.contains('POST') || type.contains('SOCIAL')) {
      context.go('/feed');
      return;
    }

    // 7. Profile
    if (type.contains('PROFILE') || type.contains('COOLDOWN') || type.contains('BADGE')) {
      context.go('/profile');
      return;
    }

    // 8. Default fallback
    context.go('/blood-hub');
  }

  /// Launch phone call with tel: scheme (guarded against masked / hidden values).
  Future<void> makePhoneCall(String phoneNumber) async {
    final trimmed = phoneNumber.trim().toLowerCase();
    if (trimmed.isEmpty ||
        trimmed.contains('hidden') ||
        trimmed.contains('*') ||
        trimmed.contains('protect') ||
        trimmed.contains('reveal')) {
      return;
    }
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.length < 7) return;
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint('[DeepLinkResolver] Cannot launch phone call to: $cleanPhone');
    }
  }
}
