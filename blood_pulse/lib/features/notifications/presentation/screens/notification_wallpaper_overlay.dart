// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../services/fcm_service.dart';
import '../../../blood_hub/presentation/widgets/report_broker_dialog.dart';
import '../../../blood_hub/presentation/widgets/request_units_progress_card.dart';

/// Popup modal styled over a phone wallpaper backdrop for high-priority emergency notifications.
/// Includes the shared [RequestUnitsProgressCard] (Part G #2), Support Status selector
/// (`Can Support` vs `Voluntary Only / Charity` — Part B), and Report Broker action (Part D).
class NotificationWallpaperOverlay extends StatefulWidget {
  const NotificationWallpaperOverlay({
    super.key,
    this.requestId,
    this.title = '🚨 CRITICAL MATCH: O+ Blood Needed',
    this.patientName = 'Md. Safiqul Islam',
    this.hospital = 'Hospital',
    this.bloodGroup = 'O+',
    this.unitsNeeded = 2,
    this.unitsReceived = 0,
    this.unitsPending = 1,
    this.requestMode = 'PROXY',
    this.requesterPhone = '',
    this.chatId = 'chat_999',
  });

  final int? requestId;
  final String title;
  final String patientName;
  final String hospital;
  final String bloodGroup;
  final int unitsNeeded;
  final int unitsReceived;
  final int unitsPending;
  final String requestMode;
  final String requesterPhone;
  final String chatId;

  static void show(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const NotificationWallpaperOverlay(),
    );
  }

  /// Parses an FCM data payload map and shows the overlay with dynamic values.
  static void showFromPayload(
    BuildContext context,
    Map<String, dynamic> payload,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => NotificationWallpaperOverlay(
        requestId: int.tryParse(payload['requestId']?.toString() ?? ''),
        title:
            payload['title'] as String? ?? '🚨 CRITICAL MATCH: Blood Needed',
        patientName: payload['patientName'] as String? ?? 'Unknown Patient',
        hospital: payload['hospital'] as String? ?? 'Nearby Hospital',
        bloodGroup: payload['bloodGroup'] as String? ?? '?',
        unitsNeeded:
            int.tryParse(payload['unitsNeeded']?.toString() ?? '2') ?? 2,
        unitsReceived:
            int.tryParse(payload['unitsReceived']?.toString() ?? '0') ?? 0,
        unitsPending:
            int.tryParse(payload['unitsPending']?.toString() ?? '0') ?? 0,
        requestMode: payload['requestMode'] as String? ?? 'PROXY',
        requesterPhone: payload['requesterPhone'] as String? ?? '',
        chatId: payload['chatId'] as String? ?? 'chat_999',
      ),
    );
  }

  @override
  State<NotificationWallpaperOverlay> createState() =>
      _NotificationWallpaperOverlayState();
}

class _NotificationWallpaperOverlayState
    extends State<NotificationWallpaperOverlay> {
  String _selectedSupportStatus = 'CAN_SUPPORT';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(248),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.primary, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(60),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFECEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const Text(
                          'Live Geolocation Dispatch Alert',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: AppColors.neutral,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Report Broker / Issue',
                    icon: const Icon(
                      Icons.flag_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: () => ReportBrokerDialog.show(
                      context,
                      requestId: widget.requestId,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close_rounded,
                      color: AppColors.neutral,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Emergency Details
              _detailRow('Patient Name:', widget.patientName),
              const SizedBox(height: 6),
              _detailRow('Hospital Unit:', widget.hospital),
              const SizedBox(height: 6),
              _detailRow(
                'Required Group:',
                '${widget.bloodGroup} (${widget.unitsNeeded} Bags)',
              ),
              const SizedBox(height: 12),

              // Shared Progress Widget (Part G #2: Notification Popup)
              RequestUnitsProgressCard(
                compact: true,
                unitsReceived: widget.unitsReceived,
                unitsPending: widget.unitsPending,
                unitsNeeded: widget.unitsNeeded,
                requestMode: widget.requestMode,
                supportStatus: _selectedSupportStatus,
              ),
              const SizedBox(height: 12),

              // Support Status Selector (Part B.1)
              const Text(
                'Your Support Status:',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    key: const Key('support_chip_can_support'),
                    label: const Text(
                      'Can Support',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12),
                    ),
                    selected: _selectedSupportStatus == 'CAN_SUPPORT',
                    selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.16),
                    onSelected: (_) =>
                        setState(() => _selectedSupportStatus = 'CAN_SUPPORT'),
                  ),
                  ChoiceChip(
                    key: const Key('support_chip_voluntary_only'),
                    label: const Text(
                      'Voluntary Only / Charity',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12),
                    ),
                    selected: _selectedSupportStatus == 'VOLUNTARY_ONLY',
                    selectedColor: const Color(0xFF6A1B9A).withValues(alpha: 0.16),
                    onSelected: (_) => setState(
                      () => _selectedSupportStatus = 'VOLUNTARY_ONLY',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dual Quick Actions: Call Now vs Message/Chat
              Row(
                children: [
                  if (widget.requesterPhone.isNotEmpty &&
                      !widget.requesterPhone.contains('*')) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await FcmService.instance.callRequester(
                            widget.requesterPhone,
                          );
                        },
                        icon: const Icon(
                          Icons.call_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        label: const Text(
                          'Call Now',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: CapsuleButton(
                      label: 'Message / Chat',
                      icon: Icons.chat_rounded,
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(
                          '/chat',
                          extra: {
                            'chatRoomId': widget.chatId,
                            'chatRecipientName': widget.patientName,
                            'bloodGroup': widget.bloodGroup,
                            'recipientId': widget.requesterPhone.isNotEmpty
                                ? widget.requesterPhone
                                : widget.chatId,
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String val) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            val,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.secondary,
            ),
          ),
        ),
      ],
    );
  }
}
