// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/capsule_button.dart';
import '../../../data/blood_hub_v2_api_service.dart';

/// Modal bottom sheet allowing reporting of journey failure & escalation to standby donor.
class DonorTrackingActionsSheet extends ConsumerStatefulWidget {
  const DonorTrackingActionsSheet({
    super.key,
    required this.matchId,
    required this.onReportSuccess,
  });

  final int matchId;
  final VoidCallback onReportSuccess;

  static Future<void> show(
    BuildContext context, {
    required int matchId,
    required VoidCallback onReportSuccess,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DonorTrackingActionsSheet(
        matchId: matchId,
        onReportSuccess: onReportSuccess,
      ),
    );
  }

  @override
  ConsumerState<DonorTrackingActionsSheet> createState() =>
      _DonorTrackingActionsSheetState();
}

class _DonorTrackingActionsSheetState
    extends ConsumerState<DonorTrackingActionsSheet> {
  String _selectedReason = 'NO_SHOW';
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);
    try {
      final res = await ref.read(bloodHubV2ApiServiceProvider).reportMatchFailure(
            widget.matchId,
            _selectedReason,
            _noteController.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onReportSuccess();
      final promoted = res['promoted_standby'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(promoted != null
              ? '✓ Reported. Standby donor #$promoted has been dispatched!'
              : '✓ Journey cancelled & requisition updated.'),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.primary),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Report Issue & Activate Standby',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'If donor cannot fulfill donation, system immediately promotes next verified standby donor.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                _buildReasonChip('NO_SHOW', 'Donor No-Show'),
                _buildReasonChip('MEDICAL', 'Medical Ineligibility'),
                _buildReasonChip('LOGISTICS', 'Logistics/Traffic'),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Brief explanation for records...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
            ),
            const SizedBox(height: 20),
            CapsuleButton(
              label: 'Escalate to Standby Donor',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submitReport,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonChip(String value, String label) {
    final isSelected = _selectedReason == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.secondary,
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      onSelected: (_) => setState(() => _selectedReason = value),
    );
  }
}
