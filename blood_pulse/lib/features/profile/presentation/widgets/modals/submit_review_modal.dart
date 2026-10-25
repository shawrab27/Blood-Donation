// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:blood_pulse/services/api_client.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';

/// Modal bottom sheet for submitting a donor review after donation completion
class SubmitReviewModal extends ConsumerStatefulWidget {
  final int donorId;
  final int bloodRequestId;
  final String donorName;

  const SubmitReviewModal({
    super.key,
    required this.donorId,
    required this.bloodRequestId,
    required this.donorName,
  });

  static Future<bool?> show({
    required BuildContext context,
    required int donorId,
    required int bloodRequestId,
    required String donorName,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SubmitReviewModal(
        donorId: donorId,
        bloodRequestId: bloodRequestId,
        donorName: donorName,
      ),
    );
  }

  @override
  ConsumerState<SubmitReviewModal> createState() => _SubmitReviewModalState();
}

class _SubmitReviewModalState extends ConsumerState<SubmitReviewModal> {
  int _stars = 5;
  String _selectedTag = 'Lifesaver';
  final TextEditingController _commentCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<String> _tags = const [
    'Lifesaver',
    'Punctual',
    'Polite',
    'Quick Responder',
    'Hero',
  ];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().post('reviews/', body: {
        'blood_request_id': widget.bloodRequestId,
        'donor_id': widget.donorId,
        'stars': _stars,
        'tag': _selectedTag,
        'comment': _commentCtrl.text.trim(),
      });

      if (!mounted) return;

      if (res.statusCode == 201 || res.statusCode == 200) {
        ref.invalidate(donorReviewsProvider(widget.donorId));
        ref.invalidate(profileProvider);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Thank you! Review submitted successfully.'),
            backgroundColor: Color(0xFF1B8A4E),
          ),
        );
      } else {
        final data = jsonDecode(res.body);
        final msg = data['detail'] ??
            (data is Map && data.values.isNotEmpty ? data.values.first.toString() : 'Failed to submit review');
        setState(() {
          _isSubmitting = false;
          _errorMessage = msg.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Network error. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
              Text(
                'Review ${widget.donorName}',
                style: const TextStyle(
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
            'Your honest feedback ensures transparency and safety in the donor community.',
            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
          ),
          const SizedBox(height: 14),

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

          // Interactive Stars
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starNum = index + 1;
                return PressableScale(child: IconButton(
                  icon: Icon(
                    starNum <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: starNum <= _stars ? const Color(0xFFC30121) : const Color(0xFFE2D6D6),
                  ),
                  onPressed: () => setState(() => _stars = starNum),
                ));
              }),
            ),
          ),
          Center(
            child: Text(
              '$_stars / 5 Stars',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC30121),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Tag chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((t) {
              final isSelected = _selectedTag == t;
              return ChoiceChip(
                label: Text(t),
                selected: isSelected,
                selectedColor: const Color(0xFFC30121),
                backgroundColor: const Color(0xFFFFF8F7),
                labelStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF24191A),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFC30121) : const Color(0xFFF0E5E5),
                  ),
                ),
                onSelected: (val) {
                  if (val) setState(() => _selectedTag = t);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Comment field
          TextField(
            controller: _commentCtrl,
            maxLines: 3,
            maxLength: 200,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Share a note of gratitude or feedback (optional)...',
              hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: Color(0xFF94A3B8)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFF0E5E5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFC30121)),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),

          // Submit Button
          SizedBox(
            height: 48,
            child: PressableScale(child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC30121),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: AppLoader.small())
                  : const Text('Submit Review'),
            )),
          ),
        ],
      ),
    );
  }
}
