// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/core/widgets/capsule_button.dart';
import 'package:blood_pulse/features/blood_hub/data/blood_hub_v2_api_service.dart';
import 'package:blood_pulse/services/api_client.dart';

/// Private donor feedback dialog on requester behavior.
/// Features:
/// - 1-5 star selection
/// - Tag chips (gave_travel_cost, gave_food, polite, rude, never_contacted)
/// - Skip / Later allowed (never blocks navigation)
/// - Fully private: no UI hint that the requester can see it
class PrivateDonorFeedbackDialog extends StatefulWidget {
  final int requestId;
  final String hospitalName;
  final VoidCallback? onDismiss;

  const PrivateDonorFeedbackDialog({
    super.key,
    required this.requestId,
    this.hospitalName = 'Hospital',
    this.onDismiss,
  });

  static Future<void> show({
    required BuildContext context,
    required int requestId,
    String hospitalName = 'Hospital',
    VoidCallback? onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PrivateDonorFeedbackDialog(
        requestId: requestId,
        hospitalName: hospitalName,
        onDismiss: onDismiss,
      ),
    );
  }

  @override
  State<PrivateDonorFeedbackDialog> createState() => _PrivateDonorFeedbackDialogState();
}

class _PrivateDonorFeedbackDialogState extends State<PrivateDonorFeedbackDialog> {
  int _stars = 5;
  final Set<String> _selectedTags = {};
  bool _isSubmitting = false;

  final List<Map<String, String>> _availableTags = const [
    {'key': 'POLITE', 'label': 'Polite & Respectful'},
    {'key': 'GAVE_TRAVEL_COST', 'label': 'Offered Travel Support'},
    {'key': 'GAVE_FOOD', 'label': 'Provided Food/Juice'},
    {'key': 'RUDE', 'label': 'Rude or Aggressive'},
    {'key': 'NEVER_CONTACTED', 'label': 'Unreachable / No-show'},
  ];

  Future<void> _submitFeedback() async {
    setState(() => _isSubmitting = true);
    try {
      final api = BloodHubV2ApiService(ApiClient());
      await api.submitDonorFeedback(
        widget.requestId,
        stars: _stars,
        tags: _selectedTags.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDismiss?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Thank you for your confidential feedback.'),
          backgroundColor: Color(0xFF1B8A4E),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDismiss?.call();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Badge & Close
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F2),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Text(
                        'CONFIDENTIAL FEEDBACK',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF757575)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDismiss?.call();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              const Text(
                'How was your donation experience?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B2B2B),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Your feedback helps maintain community safety and is never shown to the requester.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 18),

              // Star Rating (1 to 5)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return IconButton(
                      iconSize: 28,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      icon: Icon(
                        starIndex <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFFFA000),
                      ),
                      onPressed: () => setState(() => _stars = starIndex),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 14),

              // Tag Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _availableTags.map((tag) {
                  final isSelected = _selectedTags.contains(tag['key']);
                  final isNegative = tag['key'] == 'RUDE' || tag['key'] == 'NEVER_CONTACTED';
                  return FilterChip(
                    label: Text(
                      tag['label']!,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected
                            ? (isNegative ? const Color(0xFFC30121) : const Color(0xFF1B8A4E))
                            : const Color(0xFF374151),
                      ),
                    ),
                    selected: isSelected,
                    backgroundColor: const Color(0xFFF3F4F6),
                    selectedColor: isNegative ? const Color(0xFFFFEBEB) : const Color(0xFFE8F5E9),
                    checkmarkColor: isNegative ? const Color(0xFFC30121) : const Color(0xFF1B8A4E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                      side: BorderSide(
                        color: isSelected
                            ? (isNegative ? const Color(0xFFC30121) : const Color(0xFF1B8A4E))
                            : Colors.transparent,
                      ),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag['key']!);
                        } else {
                          _selectedTags.remove(tag['key']!);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // Action Buttons: Submit vs Skip/Later
              SizedBox(
                width: double.infinity,
                child: CapsuleButton(
                  label: _isSubmitting ? 'Submitting...' : 'Submit Private Feedback',
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  isLoading: _isSubmitting,
                  backgroundColor: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onDismiss?.call();
                },
                child: const Text(
                  'Skip / Later',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
