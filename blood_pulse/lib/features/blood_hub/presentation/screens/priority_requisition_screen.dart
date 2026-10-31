import 'package:blood_pulse/core/widgets/pressable_scale.dart';
import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../profile/domain/providers/profile_provider.dart';
import '../../../../services/api_client.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';
import '../../data/blood_hub_v2_api_service.dart';
import '../widgets/requisition/patient_details_card.dart';
import '../widgets/requisition/location_urgency_card.dart';
import '../widgets/requisition/medical_verification_card.dart';
import '../widgets/requisition/requisition_mode_toggle.dart';
import '../../domain/entities/poster_template.dart';
import '../widgets/request_units_progress_card.dart';


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
  final _wardBedController = TextEditingController();

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
    // Pre-cache request OTP configuration in background
    ApiClient().getRequestOtpRequired();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _conditionController.dispose();
    _contactController.dispose();
    _hospitalController.dispose();
    _wardBedController.dispose();
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
      final wardBed = _wardBedController.text.trim();

      final payload = <String, dynamic>{
        'patient_name': patientName,
        'blood_group': _selectedBloodGroup,
        'urgency': _urgencyLevel,
        'hospital_name_other': hospital.isNotEmpty ? hospital : 'Medical Center',
        if (_selectedHospital != null) 'hospital_id': _selectedHospital!.id,
        'ward_bed': wardBed,
        'contact_phone': contact,
        'condition_note': _conditionController.text.trim(),
        'units_needed': 1,
        'component': 'WHOLE',
        'mode': 'EMERGENCY',
      };

      final client = ref.read(apiClientProvider);
      final profile = ref.read(profileProvider).value;
      bool otpRequired = false;
      if (profile != null) {
        otpRequired = profile.requestOtpRequired;
      } else if (client.cachedRequestOtpRequired != null) {
        otpRequired = client.cachedRequestOtpRequired!;
      } else {
        otpRequired = await client.getRequestOtpRequired();
      }

      if (!otpRequired) {
        final res = await ref.read(bloodHubApiServiceProvider).createEmergencyRequest(
          payload,
          fileBytes: _verificationFileBytes,
          filename: _verificationFileName ?? 'requisition_slip.jpg',
          photoBytes: _patientPhotoBytes,
          photoFilename: 'patient_photo.jpg',
        );

        if (mounted) {
          final posterData = PosterData(
            patientName: patientName,
            bloodGroup: _selectedBloodGroup!,
            location: hospital.isNotEmpty ? hospital : 'Dhaka',
            unitsNeeded: 1,
            urgencyLevel: _urgencyLevel,
            condition: _conditionController.text.trim().isNotEmpty
                ? _conditionController.text.trim()
                : 'Medical Emergency',
            hospitalName: hospital.isNotEmpty ? hospital : null,
            contactNumber: contact.isNotEmpty ? contact : null,
            photoBytes: _patientPhotoBytes,
          );
          context.push('/blood-hub/poster', extra: posterData);
        }
        return;
      }

      if (mounted) {
        context.push(
          '/identity-verification',
          extra: {
            'patientName': patientName,
            'bloodGroup': _selectedBloodGroup,
            'urgencyLevel': _urgencyLevel,
            'hospitalLocation': hospital.isNotEmpty ? hospital : 'Medical Center',
            'contactNumber': contact,
            'condition': _conditionController.text.trim(),
            'emergencyPayload': payload,
            'returnRoute': '/blood-hub/poster',
          },
        );
      }
    } catch (e) {
      if (mounted) {
        String friendlyError = 'Unable to submit blood request. Please check your connection and tap Retry.';
        if (e is ApiException) {
          if (e.statusCode == 404) {
            friendlyError = 'Request service endpoint temporarily unavailable. Please tap Retry.';
          } else if (e.statusCode != null && e.statusCode! >= 500) {
            friendlyError = 'Server is currently waking up or busy. Please tap Retry.';
          } else if (e.statusCode == 403) {
            friendlyError = 'Request submission not authorized. Please complete your profile first.';
          } else {
            friendlyError = e.message;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError),
            backgroundColor: const Color(0xFFC30121),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _submitRequisition,
            ),
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
        leading: PressableScale(child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF2B2B2B)),
          onPressed: () => context.canPop() ? context.pop() : context.go('/blood-hub'),
        )),
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const RequisitionModeToggle(),
                  const SizedBox(height: 14),
                  const RequestUnitsProgressCard(
                    compact: true,
                    unitsReceived: 0,
                    unitsPending: 0,
                    unitsNeeded: 1,
                    requestMode: 'PROXY',
                  ),
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
                    wardBedController: _wardBedController,
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

  Widget _buildSubmitButton() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: PressableScale(child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFC30121), width: 1.5),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () {
                final hospital = _selectedHospital?.name ?? _hospitalController.text.trim();
                final posterData = PosterData(
                  patientName: _nameController.text.trim().isNotEmpty
                      ? _nameController.text.trim()
                      : 'Emergency Patient',
                  bloodGroup: _selectedBloodGroup ?? 'B+',
                  location: hospital.isNotEmpty ? hospital : 'Dhaka',
                  unitsNeeded: 1,
                  urgencyLevel: _urgencyLevel,
                  condition: _conditionController.text.trim().isNotEmpty
                      ? _conditionController.text.trim()
                      : 'Medical Emergency',
                  hospitalName: hospital.isNotEmpty ? hospital : null,
                  contactNumber: _contactController.text.trim().isNotEmpty
                      ? _contactController.text.trim()
                      : null,
                  photoBytes: _patientPhotoBytes,
                );
                context.push('/blood-hub/poster', extra: posterData);
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.palette_outlined, color: Color(0xFFC30121), size: 18),
                  SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Create Poster',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: Color(0xFFC30121),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: PressableScale(child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequisition,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC30121),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: AppLoader(),
                    )
                  : const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Confirm Submit',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            )),
          ),
        ),
      ],
    );
  }

}
