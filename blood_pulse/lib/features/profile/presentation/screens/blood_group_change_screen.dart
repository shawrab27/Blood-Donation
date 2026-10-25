// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../services/api_client.dart';
import '../../domain/providers/profile_provider.dart';

/// Screen for submitting a clinical blood group change request.
/// Strictly audited: requires laboratory name, test date, clinical reason,
/// optional report document, and affirmative donor consent.
class BloodGroupChangeScreen extends ConsumerStatefulWidget {
  const BloodGroupChangeScreen({super.key});

  @override
  ConsumerState<BloodGroupChangeScreen> createState() => _BloodGroupChangeScreenState();
}

class _BloodGroupChangeScreenState extends ConsumerState<BloodGroupChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _labNameCtrl = TextEditingController();

  String? _requestedGroup;
  DateTime? _testDate;
  dynamic _selectedReportFile;
  Uint8List? _reportBytes;
  String? _reportFileName;
  bool _consentGiven = false;
  bool _isSubmitting = false;
  bool _isLoadingPending = false;
  Map<String, dynamic>? _existingRequest;

  static const List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  @override
  void initState() {
    super.initState();
    _checkExistingRequest();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _labNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkExistingRequest() async {
    try {
      final res = await ApiClient().get('profile/blood-group-change/');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['status'] != null) {
          _existingRequest = data;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingPending = false);
    }
  }

  Future<void> _pickReportFile() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File exceeds 5 MB limit. Please select a smaller file.'),
                backgroundColor: Color(0xFFBA1A1A),
              ),
            );
          }
          return;
        }
        setState(() {
          _selectedReportFile = file;
          _reportBytes = bytes;
          _reportFileName = file.name;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach file: $e')),
        );
      }
    }
  }

  Future<void> _selectTestDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _testDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFC30121)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _testDate = picked);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_requestedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your requested blood group.')),
      );
      return;
    }

    if (_testDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the date of your laboratory test.')),
      );
      return;
    }

    if (!_consentGiven) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must certify that the lab test is authentic.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final body = <String, dynamic>{
        'requested_group': _requestedGroup,
        'reason': _reasonCtrl.text.trim(),
        'lab_name': _labNameCtrl.text.trim(),
        'test_date': DateFormat('yyyy-MM-dd').format(_testDate!),
        'consent': _consentGiven,
      };

      if (_reportBytes != null) {
        body['report_bytes_b64'] = base64Encode(_reportBytes!);
        body['report_filename'] = _reportFileName ?? 'lab_report.pdf';
      }

      final res = await ApiClient().post('profile/blood-group-change/', body: body);

      setState(() => _isSubmitting = false);

      if (res.statusCode == 201 || res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Request submitted! An administrator will review your lab report.'),
              backgroundColor: Color(0xFF1B8A4E),
            ),
          );
          context.pop();
        }
      } else {
        final err = jsonDecode(res.body);
        final msg = err['detail'] ?? err['error'] ?? 'Submission failed. Please check your data.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$msg'), backgroundColor: const Color(0xFFBA1A1A)),
          );
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFBA1A1A)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;
    final currentGroup = profile?.bloodGroup ?? 'O+';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: const CustomAppBar(
        title: 'Blood Group Change',
        showLogo: false,
        showBackButton: true,
        showNotification: false,
        showProfile: false,
      ),
      body: _isLoadingPending
          ? const Center(child: AppLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Active pending request banner
                      if (_existingRequest != null && _existingRequest!['status'] == 'pending') ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFFD8A8)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'Request Under Review',
                                    style: TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You already have a pending change request to ${_existingRequest!["requested_group"]}. '
                                'Our medical team is reviewing the documentation.',
                                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF92400E)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Form
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Current Group Banner
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFF0E5E5)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Current Blood Group',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Locked for Recipient Safety',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF8C8A8A)),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF0F1),
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(color: const Color(0xFFE2D6D6)),
                                    ),
                                    child: Text(
                                      currentGroup,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFC30121),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Requested Blood Group Dropdown
                            const Text(
                              'Requested Blood Group *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: const Color(0xFFE2D6D6)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _requestedGroup,
                                  hint: const Text('Select verified blood group', style: TextStyle(fontFamily: 'Inter', fontSize: 13.5)),
                                  isExpanded: true,
                                  items: _bloodGroups
                                      .where((g) => g != currentGroup)
                                      .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold))))
                                      .toList(),
                                  onChanged: (val) => setState(() => _requestedGroup = val),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Diagnostic Lab Name
                            const Text(
                              'Diagnostic Laboratory Name *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _labNameCtrl,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Please specify the lab name' : null,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: 'e.g. Popular Diagnostic Center, Dhaka',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: Color(0xFFE2D6D6))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: Color(0xFFE2D6D6))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: Color(0xFFC30121))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Test Date Picker
                            const Text(
                              'Date of Lab Test *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _selectTestDate,
                              borderRadius: BorderRadius.circular(50),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(color: const Color(0xFFE2D6D6)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _testDate != null ? DateFormat('d MMMM yyyy').format(_testDate!) : 'Select test date',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 13.5,
                                        color: _testDate != null ? const Color(0xFF24191A) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFC30121)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Clinical Reason
                            const Text(
                              'Reason for Change *',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _reasonCtrl,
                              maxLines: 2,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Please describe why the group changed' : null,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5),
                              decoration: InputDecoration(
                                hintText: 'e.g. Previous test was inaccurate; retested and confirmed',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2D6D6))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2D6D6))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFC30121))),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Lab Report Attachment (Private Encrypted)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFF0E5E5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Expanded(
                                        child: Text(
                                          'Attach Diagnostic Report',
                                          style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'PDF, JPG, PNG (Max 5MB)',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF8C8A8A)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (_selectedReportFile != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF0F1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.attachment_rounded, size: 16, color: Color(0xFFC30121)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _selectedReportFile!.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFC30121)),
                                            ),
                                          ),
                                          PressableScale(child: IconButton(
                                            icon: const Icon(Icons.close_rounded, size: 16),
                                            onPressed: () => setState(() {
                                              _selectedReportFile = null;
                                              _reportBytes = null;
                                              _reportFileName = null;
                                            }),
                                            visualDensity: VisualDensity.compact,
                                          )),
                                        ],
                                      ),
                                    )
                                  else
                                    PressableScale(child: OutlinedButton.icon(
                                      onPressed: _pickReportFile,
                                      icon: const Icon(Icons.upload_file_rounded, size: 16, color: Color(0xFFC30121)),
                                      label: const Text('Choose Document'),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFFC30121)),
                                        foregroundColor: const Color(0xFFC30121),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                      ),
                                    )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Consent Checkbox
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _consentGiven,
                                  activeColor: const Color(0xFFC30121),
                                  onChanged: (val) => setState(() => _consentGiven = val ?? false),
                                ),
                                const Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      'I solemnly certify that the medical report submitted is authentic and accurate. '
                                      'I understand that providing false biological data may endanger transfusion recipients.',
                                      style: TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF5F5E5E), height: 1.3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              height: 52,
                              child: PressableScale(child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _submitRequest,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC30121),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                                  elevation: 2,
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(height: 22, width: 22, child: AppLoader())
                                    : const Text(
                                        'Submit for Clinical Review',
                                        style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                              )),
                            ),
                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
