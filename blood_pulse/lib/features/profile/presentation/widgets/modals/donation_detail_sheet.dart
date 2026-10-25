// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:blood_pulse/features/profile/domain/models/profile_models.dart';
import 'digital_certificate_sheet.dart';

/// Stitch Screen: Donation Detail Bottom Sheet
/// Shows hospital, date, how, type, volume, linked request, verification status, XP earned.
class DonationDetailSheet extends StatelessWidget {
  final DonationHistoryModel donation;
  final String donorName;
  final String bloodGroup;

  const DonationDetailSheet({
    super.key,
    required this.donation,
    required this.donorName,
    required this.bloodGroup,
  });

  static Future<void> show({
    required BuildContext context,
    required DonationHistoryModel donation,
    required String donorName,
    required String bloodGroup,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DonationDetailSheet(
        donation: donation,
        donorName: donorName,
        bloodGroup: bloodGroup,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String formattedDate = donation.date;
    try {
      final dt = DateTime.tryParse(donation.date);
      if (dt != null) {
        formattedDate = DateFormat('d MMMM yyyy').format(dt);
      }
    } catch (_) {}

    final isVerified = donation.verified;
    final int xpEarned = isVerified ? 100 : 0;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE2D6D6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  donation.hospital.isNotEmpty ? donation.hospital : 'Direct Blood Donation',
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF24191A),
                  ),
                ),
              ),
              PressableScale(child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                visualDensity: VisualDensity.compact,
              )),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            donation.city.isNotEmpty ? '${donation.city}, Bangladesh' : 'Bangladesh',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
          ),
          const SizedBox(height: 14),

          // Verification & XP status badge card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isVerified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isVerified ? const Color(0xFFA5D6A7) : const Color(0xFFF0E5E5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
                  size: 24,
                  color: isVerified ? const Color(0xFF1B8A4E) : const Color(0xFFD97706),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified ? 'Clinically Verified Donation' : 'Self-Reported Voluntary Record',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isVerified ? const Color(0xFF1B8A4E) : const Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isVerified
                          ? '+$xpEarned XP awarded • Counted toward Top Donors & Global Rank'
                          : '0 XP • Self-reported records are for personal history tracking only',
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF5F5E5E)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Details List
          _buildDetailRow('Date', formattedDate, Icons.calendar_today_rounded),
          const Divider(height: 18, color: Color(0xFFF0E5E5)),
          _buildDetailRow('Volume & Units', '${donation.bags} Bag (${donation.volumeMl ?? 450} ml)', Icons.water_drop_rounded),
          const Divider(height: 18, color: Color(0xFFF0E5E5)),
          _buildDetailRow('Donation Type', donation.donationType.replaceAll('_', ' ').toUpperCase(), Icons.bloodtype_rounded),
          const Divider(height: 18, color: Color(0xFFF0E5E5)),
          _buildDetailRow('Donation Method', donation.how.toUpperCase(), Icons.how_to_reg_rounded),
          const Divider(height: 18, color: Color(0xFFF0E5E5)),
          _buildDetailRow('Source', donation.source == 'verified' ? 'System Confirmed' : 'User Self-Reported', Icons.source_rounded),
          const SizedBox(height: 20),

          // Action Buttons: Certificate and Share
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: PressableScale(child: OutlinedButton.icon(
                    onPressed: () {
                      final shareText = 'BloodPulse Donation Record:\n'
                          'Donor: $donorName ($bloodGroup)\n'
                          'Hospital: ${donation.hospital}\n'
                          'Date: $formattedDate\n'
                          'Status: ${isVerified ? "Verified (+100 XP)" : "Self-reported"}\n'
                          '#BloodPulse #SaveLivesBangladesh';
                      Share.share(shareText);
                    },
                    icon: const Icon(Icons.share_outlined, size: 16, color: Color(0xFF24191A)),
                    label: const Text('Share Record'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF24191A),
                      side: const BorderSide(color: Color(0xFFE2D6D6)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  )),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: PressableScale(child: ElevatedButton.icon(
                    onPressed: isVerified
                        ? () {
                            Navigator.of(context).pop();
                            DigitalCertificateSheet.show(
                              context: context,
                              donorName: donorName,
                              bloodGroup: bloodGroup,
                              totalDonations: donation.bags,
                            );
                          }
                        : null,
                    icon: const Icon(Icons.verified_outlined, size: 16),
                    label: const Text('Certificate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC30121),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE2D6D6),
                      disabledForegroundColor: const Color(0xFF8C8A8A),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                      textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  )),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8C8A8A)),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF5F5E5E)),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF24191A),
          ),
        ),
      ],
    );
  }
}
