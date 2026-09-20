import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../services/fcm_service.dart';

/// Popup modal styled over a phone wallpaper backdrop for high-priority emergency notifications.
class NotificationWallpaperOverlay extends StatelessWidget {
  const NotificationWallpaperOverlay({
    super.key,
    this.title = '🚨 CRITICAL MATCH: O+ Blood Needed',
    this.patientName = 'Md. Safiqul Islam',
    this.hospital = 'Dhaka Medical College Hospital (Ward 4)',
    this.bloodGroup = 'O+',
    this.unitsNeeded = 2,
    this.requesterPhone = '01711-999888',
    this.chatId = 'chat_999',
  });

  final String title;
  final String patientName;
  final String hospital;
  final String bloodGroup;
  final int unitsNeeded;
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
  ///
  /// Expected keys (all optional, fall back to defaults):
  ///   `title`, `patientName`, `hospital`, `bloodGroup`,
  ///   `unitsNeeded`, `requesterPhone`, `chatId`
  static void showFromPayload(
    BuildContext context,
    Map<String, dynamic> payload,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => NotificationWallpaperOverlay(
        title:          payload['title']         as String? ?? '🚨 CRITICAL MATCH: Blood Needed',
        patientName:    payload['patientName']   as String? ?? 'Unknown Patient',
        hospital:       payload['hospital']      as String? ?? 'Nearby Hospital',
        bloodGroup:     payload['bloodGroup']    as String? ?? '?',
        unitsNeeded:    int.tryParse(payload['unitsNeeded']?.toString() ?? '1') ?? 1,
        requesterPhone: payload['requesterPhone'] as String? ?? '',
        chatId:         payload['chatId']        as String? ?? 'chat_999',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(245),
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
                  child: const Icon(Icons.emergency_rounded, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      const Text('Live Geolocation Dispatch Alert', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, color: AppColors.neutral),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Emergency Details
            _detailRow('Patient Name:', patientName),
            const SizedBox(height: 8),
            _detailRow('Hospital Unit:', hospital),
            const SizedBox(height: 8),
            _detailRow('Required Group:', '$bloodGroup ($unitsNeeded Bags)'),
            const SizedBox(height: 20),

            // Dual Quick Actions: Call Now vs Message/Chat
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.5),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      if (requesterPhone.isNotEmpty) {
                        await FcmService.instance.callRequester(requesterPhone);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('📞 No phone number available for this request.'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.call_rounded, color: AppColors.primary, size: 18),
                    label: const Text('Call Now', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CapsuleButton(
                    label: 'Message / Chat',
                    icon: Icons.chat_rounded,
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(
                        '/chat',
                        extra: {
                          'chatRoomId': chatId,
                          'chatRecipientName': patientName,
                          'bloodGroup': bloodGroup,
                          'recipientId': requesterPhone.isNotEmpty ? requesterPhone : chatId,
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
    );
  }

  Widget _detailRow(String label, String val) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(val, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.secondary)),
        ),
      ],
    );
  }
}
