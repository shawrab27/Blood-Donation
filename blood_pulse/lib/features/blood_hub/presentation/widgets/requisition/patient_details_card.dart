// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const List<String> _kBloodGroups = [
  'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-',
];

/// Card 1 for Priority Blood Requisition: Patient Details & Optional Photo.
class PatientDetailsCard extends StatelessWidget {
  const PatientDetailsCard({
    super.key,
    required this.nameController,
    required this.conditionController,
    required this.contactController,
    required this.selectedBloodGroup,
    required this.onBloodGroupChanged,
    required this.patientPhotoBytes,
    required this.onPhotoPicked,
  });

  final TextEditingController nameController;
  final TextEditingController conditionController;
  final TextEditingController contactController;
  final String? selectedBloodGroup;
  final ValueChanged<String?> onBloodGroupChanged;
  final Uint8List? patientPhotoBytes;
  final ValueChanged<Uint8List?> onPhotoPicked;

  Future<void> _pickPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      onPhotoPicked(bytes);
    }
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
            'Patient Details',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF24191A),
            ),
          ),
          const SizedBox(height: 16),

          // Optional Patient Photo Picker
          Center(
            child: GestureDetector(
              onTap: () => _pickPhoto(context),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFFFEE9EB),
                    backgroundImage: patientPhotoBytes != null
                        ? MemoryImage(patientPhotoBytes!)
                        : null,
                    child: patientPhotoBytes == null
                        ? const Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 32,
                            color: Color(0xFFC30121),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFC30121),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Patient Photo (Optional)',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: Color(0xFF916F6C),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Patient Name Field
          _buildTextField(
            controller: nameController,
            label: 'Patient Name',
            hint: 'Enter full name',
            validator: (v) => v == null || v.trim().isEmpty ? 'Patient name is required' : null,
          ),
          const SizedBox(height: 14),

          // Blood Group Dropdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Required Blood Type',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5C3F3D),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF3F3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE8DADA)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: selectedBloodGroup,
                    hint: const Text(
                      'Select Type',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFF916F6C),
                      ),
                    ),
                    items: _kBloodGroups.map((bg) {
                      return DropdownMenuItem(
                        value: bg,
                        child: Text(
                          bg,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF24191A),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: onBloodGroupChanged,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Disease / Condition Field
          _buildTextField(
            controller: conditionController,
            label: 'Disease / Condition',
            hint: 'e.g. Surgery, Accident, Anemia',
            validator: (v) => v == null || v.trim().isEmpty ? 'Condition is required' : null,
          ),
          const SizedBox(height: 14),

          // Contact Number Field
          _buildTextField(
            controller: contactController,
            label: 'Contact Number',
            hint: 'e.g. 017XXXXXXXX',
            keyboardType: TextInputType.phone,
            validator: (v) => v == null || v.trim().isEmpty ? 'Contact number is required' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C3F3D),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF24191A),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF916F6C),
            ),
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
      ],
    );
  }
}
