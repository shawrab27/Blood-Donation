// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/core/errors/app_error_mapper.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/core/widgets/blood_pulse_app_bar.dart';
import 'package:blood_pulse/core/widgets/responsive_layout.dart';
import 'package:blood_pulse/features/auth/presentation/providers/locale_provider.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'package:blood_pulse/features/blood_hub/presentation/providers/poster_provider.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_canvas.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_editor_controls.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_generator_widget.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_share_sheet.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_style_selectors.dart';
import 'package:blood_pulse/features/feed/presentation/providers/feed_provider.dart';

/// Full-screen poster studio: live-preview, size/colour pickers, export & share.
class PosterGeneratorScreen extends ConsumerStatefulWidget {
  const PosterGeneratorScreen({
    super.key,
    this.initialData,
    this.initialTemplateType = PosterTemplateType.withPhoto,
  });

  final PosterData? initialData;
  final PosterTemplateType initialTemplateType;

  @override
  ConsumerState<PosterGeneratorScreen> createState() =>
      _PosterGeneratorScreenState();
}

class _PosterGeneratorScreenState extends ConsumerState<PosterGeneratorScreen> {
  late PosterData _posterData;
  late PosterTemplateType _templateType;
  PosterAspectRatio _aspectRatio = PosterAspectRatio.square;
  PosterColorTheme _colorTheme = PosterColorTheme.crimson;
  final GlobalKey<PosterGeneratorWidgetState> _generatorKey = GlobalKey();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _posterData = widget.initialData ?? PosterData.empty();
    _templateType = widget.initialTemplateType;
  }

  Future<void> _exportToGallery(bool isBangla) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final png = await _generatorKey.currentState?.exportPNG();
      if (png == null) throw Exception('Could not capture poster.');
      await ref.read(posterRepositoryProvider).exportToGallery(png);
      if (mounted) {
        _snack(
          isBangla
              ? 'পোস্টারটি সফলভাবে গ্যালারিতে সংরক্ষিত হয়েছে!'
              : '✓ Poster successfully saved to Gallery!',
          AppColors.success,
        );
      }
    } catch (e) {
      if (mounted) _snack(AppError.toHumanMessage(e, isBangla: isBangla), AppColors.error);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _shareToBloodPulseFeed(bool isBangla) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final png = await _generatorKey.currentState?.exportPNG();
      if (png == null) throw Exception('Could not capture poster.');

      final caption = isBangla
          ? '🚨 জরুরি রক্ত প্রয়োজন (${_posterData.bloodGroup})\n'
              'স্থান: ${_posterData.location}\n'
              'পরিমাণ: ${_posterData.unitsNeeded} ব্যাগ\n'
              'জরুরি মাত্রা: ${_posterData.urgencyLevel}\n'
              'কারণ: ${_posterData.condition}'
          : '🚨 Urgent Blood Request (${_posterData.bloodGroup})\n'
              'Location: ${_posterData.location}\n'
              'Units: ${_posterData.unitsNeeded} Bag(s)\n'
              'Urgency: ${_posterData.urgencyLevel}\n'
              'Reason: ${_posterData.condition}';

      final author = _posterData.patientName.isNotEmpty ? _posterData.patientName : 'Emergency Requester';
      final success = await ref.read(feedProvider.notifier).addPost(
        authorName: author,
        content: caption,
        imageBytes: png,
        location: _posterData.location,
        kind: 'emergency',
        urgentNeedBadge: _posterData.urgencyLevel,
        bloodGroupBadge: _posterData.bloodGroup,
      );

      if (mounted) {
        if (success) {
          _snack(
            isBangla ? '✓ BloodPulse ফিডে পোস্ট করা হয়েছে!' : '✓ Shared to BloodPulse Feed!',
            AppColors.success,
          );
        } else {
          _snack(
            isBangla ? 'ফিডে পোস্ট করতে ব্যর্থ হয়েছে' : 'Failed to post to Feed',
            AppColors.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _snack(AppError.toHumanMessage(e, isBangla: isBangla), AppColors.error);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _sharePoster(bool isBangla, {String? platform}) async {
    if (platform == 'gallery') { await _exportToGallery(isBangla); return; }
    if (platform == 'bloodpulse') { await _shareToBloodPulseFeed(isBangla); return; }
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      final png = await _generatorKey.currentState?.exportPNG();
      if (png == null) throw Exception('Could not capture poster.');
      await ref.read(posterRepositoryProvider)
          .sharePoster(png, _posterData, platform: platform, isBangla: isBangla);
    } catch (e) {
      if (mounted) _snack(AppError.toHumanMessage(e, isBangla: isBangla), AppColors.error);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'Inter')),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: const StadiumBorder(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isBangla = locale.languageCode == 'bn';
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: BloodPulseAppBar(
        showBackButton: true,
        showLogo: false,
        title: isBangla ? 'পোস্টার স্টুডিও' : 'Poster Studio',
        titleColor: AppColors.primary,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ResponsiveLayout(
        maxWidth: 600,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              PosterTemplateTabBar(
                selected: _templateType,
                isBangla: isBangla,
                onChanged: (t) => setState(() => _templateType = t),
              ),
              const SizedBox(height: 16),
              PosterCanvas(
                generatorKey: _generatorKey,
                data: _posterData,
                templateType: _templateType,
                aspectRatio: _aspectRatio,
                colorTheme: _colorTheme,
                isBangla: isBangla,
              ),
              const SizedBox(height: 20),
              PosterEditorControls(
                initialData: _posterData,
                isBangla: isBangla,
                selectedAspectRatio: _aspectRatio,
                selectedColorTheme: _colorTheme,
                onDataChanged: (d) => setState(() => _posterData = d),
                onAspectRatioChanged: (r) => setState(() => _aspectRatio = r),
                onColorThemeChanged: (t) => setState(() => _colorTheme = t),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: _bottomBar(isBangla),
        ),
      ),
    );
  }

  Widget _bottomBar(bool isBangla) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withAlpha(15),
          blurRadius: 10,
          offset: const Offset(0, -3),
        )],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: _isProcessing ? null : () => _exportToGallery(isBangla),
              icon: const Icon(Icons.download_rounded, color: AppColors.primary),
              label: Text(
                isBangla ? 'গ্যালারিতে সেভ' : 'Save to Gallery',
                style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 12,
                    fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: _isProcessing
                  ? null
                  : () => PosterShareSheet.show(
                        context,
                        isBangla: isBangla,
                        posterData: _posterData,
                        onSelectChannel: (p) => _sharePoster(isBangla, platform: p),
                      ),
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              label: Text(
                isBangla ? 'শেয়ার করুন' : 'Share Poster',
                style: const TextStyle(
                    fontFamily: 'Inter', fontSize: 12,
                    fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
