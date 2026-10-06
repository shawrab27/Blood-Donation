// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';

/// Local data source contract for poster storage and sharing operations.
abstract class PosterLocalDataSource {
  Future<File> exportToGallery(File pngFile);

  Future<void> sharePoster(
    File pngFile,
    PosterData data, {
    String? platform,
    bool isBangla = false,
  });
}

/// Implementation of [PosterLocalDataSource] with path_provider & share_plus.
class PosterLocalDataSourceImpl implements PosterLocalDataSource {
  const PosterLocalDataSourceImpl();

  @override
  Future<File> exportToGallery(File pngFile) async {
    Directory? baseDir;
    try {
      baseDir = await getExternalStorageDirectory();
    } catch (_) {
      baseDir = null;
    }
    baseDir ??= await getApplicationDocumentsDirectory();

    final posterDir = Directory('${baseDir.path}/BloodPulse/Posters');
    if (!await posterDir.exists()) {
      await posterDir.create(recursive: true);
    }

    final targetPath =
        '${posterDir.path}/poster_${DateTime.now().millisecondsSinceEpoch}.png';
    return await pngFile.copy(targetPath);
  }

  @override
  Future<void> sharePoster(
    File pngFile,
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
      }
    } else if (platform == 'sms') {
      final smsUrl = Uri.parse('sms:?body=${Uri.encodeComponent(caption)}');
      if (await canLaunchUrl(smsUrl)) {
        await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
      }
    }

    // Default to native multi-channel share sheet with file attached
    await Share.shareXFiles(
      [XFile(pngFile.path)],
      text: caption,
      subject: isBangla
          ? 'জরুরি রক্ত প্রয়োজন: ${data.bloodGroup}'
          : 'Urgent Blood Needed: ${data.bloodGroup}',
    );
  }

  String _buildShareCaption(PosterData data, bool isBangla) {
    if (isBangla) {
      return '🩸 ${data.bloodGroup} রক্ত প্রয়োজন | ${data.location}\n'
          'রোগীর নাম: ${data.patientName}\n'
          'হাসপাতাল: ${data.hospitalName ?? 'জরুরি বিভাগ'}\n'
          'ইউনিট: ${data.unitsNeeded} ব্যাগ | জরুরি অবস্থা: ${data.urgencyLevel}\n'
          'যোগাযোগ: ${data.contactNumber ?? 'জরুরি হটলাইন'}\n\n'
          '"আজ আপনি দিলে, কাল তারা বাঁচবে।"\n'
          'অ্যাপে দেখুন: https://bloodpulse.app';
    }

    return '🩸 Urgent ${data.bloodGroup} Blood Needed | ${data.location}\n'
        'Patient: ${data.patientName}\n'
        'Hospital: ${data.hospitalName ?? 'Emergency Clinic'}\n'
        'Units Needed: ${data.unitsNeeded} bag(s) | Urgency: ${data.urgencyLevel}\n'
        'Contact: ${data.contactNumber ?? 'Direct Attendant'}\n\n'
        '"You give today, They live today."\n'
        'Details: https://bloodpulse.app';
  }
}
