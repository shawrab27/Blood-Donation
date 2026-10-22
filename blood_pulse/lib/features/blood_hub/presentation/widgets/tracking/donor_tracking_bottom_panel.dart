// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/capsule_button.dart';
import 'donor_tracking_actions_sheet.dart';

/// Floating bottom status and action panel for the live donor tracking view.
class DonorTrackingBottomPanel extends StatelessWidget {
  const DonorTrackingBottomPanel({
    super.key,
    required this.distanceKm,
    required this.etaMinutes,
    required this.currentStatus,
    required this.isDonorView,
    required this.patientName,
    required this.donorName,
    required this.chatRoomId,
    required this.numericMatchId,
    required this.onStatusUpdate,
    required this.onReportSuccess,
  });

  final double distanceKm;
  final int etaMinutes;
  final String currentStatus;
  final bool isDonorView;
  final String patientName;
  final String donorName;
  final String chatRoomId;
  final int numericMatchId;
  final ValueChanged<String> onStatusUpdate;
  final VoidCallback onReportSuccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '~$distanceKm km remaining',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ETA: $etaMinutes mins (Estimate)',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  currentStatus,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B8A4E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  // USER RULE - do not change: launch chat with numeric match ID for real-time Django HTTP transport
                  onPressed: () => context.push('/chat', extra: {
                    'chatRecipientName':
                        isDonorView ? patientName : donorName,
                    'chatRoomId': (chatRoomId.isNotEmpty && chatRoomId != 'emergency_chat')
                        ? chatRoomId
                        : numericMatchId.toString(),
                  }),
                  icon:
                      const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('Chat'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => DonorTrackingActionsSheet.show(
                    context,
                    matchId: numericMatchId,
                    onReportSuccess: onReportSuccess,
                  ),
                  icon: const Icon(Icons.report_problem_outlined, size: 16),
                  label: const Text('Report'),
                ),
              ),
            ],
          ),
          if (isDonorView && currentStatus == 'IN_TRANSIT') ...[
            const SizedBox(height: 10),
            CapsuleButton(
              label: 'Arrived at Hospital',
              onPressed: () => onStatusUpdate('ARRIVED'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ] else if (!isDonorView && currentStatus == 'ARRIVED') ...[
            const SizedBox(height: 10),
            CapsuleButton(
              label: 'Confirm Donation Received',
              onPressed: () => onStatusUpdate('DONATED'),
              backgroundColor: const Color(0xFF1B8A4E),
              foregroundColor: Colors.white,
            ),
          ],
        ],
      ),
    );
  }
}
