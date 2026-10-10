// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';

/// Modal bottom sheet providing multi-channel poster sharing options.
/// Matches Stitch design: "Poster Editor — Share & Download Sheet".
class PosterShareSheet extends StatelessWidget {
  const PosterShareSheet({
    super.key,
    required this.isBangla,
    required this.onSelectChannel,
    required this.posterData,
    this.onCopyCaption,
    this.onDownloadPdf,
  });

  final bool isBangla;
  final ValueChanged<String?> onSelectChannel;
  final PosterData posterData;
  final VoidCallback? onCopyCaption;
  final VoidCallback? onDownloadPdf;

  static void show(
    BuildContext context, {
    required bool isBangla,
    required ValueChanged<String?> onSelectChannel,
    required PosterData posterData,
    VoidCallback? onCopyCaption,
    VoidCallback? onDownloadPdf,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: PosterShareSheet(
          isBangla: isBangla,
          posterData: posterData,
          onCopyCaption: onCopyCaption,
          onSelectChannel: (platform) {
            Navigator.pop(ctx);
            onSelectChannel(platform);
          },
          onDownloadPdf: onDownloadPdf != null
              ? () {
                  Navigator.pop(ctx);
                  onDownloadPdf();
                }
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDD0D0),
                borderRadius: BorderRadius.circular(50),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isBangla ? 'পোস্টার শেয়ার ও ডাউনলোড' : 'Share & Download Poster',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isBangla
                ? 'সোশ্যাল মিডিয়ায় শেয়ার করুন বা গ্যালারিতে সেভ করুন'
                : 'Share to social media or save to your gallery',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.neutral,
            ),
          ),
          const SizedBox(height: 20),

          // Social platforms row
          Text(
            isBangla ? 'সোশ্যাল মিডিয়া' : 'Social Platforms',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _channelBtn(
                icon: Icons.chat_rounded,
                color: const Color(0xFF25D366),
                label: 'WhatsApp',
                onTap: () => onSelectChannel('whatsapp'),
              ),
              _channelBtn(
                icon: Icons.facebook_rounded,
                color: const Color(0xFF1877F2),
                label: 'Facebook',
                onTap: () => onSelectChannel('facebook'),
              ),
              _channelBtn(
                icon: Icons.close_rounded,
                color: const Color(0xFF1DA1F2),
                label: 'Twitter/X',
                onTap: () => onSelectChannel('twitter'),
              ),
              _channelBtn(
                icon: Icons.camera_alt_rounded,
                color: const Color(0xFFE1306C),
                label: 'Instagram',
                onTap: () => onSelectChannel('instagram'),
              ),
              _channelBtn(
                icon: Icons.share_rounded,
                color: AppColors.primary,
                label: isBangla ? 'অন্যান্য' : 'More',
                onTap: () => onSelectChannel(null),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFF0E0E0), thickness: 1),
          const SizedBox(height: 16),

          // Action cards
          Text(
            isBangla ? 'ডাউনলোড ও কপি' : 'Download & Copy',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.neutral,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          // Save high-res
          _actionCard(
            icon: Icons.download_rounded,
            color: AppColors.primary,
            title: isBangla ? 'হাই-রেজ ছবি গ্যালারিতে সেভ করুন' : 'Save High-Res Image to Gallery',
            subtitle: isBangla ? 'PNG · 3× রেজোলিউশন' : 'PNG · 3× pixel density',
            onTap: () => onSelectChannel('gallery'),
          ),
          const SizedBox(height: 10),

          // Copy caption
          _actionCard(
            icon: Icons.copy_rounded,
            color: AppColors.tertiary,
            title: isBangla ? 'ফ্রি ক্যাপশন কপি করুন' : 'Copy Free Written Caption',
            subtitle: isBangla ? 'WhatsApp, Facebook-এ পেস্ট করুন' : 'Ready to paste on any platform',
            onTap: () {
              _copyCaption(context);
            },
          ),
          const SizedBox(height: 10),

          // Download PDF
          _actionCard(
            icon: Icons.picture_as_pdf_rounded,
            color: const Color(0xFFD32F2F),
            title: isBangla ? 'PDF সারসংক্ষেপ ডাউনলোড করুন' : 'Download PDF Summary',
            subtitle: isBangla ? '~2.5 MB · ক্লিনিকাল রেফারেন্স' : '~2.5 MB · Clinical reference copy',
            onTap: onDownloadPdf,
          ),
        ],
      ),
    );
  }

  void _copyCaption(BuildContext context) {
    final caption = _buildCaption(posterData, isBangla);
    Clipboard.setData(ClipboardData(text: caption));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        isBangla ? 'ক্যাপশন ক্লিপবোর্ডে কপি হয়েছে!' : 'Caption copied!',
        style: const TextStyle(fontFamily: 'Inter'),
      ),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: const StadiumBorder(),
      duration: const Duration(seconds: 2),
    ));
    onCopyCaption?.call();
  }

  String _buildCaption(PosterData data, bool isBangla) {
    if (isBangla) {
      return '🩸 ${data.bloodGroup} রক্ত জরুরি প্রয়োজন!\n'
          'রোগী: ${data.patientName} | ${data.condition}\n'
          'হাসপাতাল: ${data.hospitalName ?? 'জরুরি বিভাগ'} — ${data.location}\n'
          'প্রয়োজন: ${data.unitsNeeded} ব্যাগ | জরুরি: ${data.urgencyLevel}\n'
          'যোগাযোগ: ${data.contactNumber ?? 'হটলাইনে কল করুন'}\n\n'
          '"আজ আপনি দিলে, কাল তারা বাঁচবে।"\n'
          '🔗 https://bloodpulse.app';
    }
    return '🩸 URGENT ${data.bloodGroup} Blood Needed!\n'
        'Patient: ${data.patientName} | ${data.condition}\n'
        'Hospital: ${data.hospitalName ?? 'Emergency Dept'} — ${data.location}\n'
        'Need: ${data.unitsNeeded} bag(s) | Urgency: ${data.urgencyLevel}\n'
        'Contact: ${data.contactNumber ?? 'Emergency Hotline'}\n\n'
        '"You give today, They live today."\n'
        '🔗 https://bloodpulse.app';
  }

  Widget _channelBtn({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withAlpha(28),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0E0E0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withAlpha(24),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.neutral,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
