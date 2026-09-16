import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../services/ai_trust_detector_service.dart';
import '../providers/blood_request_provider.dart';

enum UrgencyLevel { critical, moderate }

const List<String> _bloodGroups = [
  'A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−',
];

const List<String> _divisions = [
  'Dhaka', 'Chattogram', 'Rajshahi', 'Khulna',
  'Barishal', 'Sylhet', 'Rangpur', 'Mymensingh',
];

class EmergencyRequestScreen extends ConsumerStatefulWidget {
  const EmergencyRequestScreen({super.key});

  @override
  ConsumerState<EmergencyRequestScreen> createState() => _EmergencyRequestScreenState();
}

class _EmergencyRequestScreenState extends ConsumerState<EmergencyRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // Controllers
  final _patientNameCtrl    = TextEditingController();
  final _conditionReasonCtrl = TextEditingController();
  final _hospitalNameCtrl   = TextEditingController();
  final _districtCtrl       = TextEditingController();
  final _upazilaCtrl        = TextEditingController();
  final _addressDetailsCtrl = TextEditingController();
  final _contactPhoneCtrl   = TextEditingController();

  // State
  String? _selectedBloodGroup;
  int _unitsNeeded = 1;
  UrgencyLevel _urgency = UrgencyLevel.critical;
  String? _selectedDivision;

  // Documents
  File? _nidFile;
  File? _medicalReportFile;

  // AI Detection State
  bool _isAnalyzing = false;
  AiDetectionResult? _aiResult;
  bool _simulateFakeReport = false;

  @override
  void dispose() {
    _patientNameCtrl.dispose();
    _conditionReasonCtrl.dispose();
    _hospitalNameCtrl.dispose();
    _districtCtrl.dispose();
    _upazilaCtrl.dispose();
    _addressDetailsCtrl.dispose();
    _contactPhoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(bool isNid) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() {
        if (isNid) {
          _nidFile = File(picked.path);
        } else {
          _medicalReportFile = File(picked.path);
        }
        // Reset previous AI result on new upload
        _aiResult = null;
      });
    }
  }

  Future<void> _runAiDetection() async {
    if (_patientNameCtrl.text.isEmpty) {
      _showSnackBar('Please enter patient name before running AI evaluation.', isError: true);
      return;
    }
    if (_selectedBloodGroup == null) {
      _showSnackBar('Please select required blood group.', isError: true);
      return;
    }
    if (_nidFile == null || _medicalReportFile == null) {
      _showSnackBar('Please upload both NID and Medical Report for AI evaluation.', isError: true);
      return;
    }

    setState(() => _isAnalyzing = true);

    final result = await AiTrustDetectorService.analyzeDocuments(
      nidFile: _nidFile,
      medicalReportFile: _medicalReportFile,
      patientName: _patientNameCtrl.text.trim(),
      selectedBloodGroup: _selectedBloodGroup!,
      simulateFake: _simulateFakeReport,
    );

    if (mounted) {
      setState(() {
        _isAnalyzing = false;
        _aiResult = result;
      });
    }
  }

  void _onSubmitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBloodGroup == null) {
      _showSnackBar('Please select required blood group.', isError: true);
      return;
    }
    if (_nidFile == null || _medicalReportFile == null) {
      _showSnackBar('Mandatory NID & Medical Report uploads are required.', isError: true);
      return;
    }
    if (_aiResult == null) {
      _showSnackBar('Please run AI Document Evaluation before submitting.', isError: true);
      return;
    }
    if (!_aiResult!.isApproved) {
      _showSnackBar('SUBMISSION BLOCKED: AI model flagged high fraud risk / suspect report.', isError: true);
      return;
    }

    final hospitalLoc = _districtCtrl.text.isNotEmpty
        ? '${_hospitalNameCtrl.text.trim()}, ${_districtCtrl.text.trim()}'
        : _hospitalNameCtrl.text.trim();

    final urgencyStr = _urgency == UrgencyLevel.critical ? 'Critical' : 'Moderate';

    final success = await ref.read(bloodRequestProvider.notifier).createRequest(
          patientName: _patientNameCtrl.text.trim(),
          bloodGroup: _selectedBloodGroup!,
          urgencyLevel: urgencyStr,
          hospitalLocation: hospitalLoc,
          contactNumber: _contactPhoneCtrl.text.trim(),
        );

    if (!mounted) return;

    if (!success) {
      final err = ref.read(bloodRequestProvider).errorMessage ?? 'Failed to submit request.';
      _showSnackBar(err, isError: true);
      return;
    }

    // Success dialog
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
            SizedBox(width: 10),
            Text('Request Broadcasted', style: TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Emergency request for ${_patientNameCtrl.text} ($_selectedBloodGroup) has been broadcasted with an AI Trust Score of ${_aiResult!.trustScorePercentage.toInt()}%.',
          style: const TextStyle(fontFamily: 'Inter'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/dashboard');
            },
            child: const Text('Return to Feed', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Emergency Blood Request',
        showBackButton: true,
        onBack: () => context.go('/dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderBanner(),
                const SizedBox(height: 24),

                _sectionHeader('Patient & Medical Details'),
                const SizedBox(height: 12),
                _buildPatientMedicalFields(),
                const SizedBox(height: 28),

                _sectionHeader('Blood & Urgency Requirements'),
                const SizedBox(height: 12),
                _buildBloodUrgencyFields(),
                const SizedBox(height: 28),

                _sectionHeader('Hospital & Location Details'),
                const SizedBox(height: 12),
                _buildHospitalLocationFields(),
                const SizedBox(height: 28),

                _sectionHeader('Contact Information'),
                const SizedBox(height: 12),
                CustomInputField(
                  controller: _contactPhoneCtrl,
                  hint: 'Contact Person Phone Number',
                  prefixIcon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Contact phone is required' : null,
                ),
                const SizedBox(height: 28),

                _sectionHeader('Mandatory Document Uploads'),
                const SizedBox(height: 6),
                Text(
                  'Required for AI Trust Scoring & fake request detection.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
                ),
                const SizedBox(height: 14),
                _buildDocumentUploadBoxes(),
                const SizedBox(height: 24),

                // AI Evaluation Section
                _buildAiEvaluationCard(),
                const SizedBox(height: 20),

                // Debug switch to simulate fake report
                _buildSimulateFakeSwitch(),
                const SizedBox(height: 28),

                // Submit Button
                CapsuleButton(
                  label: 'Broadcast Emergency Request',
                  icon: Icons.send_rounded,
                  showGlow: true,
                  onPressed: _onSubmitRequest,
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          Icon(Icons.emergency_rounded, color: Colors.white, size: 40),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency Blood Request',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                SizedBox(height: 4),
                Text(
                  'AI verified requests get priority notification to matching donors.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientMedicalFields() {
    return Column(
      children: [
        CustomInputField(
          controller: _patientNameCtrl,
          hint: 'Patient Full Name',
          prefixIcon: Icons.person_outline_rounded,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Patient name required' : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _conditionReasonCtrl,
          hint: 'Disease / Medical Condition / Operation Reason',
          prefixIcon: Icons.medical_services_outlined,
          maxLines: 2,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Condition/Reason required' : null,
        ),
      ],
    );
  }

  Widget _buildBloodUrgencyFields() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6BDBA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Required Blood Group', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBloodGroup,
                hint: const Text('Select Blood Group', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)),
                isExpanded: true,
                items: _bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _selectedBloodGroup = v),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Units Needed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Units / Bags Needed', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
              Row(
                children: [
                  _counterBtn(Icons.remove, () => setState(() => _unitsNeeded = (_unitsNeeded - 1).clamp(1, 20))),
                  const SizedBox(width: 16),
                  Text('$_unitsNeeded', style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 16),
                  _counterBtn(Icons.add, () => setState(() => _unitsNeeded = (_unitsNeeded + 1).clamp(1, 20))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Urgency Level Toggle
          const Text('Urgency Level', style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _urgencyPill(
                  level: UrgencyLevel.critical,
                  label: '🚨 Critical (Immediate)',
                  activeColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _urgencyPill(
                  level: UrgencyLevel.moderate,
                  label: '⚠️ Moderate (24 Hours)',
                  activeColor: AppColors.warning,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _urgencyPill({required UrgencyLevel level, required String label, required Color activeColor}) {
    final isSelected = _urgency == level;
    return GestureDetector(
      onTap: () => setState(() => _urgency = level),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF3DDE0),
          borderRadius: BorderRadius.circular(50),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.neutral,
          ),
        ),
      ),
    );
  }

  Widget _counterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0xFFF3DDE0),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }

  Widget _buildHospitalLocationFields() {
    return Column(
      children: [
        CustomInputField(
          controller: _hospitalNameCtrl,
          hint: 'Hospital / Clinic Name',
          prefixIcon: Icons.local_hospital_outlined,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Hospital name required' : null,
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _selectedDivision,
          decoration: InputDecoration(
            hintText: 'Select Division',
            prefixIcon: const Icon(Icons.map_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(50)),
          ),
          items: _divisions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => _selectedDivision = v),
          validator: (v) => v == null ? 'Division required' : null,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: CustomInputField(
                controller: _districtCtrl,
                hint: 'District (Zila)',
                prefixIcon: Icons.location_city_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'District required' : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomInputField(
                controller: _upazilaCtrl,
                hint: 'Upazila',
                prefixIcon: Icons.navigation_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Upazila required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _addressDetailsCtrl,
          hint: 'Detailed Ward / Bed / Address Details',
          prefixIcon: Icons.place_outlined,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Detailed address required' : null,
        ),
      ],
    );
  }

  Widget _buildDocumentUploadBoxes() {
    return Row(
      children: [
        Expanded(
          child: _docBox(
            title: '1. NID / Birth Cert',
            file: _nidFile,
            onTap: () => _pickDocument(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _docBox(
            title: '2. Medical Report',
            file: _medicalReportFile,
            onTap: () => _pickDocument(false),
          ),
        ),
      ],
    );
  }

  Widget _docBox({required String title, required File? file, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: file != null ? Colors.white : const Color(0xFFFFF0F1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: file != null ? AppColors.primary : const Color(0xFFE6BDBA)),
        ),
        child: file == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 28),
                  const SizedBox(height: 6),
                  Text(title, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
                  const SizedBox(height: 4),
                  Text('$title Uploaded', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                ],
              ),
      ),
    );
  }

  Widget _buildAiEvaluationCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology_outlined, color: AppColors.primary, size: 24),
                  SizedBox(width: 8),
                  Text('AI Trust Score Engine', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                ],
              ),
              if (_isAnalyzing)
                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),

          if (_aiResult == null) ...[
            const Text(
              'Click below to scan uploaded documents for AI authenticity verification.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isAnalyzing ? null : _runAiDetection,
              icon: const Icon(Icons.center_focus_strong_rounded),
              label: const Text('Scan & Evaluate Documents with AI'),
            ),
          ] else ...[
            // Score Display
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _aiResult!.trustScorePercentage / 100.0,
                    backgroundColor: Colors.grey.shade200,
                    color: _aiResult!.isApproved ? AppColors.success : AppColors.error,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_aiResult!.trustScorePercentage.toInt()}%',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _aiResult!.isApproved ? AppColors.success : AppColors.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _aiResult!.isApproved ? const Color(0xFFE8F5E9) : const Color(0xFFFFECEE),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _aiResult!.isApproved ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                    size: 16,
                    color: _aiResult!.isApproved ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _aiResult!.authenticityBadge,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _aiResult!.isApproved ? AppColors.success : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Text(
              _aiResult!.analysisSummary,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: _aiResult!.isApproved ? AppColors.secondary : AppColors.error,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: _runAiDetection,
              child: const Text('Re-evaluate Documents'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimulateFakeSwitch() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB3AE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.bug_report_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Simulate Fraudulent / Manipulated Medical Report (Test AI Blocking)',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
            ),
          ),
          Switch(
            value: _simulateFakeReport,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withAlpha(128),
            onChanged: (val) => setState(() {
              _simulateFakeReport = val;
              _aiResult = null; // reset to force re-evaluation
            }),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.secondary,
      ),
    );
  }
}
