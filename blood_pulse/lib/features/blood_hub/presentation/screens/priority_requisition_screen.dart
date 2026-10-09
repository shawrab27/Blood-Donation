// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';
import '../widgets/requisition/patient_details_card.dart';
import '../widgets/requisition/location_urgency_card.dart';
import '../widgets/requisition/medical_verification_card.dart';

/// Screen 3: Priority Blood Requisition form conforming to Stitch UI specification.
class PriorityBloodRequisitionScreen extends ConsumerStatefulWidget {
  const PriorityBloodRequisitionScreen({
    super.key,
    this.prefillBloodGroup,
    this.prefillComponent,
    this.prefillDistrict,
    this.mode,
  });

  final String? prefillBloodGroup;
  final String? prefillComponent;
  final String? prefillDistrict;
  final String? mode;

  @override
  ConsumerState<PriorityBloodRequisitionScreen> createState() =>
      _PriorityBloodRequisitionScreenState();
}

class _PriorityBloodRequisitionScreenState
    extends ConsumerState<PriorityBloodRequisitionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _conditionController = TextEditingController();
  final _contactController = TextEditingController();
  final _hospitalController = TextEditingController();

  String? _selectedBloodGroup;
  HospitalModel? _selectedHospital;
  String _urgencyLevel = 'URGENT';
  DateTime? _customDateTime;
  Uint8List? _patientPhotoBytes;
  Uint8List? _verificationFileBytes;
  String? _verificationFileName;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedBloodGroup = widget.prefillBloodGroup;
    if (widget.prefillDistrict != null) {
      _hospitalController.text = widget.prefillDistrict!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _conditionController.dispose();
    _contactController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  Future<void> _submitRequisition() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBloodGroup == null || _selectedBloodGroup!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a required blood group.'),
          backgroundColor: Color(0xFFC30121),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final patientName = _nameController.text.trim();
      final hospital = _selectedHospital?.nameEn ?? _hospitalController.text.trim();
      final contact = _contactController.text.trim();

      if (mounted) {
        context.push(
          '/identity/verify',
          extra: {
            'patientName': patientName,
            'bloodGroup': _selectedBloodGroup,
            'urgencyLevel': _urgencyLevel,
            'hospitalLocation': hospital.isNotEmpty ? hospital : 'Medical Center',
            'contactNumber': contact,
            'condition': _conditionController.text.trim(),
            'returnRoute': '/blood-hub/poster',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error preparing request: $e'),
            backgroundColor: const Color(0xFFC30121),
          ),
        );
      }
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
          'Emergency Blood Request',
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
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeToggle(),
                  const SizedBox(height: 20),
                  PatientDetailsCard(
                    nameController: _nameController,
                    conditionController: _conditionController,
                    contactController: _contactController,
                    selectedBloodGroup: _selectedBloodGroup,
                    onBloodGroupChanged: (bg) => setState(() => _selectedBloodGroup = bg),
                    patientPhotoBytes: _patientPhotoBytes,
                    onPhotoPicked: (bytes) => setState(() => _patientPhotoBytes = bytes),
                  ),
                  const SizedBox(height: 20),
                  LocationUrgencyCard(
                    hospitalController: _hospitalController,
                    selectedHospital: _selectedHospital,
                    onHospitalSelected: (h) => setState(() => _selectedHospital = h),
                    urgencyLevel: _urgencyLevel,
                    onUrgencyChanged: (lvl) => setState(() => _urgencyLevel = lvl),
                    customDateTime: _customDateTime,
                    onDateTimeChanged: (dt) => setState(() => _customDateTime = dt),
                  ),
                  const SizedBox(height: 20),
                  MedicalVerificationCard(
                    verificationFileBytes: _verificationFileBytes,
                    fileName: _verificationFileName,
                    onFilePicked: (bytes, name) => setState(() {
                      _verificationFileBytes = bytes;
                      _verificationFileName = name;
                    }),
                  ),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Your request will be visible to nearby compatible donors immediately.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF8E7D7F)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFE8DADA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => context.canPop() ? context.pop() : context.go('/blood-hub/search'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                child: const Text(
                  'Search Donors',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5F5E5E),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFC30121),
                borderRadius: BorderRadius.circular(50),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Request for Blood',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRequisition,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC30121),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                'Submit Request',
                style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
