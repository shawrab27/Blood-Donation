// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_v2_api_service.dart';

/// Screen allowing donors to answer 24h post-donation wellness follow-up checks.
class FollowUpScreen extends ConsumerStatefulWidget {
  const FollowUpScreen({
    super.key,
    required this.followupId,
    this.hospitalName = 'Medical Center',
  });

  final int followupId;
  final String hospitalName;

  @override
  ConsumerState<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends ConsumerState<FollowUpScreen> {
  String _selectedResponse = 'OK'; // OK | NOT_OK
  final _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
    setState(() => _isSubmitting = true);
    try {
      await ref.read(bloodHubV2ApiServiceProvider).answerFollowUp(
            widget.followupId,
            _selectedResponse,
            notes: _notesController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedResponse == 'OK'
              ? '✓ Thank you! Glad to know you are feeling well.'
              : 'Medical team alerted. Please stay hydrated and rest.'),
          backgroundColor:
              _selectedResponse == 'OK' ? const Color(0xFF1B8A4E) : AppColors.primary,
        ),
      );
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/blood-hub');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.primary,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2B2B2B)),
          onPressed: () => context.canPop() ? context.pop() : context.go('/blood-hub'),
        ),
        title: const Text(
          'Donor Wellness Check',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B2B2B),
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          maxWidth: 600,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3DDE0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFF1B8A4E), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Post-Donation Care',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2B2B2B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '24-Hour follow-up for your donation at ${widget.hospitalName}.',
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'How are you feeling right now?',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoiceCard(
                        title: 'Feeling Great',
                        subtitle: 'No dizziness or issues',
                        icon: Icons.sentiment_very_satisfied_rounded,
                        value: 'OK',
                        color: const Color(0xFF1B8A4E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildChoiceCard(
                        title: 'Need Advice',
                        subtitle: 'Dizziness or discomfort',
                        icon: Icons.sentiment_dissatisfied_rounded,
                        value: 'NOT_OK',
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Additional Notes (Optional)',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF3DDE0)),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Share any symptoms, recovery details or notes...',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.5),
                  ),
                ),
                const SizedBox(height: 30),
                CapsuleButton(
                  label: 'Submit Wellness Response',
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submitAnswer,
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required Color color,
  }) {
    final isSelected = _selectedResponse == value;
    return InkWell(
      onTap: () => setState(() => _selectedResponse = value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFF3DDE0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? color : const Color(0xFF64748B), size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? color : const Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
