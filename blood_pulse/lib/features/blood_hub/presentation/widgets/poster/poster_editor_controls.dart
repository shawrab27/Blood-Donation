// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'poster_editor_inputs.dart';

/// Interactive editor controls allowing the user to customize poster content in real-time.
class PosterEditorControls extends StatefulWidget {
  const PosterEditorControls({
    super.key,
    required this.initialData,
    required this.onDataChanged,
    this.isBangla = false,
  });

  final PosterData initialData;
  final ValueChanged<PosterData> onDataChanged;
  final bool isBangla;

  @override
  State<PosterEditorControls> createState() => _PosterEditorControlsState();
}

class _PosterEditorControlsState extends State<PosterEditorControls> {
  late TextEditingController _patientCtrl;
  late TextEditingController _hospitalCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _contactCtrl;
  late TextEditingController _conditionCtrl;
  late TextEditingController _messageCtrl;

  late PosterData _currentData;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentData = widget.initialData;
    _patientCtrl = TextEditingController(text: _currentData.patientName);
    _hospitalCtrl = TextEditingController(text: _currentData.hospitalName ?? '');
    _locationCtrl = TextEditingController(text: _currentData.location);
    _contactCtrl = TextEditingController(text: _currentData.contactNumber ?? '');
    _conditionCtrl = TextEditingController(text: _currentData.condition);
    _messageCtrl = TextEditingController(text: _currentData.customMessage ?? '');
  }

  @override
  void dispose() {
    _patientCtrl.dispose();
    _hospitalCtrl.dispose();
    _locationCtrl.dispose();
    _contactCtrl.dispose();
    _conditionCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _notifyUpdate(PosterData updated) {
    setState(() => _currentData = updated);
    widget.onDataChanged(updated);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final Uint8List bytes = await picked.readAsBytes();
        _notifyUpdate(
          _currentData.copyWith(
            photoPath: picked.path,
            photoBytes: bytes,
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isBangla ? 'পোস্টার এডিটর' : 'Poster Content Editor',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                  side: const BorderSide(color: AppColors.primary),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: () => _pickPhoto(ImageSource.gallery),
                icon: const Icon(Icons.add_a_photo_rounded,
                    size: 15, color: AppColors.primary),
                label: Text(
                  widget.isBangla ? 'ছবি পরিবর্তন' : 'Change Photo',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PosterInputPill(
            controller: _patientCtrl,
            label: widget.isBangla ? 'রোগীর নাম' : 'Patient Name',
            onChanged: (v) =>
                _notifyUpdate(_currentData.copyWith(patientName: v)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PosterBloodDropdown(
                  value: _currentData.bloodGroup,
                  isBangla: widget.isBangla,
                  onChanged: (val) =>
                      _notifyUpdate(_currentData.copyWith(bloodGroup: val)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PosterUnitsStepper(
                  units: _currentData.unitsNeeded,
                  isBangla: widget.isBangla,
                  onChanged: (u) =>
                      _notifyUpdate(_currentData.copyWith(unitsNeeded: u)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PosterInputPill(
                  controller: _hospitalCtrl,
                  label: widget.isBangla ? 'হাসপাতাল' : 'Hospital Name',
                  onChanged: (v) =>
                      _notifyUpdate(_currentData.copyWith(hospitalName: v)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PosterInputPill(
                  controller: _locationCtrl,
                  label: widget.isBangla ? 'অবস্থান' : 'Location / District',
                  onChanged: (v) =>
                      _notifyUpdate(_currentData.copyWith(location: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PosterInputPill(
                  controller: _contactCtrl,
                  label: widget.isBangla ? 'যোগাযোগ নম্বর' : 'Contact Phone',
                  keyboardType: TextInputType.phone,
                  onChanged: (v) =>
                      _notifyUpdate(_currentData.copyWith(contactNumber: v)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PosterInputPill(
                  controller: _conditionCtrl,
                  label: widget.isBangla ? 'কারণ / রোগ' : 'Medical Condition',
                  onChanged: (v) =>
                      _notifyUpdate(_currentData.copyWith(condition: v)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PosterUrgencyChips(
            selectedLevel: _currentData.urgencyLevel,
            onChanged: (lvl) =>
                _notifyUpdate(_currentData.copyWith(urgencyLevel: lvl)),
          ),
          const SizedBox(height: 10),
          PosterInputPill(
            controller: _messageCtrl,
            label: widget.isBangla ? 'কাস্টম বার্তা (ঐচ্ছিক)' : 'Custom Message',
            maxLines: 2,
            onChanged: (v) =>
                _notifyUpdate(_currentData.copyWith(customMessage: v)),
          ),
        ],
      ),
    );
  }
}
