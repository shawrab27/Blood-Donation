// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:io';
import 'dart:typed_data';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'poster_local_datasource.dart';

/// Implementation of [PosterLocalDataSource] for native platforms (Android / iOS)
/// using path_provider, gal, and share_plus.
class PosterLocalDataSourceImpl implements PosterLocalDataSource {
  const PosterLocalDataSourceImpl();

  @override
  Future<String> exportToGallery(Uint8List pngBytes, {String? filename}) async {
    final name = filename ?? 'BloodPulse_Poster_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Native Mobile (Android / iOS): Save directly to native Gallery via Gal
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
      await Gal.putImageBytes(pngBytes, name: name);
    } catch (_) {
      // Fallback if Gal is denied or unavailable in environment
    }

    // 2. Write to persistent local directory as reliable file path return
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final posterDir = Directory('${baseDir.path}/BloodPulse/Posters');
      if (!await posterDir.exists()) {
        await posterDir.create(recursive: true);
      }
      final targetPath = '${posterDir.path}/$name.png';
      await File(targetPath).writeAsBytes(pngBytes);
      return targetPath;
    } catch (_) {
      return name;
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

    // Mobile file writing for share_plus
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/bloodpulse_poster_share.png');
      await tempFile.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: caption,
        subject: isBangla
            ? 'জরুরি রক্ত প্রয়োজন: ${data.bloodGroup}'
            : 'Urgent Blood Needed: ${data.bloodGroup}',
      );
    } catch (_) {
      // Fallback to text share if file sharing fails
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
