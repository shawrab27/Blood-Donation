// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/core/widgets/blood_pulse_app_bar.dart';
import 'package:blood_pulse/core/widgets/responsive_layout.dart';
import 'package:blood_pulse/features/auth/presentation/providers/locale_provider.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'package:blood_pulse/features/blood_hub/presentation/providers/poster_provider.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_editor_controls.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_generator_widget.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_share_sheet.dart';

/// Full screen enabling customizable poster editing, live preview, export, and social sharing.
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
      final pngFile = await _generatorKey.currentState?.exportPNG();
      if (pngFile == null) {
        throw Exception('Could not capture poster image.');
      }

      final repo = ref.read(posterRepositoryProvider);
      final savedFile = await repo.exportToGallery(pngFile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text(
              isBangla
                  ? 'গ্যালারিতে সেভ হয়েছে: ${savedFile.path.split("/").last}'
                  : 'Poster saved to gallery: ${savedFile.path.split("/").last}',
              style: const TextStyle(fontFamily: 'Inter'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              isBangla
                  ? 'সেভ করতে ব্যর্থ হয়েছে: $e'
                  : 'Failed to export poster: $e',
              style: const TextStyle(fontFamily: 'Inter'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _sharePoster(bool isBangla, {String? platform}) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final pngFile = await _generatorKey.currentState?.exportPNG();
      if (pngFile == null) {
        throw Exception('Could not capture poster image.');
      }

      final repo = ref.read(posterRepositoryProvider);
      await repo.sharePoster(
        pngFile,
        _posterData,
        platform: platform,
        isBangla: isBangla,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              isBangla
                  ? 'শেয়ার করতে ব্যর্থ হয়েছে: $e'
                  : 'Failed to share poster: $e',
              style: const TextStyle(fontFamily: 'Inter'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
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
        title: isBangla ? 'পোস্টার জেনারেটর' : 'Poster Generator',
        titleColor: AppColors.primary,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: ResponsiveLayout(
        maxWidth: 600,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    _templateTypeSelector(isBangla),
                    const SizedBox(height: 16),
                    Center(
                      child: PosterGeneratorWidget(
                        key: _generatorKey,
                        data: _posterData,
                        templateType: _templateType,
                        isBangla: isBangla,
                      ),
                    ),
                    const SizedBox(height: 20),
                    PosterEditorControls(
                      initialData: _posterData,
                      isBangla: isBangla,
                      onDataChanged: (updated) =>
                          setState(() => _posterData = updated),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            _bottomActionBar(isBangla),
          ],
        ),
      ),
    );
  }

  Widget _templateTypeSelector(bool isBangla) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3DDE0),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          _templateTab(
            type: PosterTemplateType.withPhoto,
            label: isBangla ? '১. ছবিসহ' : '1. Photo',
          ),
          _templateTab(
            type: PosterTemplateType.textOnly,
            label: isBangla ? '২. টেক্সট' : '2. Text',
          ),
          _templateTab(
            type: PosterTemplateType.blank,
            label: isBangla ? '৩. কাস্টম' : '3. Custom',
          ),
        ],
      ),
    );
  }

  Widget _templateTab({
    required PosterTemplateType type,
    required String label,
  }) {
    final isSelected = _templateType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _templateType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomActionBar(bool isBangla) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
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
                isBangla ? 'গ্যালারিতে সংরক্ষণ' : 'Save to Gallery',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
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
                        onSelectChannel: (platform) => _sharePoster(isBangla, platform: platform),
                      ),
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              label: Text(
                isBangla ? 'শেয়ার করুন' : 'Share Poster',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
