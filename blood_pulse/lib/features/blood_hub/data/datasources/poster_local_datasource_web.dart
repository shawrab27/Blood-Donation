// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'poster_local_datasource.dart';

/// Implementation of [PosterLocalDataSource] for Web platform.
/// Completely free of dart:io, path_provider, and gal.
class PosterLocalDataSourceImpl implements PosterLocalDataSource {
  const PosterLocalDataSourceImpl();

  @override
  Future<String> exportToGallery(Uint8List pngBytes, {String? filename}) async {
    final name = filename ?? 'BloodPulse_Poster_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final xfile = XFile.fromData(pngBytes, mimeType: 'image/png', name: '$name.png');
      await xfile.saveTo('$name.png');
      return '$name.png';
    } catch (e) {
      return 'downloaded';
    }
  }

  @override
  Future<void> sharePoster(
    Uint8List pngBytes,
    PosterData data, {
    String? platform,
    bool isBangla = false,
  }) async {
    final caption = _buildShareCaption(data, isBangla);

    if (platform == 'whatsapp') {
      final whatsappUrl = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(caption)}',
      );
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
        return;
      }
    } else if (platform == 'sms') {
      final smsUrl = Uri.parse('sms:?body=${Uri.encodeComponent(caption)}');
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
        return;
      }
    }

    try {
      final xfile = XFile.fromData(pngBytes, mimeType: 'image/png', name: 'bloodpulse_poster.png');
      await Share.shareXFiles(
        [xfile],
        text: caption,
        subject: isBangla
            ? 'জরুরি রক্ত প্রয়োজন: ${data.bloodGroup}'
            : 'Urgent Blood Needed: ${data.bloodGroup}',
      );
    } catch (_) {
      await Share.share(caption);
    }
  }

  String _buildShareCaption(PosterData data, bool isBangla) {
    if (isBangla) {
      return '🚨 জরুরি রক্ত প্রয়োজন (${data.bloodGroup})\n'
          'রোগী: ${data.patientName}\n'
          'স্থান: ${data.location}\n'
          'রক্তের পরিমাণ: ${data.unitsNeeded} ব্যাগ\n'
          'জরুরি মাত্রা: ${data.urgencyLevel}\n'
          'কারণ: ${data.condition}\n'
          'যোগাযোগ: ${data.contactNumber ?? "BloodPulse অ্যাপে দেখুন"}\n'
          'রক্তদানে এগিয়ে আসুন — BloodPulse';
    }
    return '🚨 URGENT BLOOD NEEDED (${data.bloodGroup})\n'
        'Patient: ${data.patientName}\n'
        'Location: ${data.location}\n'
        'Units Needed: ${data.unitsNeeded} Bag(s)\n'
        'Urgency: ${data.urgencyLevel}\n'
        'Reason: ${data.condition}\n'
        'Contact: ${data.contactNumber ?? "See BloodPulse App"}\n'
        'Please donate blood today — BloodPulse';
  }
}
