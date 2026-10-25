// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_v2_api_service.dart';

/// Screen allowing requesters to compose and send structured Thank You Letters to matched donors.
class ThankYouLetterScreen extends ConsumerStatefulWidget {
  const ThankYouLetterScreen({
    super.key,
    required this.matchId,
    this.donorName = 'Valued Donor',
  });

  final int matchId;
  final String donorName;

  @override
  ConsumerState<ThankYouLetterScreen> createState() => _ThankYouLetterScreenState();
}

class _ThankYouLetterScreenState extends ConsumerState<ThankYouLetterScreen> {
  String _selectedTemplateKey = 'warm_gratitude';
  late final TextEditingController _bodyController;
  bool _isSending = false;

  final Map<String, String> _templates = {
    'warm_gratitude':
        'Dear donor, thank you deeply for stepping forward and donating blood today. '
        'Your selflessness has saved a life and brought immense hope to our family.',
    'family_blessing':
        'On behalf of our entire family, we pray for your continued good health and happiness. '
        'You answered our call at the most critical hour, and we are forever grateful.',
    'life_saver':
        'You are a true everyday hero. Your timely arrival and voluntary donation made all '
        'the difference between despair and survival. May your kindness be rewarded tenfold.',
    'custom': '',
  };

  @override
  void initState() {
    super.initState();
    _bodyController = TextEditingController(text: _templates['warm_gratitude']);
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  void _onTemplateSelected(String key) {
    setState(() {
      _selectedTemplateKey = key;
      _bodyController.text = _templates[key] ?? '';
    });
  }

  Future<void> _submitLetter() async {
    final text = _bodyController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please write a thank you note before sending.'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      await ref.read(bloodHubV2ApiServiceProvider).sendThankYouLetter(
            widget.matchId,
            _selectedTemplateKey,
            text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Thank You Letter sent to donor!'),
          backgroundColor: Color(0xFF1B8A4E),
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
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: PressableScale(child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2B2B2B)),
          onPressed: () => context.canPop() ? context.pop() : context.go('/blood-hub'),
        )),
        title: const Text(
          'Letter of Gratitude',
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
                          color: Color(0xFFFEE9EB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.favorite_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Honoring ${widget.donorName}',
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2B2B2B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Sending gratitude inspires lifelong voluntary donors.',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Choose Template Format',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChip('warm_gratitude', 'Warm Gratitude'),
                    _buildChip('family_blessing', 'Family Blessing'),
                    _buildChip('life_saver', 'Life Saver'),
                    _buildChip('custom', 'Custom Message'),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Message Body',
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
                    controller: _bodyController,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Type your message of appreciation here...',
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 13, height: 1.5),
                  ),
                ),
                const SizedBox(height: 30),
                CapsuleButton(
                  label: 'Send Letter of Gratitude',
                  isLoading: _isSending,
                  onPressed: _isSending ? null : _submitLetter,
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

  Widget _buildChip(String key, String label) {
    final isSelected = _selectedTemplateKey == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : AppColors.primary,
        fontSize: 12,
      ),
      onSelected: (_) => _onTemplateSelected(key),
    );
  }
}
