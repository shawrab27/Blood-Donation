// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/custom_input_field.dart';

/// Modal bottom sheet allowing quick edit of user's personal donor bio quote.
class EditBioSheet extends StatefulWidget {
  final String initialBio;
  final ValueChanged<String> onSave;

  const EditBioSheet({
    super.key,
    required this.initialBio,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required String initialBio,
    required ValueChanged<String> onSave,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EditBioSheet(
        initialBio: initialBio,
        onSave: onSave,
      ),
    );
  }

  @override
  State<EditBioSheet> createState() => _EditBioSheetState();
}

class _EditBioSheetState extends State<EditBioSheet> {
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Donor Bio',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              PressableScale(child: IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )),
            ],
          ),
          const SizedBox(height: 12),
          CustomInputField(
            label: 'Your Personal Motto',
            hint: 'e.g. Committed to saving lives, one drop at a time.',
            controller: _bioController,
            maxLines: 2,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: PressableScale(child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final text = _bioController.text.trim();
                if (text.isNotEmpty) {
                  widget.onSave(text);
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                'Save Bio',
                style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
              ),
            )),
          ),
        ],
      ),
    );
  }
}
