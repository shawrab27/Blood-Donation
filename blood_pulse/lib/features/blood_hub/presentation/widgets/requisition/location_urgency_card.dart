// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/blood_hub_api_service.dart';

/// Card 2 for Priority Blood Requisition: Hospital Location & Urgency.
class LocationUrgencyCard extends ConsumerStatefulWidget {
  const LocationUrgencyCard({
    super.key,
    required this.hospitalController,
    required this.selectedHospital,
    required this.onHospitalSelected,
    required this.urgencyLevel,
    required this.onUrgencyChanged,
    required this.customDateTime,
    required this.onDateTimeChanged,
  });

  final TextEditingController hospitalController;
  final HospitalModel? selectedHospital;
  final ValueChanged<HospitalModel?> onHospitalSelected;
  final String urgencyLevel; // 'NORMAL' | 'URGENT' | 'CUSTOM'
  final ValueChanged<String> onUrgencyChanged;
  final DateTime? customDateTime;
  final ValueChanged<DateTime?> onDateTimeChanged;

  @override
  ConsumerState<LocationUrgencyCard> createState() => _LocationUrgencyCardState();
}

class _LocationUrgencyCardState extends ConsumerState<LocationUrgencyCard> {
  Timer? _debounce;
  List<HospitalModel> _suggestions = [];
  bool _isLoadingHospitals = false;

  void _onHospitalInputChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() => _isLoadingHospitals = true);
      try {
        final res = await ref.read(bloodHubApiServiceProvider).searchHospitals(val.trim());
        if (mounted) setState(() => _suggestions = res);
      } catch (_) {
        if (mounted) setState(() => _suggestions = []);
      } finally {
        if (mounted) setState(() => _isLoadingHospitals = false);
      }
    });
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate != null && context.mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (pickedTime != null) {
        final dt = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );
        widget.onDateTimeChanged(dt);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF3DDE0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Location & Urgency',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF24191A),
            ),
          ),
          const SizedBox(height: 16),

          // Hospital Location Field
          const Text(
            'Hospital Location',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5C3F3D),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.hospitalController,
            onChanged: _onHospitalInputChanged,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: Color(0xFF24191A),
            ),
            decoration: InputDecoration(
              hintText: 'Search hospital name or address',
              hintStyle: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF916F6C),
              ),
              prefixIcon: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFFC30121),
                size: 22,
              ),
              suffixIcon: _isLoadingHospitals
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFFFDF3F3),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE8DADA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE8DADA)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFC30121)),
              ),
            ),
          ),

          // Hospital Suggestions List
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8DADA)),
                boxShadow: const [
                  BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final h = _suggestions[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      h.nameEn.isNotEmpty ? h.nameEn : h.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Text(
                      h.district,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF757575)),
                    ),
                    onTap: () {
                      widget.hospitalController.text = h.nameEn.isNotEmpty ? h.nameEn : h.name;
                      widget.onHospitalSelected(h);
                      setState(() => _suggestions = []);
                    },
                  );
                },
              ),
            ),

          const SizedBox(height: 18),

          // Urgency Level Selector
          const Text(
            'Urgency Level',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5C3F3D),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _urgencyChip(
                label: 'Normal\n(Within 24h)',
                value: 'NORMAL',
              ),
              const SizedBox(width: 8),
              _urgencyChip(
                label: 'Urgent\n(Immediate)',
                value: 'URGENT',
                isHighlighted: true,
              ),
              const SizedBox(width: 8),
              _urgencyChip(
                label: 'Custom',
                value: 'CUSTOM',
              ),
            ],
          ),

          // Custom Date & Time Picker
          if (widget.urgencyLevel == 'CUSTOM') ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: () => _pickDateTime(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF3F3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8DADA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: Color(0xFFC30121), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.customDateTime != null
                            ? '${widget.customDateTime!.toLocal()}'.split('.')[0]
                            : 'Select Required Date & Time',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF24191A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _urgencyChip({
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    final isSelected = widget.urgencyLevel == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => widget.onUrgencyChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isHighlighted ? const Color(0xFFC30121) : const Color(0xFF2B2B2B))
                : const Color(0xFFFDF3F3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.transparent : const Color(0xFFE8DADA),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : const Color(0xFF5F5E5E),
            ),
          ),
        ),
      ),
    );
  }
}
