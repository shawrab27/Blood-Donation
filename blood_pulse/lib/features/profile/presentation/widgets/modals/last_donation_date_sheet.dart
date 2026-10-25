// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:blood_pulse/constants/app_config.dart';
import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:blood_pulse/providers/profile_countdown_provider.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';

/// Stitch Screen: Last Donation Date Selection Bottom Sheet
/// 90-day cooldown calculation, future date prevention, error handling.
class LastDonationDateSheet extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const LastDonationDateSheet({super.key, this.initialDate});

  static Future<bool?> show({
    required BuildContext context,
    DateTime? initialDate,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LastDonationDateSheet(initialDate: initialDate),
    );
  }

  @override
  ConsumerState<LastDonationDateSheet> createState() => _LastDonationDateSheetState();
}

class _LastDonationDateSheetState extends ConsumerState<LastDonationDateSheet> {
  late DateTime _selectedDate;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (widget.initialDate != null && widget.initialDate!.isBefore(today.add(const Duration(days: 1)))) {
      _selectedDate = DateTime(widget.initialDate!.year, widget.initialDate!.month, widget.initialDate!.day);
    } else {
      _selectedDate = today;
    }
  }

  DateTime get _nextEligibleDate => _selectedDate.add(Duration(days: AppConfig.donorCooldownDays));

  int get _daysUntilEligible {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = _nextEligibleDate.difference(today).inDays;
    return diff > 0 ? diff : 0;
  }

  Future<void> _handleSave() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedDate.isAfter(today)) {
      setState(() => _errorMessage = 'Cannot select a future date.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final formatted = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final result = await ref.read(profileProvider.notifier).updateLastDonationDate(formatted);

    if (!mounted) return;

    if (result['success'] == true) {
      ref.read(profileCountdownProvider.notifier).recordDonation(_selectedDate);
      ref.invalidate(profileProvider);
      ref.invalidate(profileDonationsProvider);
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Last donation date recorded. Eligibility recalculated.'),
          backgroundColor: Color(0xFF1B8A4E),
        ),
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result['error']?.toString() ?? 'Failed to update donation date.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minDate = today.subtract(const Duration(days: 365 * 3));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
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
              const Text(
                'Record Last Donation',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24191A),
                ),
              ),
              PressableScale(child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                visualDensity: VisualDensity.compact,
              )),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Bangladesh Clinical Protocol: 90-day cooldown between donations.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
          ),
          const SizedBox(height: 12),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF9A8D4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFC30121)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFFC30121)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Calendar Date Picker
          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFFC30121),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Color(0xFF24191A),
              ),
            ),
            child: CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: minDate,
              lastDate: today,
              selectableDayPredicate: (day) => !day.isAfter(today),
              onDateChanged: (val) {
                setState(() {
                  _selectedDate = val;
                  _errorMessage = null;
                });
              },
            ),
          ),
          const SizedBox(height: 12),

          // Calculation summary card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF0E5E5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next Eligible Date',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF5F5E5E)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMMM yyyy').format(_nextEligibleDate),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _daysUntilEligible == 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: _daysUntilEligible == 0 ? const Color(0xFFA5D6A7) : const Color(0xFFF9A8D4),
                    ),
                  ),
                  child: Text(
                    _daysUntilEligible == 0 ? 'Eligible Today' : '$_daysUntilEligible days left',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _daysUntilEligible == 0 ? const Color(0xFF1B8A4E) : const Color(0xFFC30121),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Save Button
          SizedBox(
            height: 48,
            child: PressableScale(child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC30121),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold),
              ),
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: AppLoader.small())
                  : const Text('Save Last Donation Date'),
            )),
          ),
        ],
      ),
    ),
  ),
);
}
}
