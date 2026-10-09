// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Card 3 for Priority Blood Requisition: Medical Verification Upload.
class MedicalVerificationCard extends StatelessWidget {
  const MedicalVerificationCard({
    super.key,
    required this.verificationFileBytes,
    required this.fileName,
    required this.onFilePicked,
  });

  final Uint8List? verificationFileBytes;
  final String? fileName;
  final void Function(Uint8List? bytes, String? name) onFilePicked;

  Future<void> _pickFromCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      onFilePicked(bytes, file.name);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file != null) {
      final bytes = await file.readAsBytes();
      onFilePicked(bytes, file.name);
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
          Row(
            children: const [
              Icon(Icons.medical_information_rounded, color: Color(0xFFC30121), size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Medical Verification',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF24191A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Please upload a picture of the medical report or blood test to verify this request.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xFF5F5E5E),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Upload Container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFC30121).withAlpha(80),
                style: BorderStyle.solid,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                if (verificationFileBytes != null) ...[
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF1B8A4E), size: 36),
                  const SizedBox(height: 8),
                  Text(
                    fileName ?? 'Document Uploaded',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF24191A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => onFilePicked(null, null),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                    label: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ] else ...[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE9EB),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: Color(0xFFC30121),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap to upload medical slip',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF24191A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'PNG, JPG up to 10MB',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF8E7D7F),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFromCamera,
                        icon: const Icon(Icons.photo_camera_rounded, size: 16),
                        label: const Text('Camera'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF24191A),
                          side: const BorderSide(color: Color(0xFFE8DADA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Files'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF24191A),
                          side: const BorderSide(color: Color(0xFFE8DADA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
