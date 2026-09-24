import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Color _kPrimary = Color(0xFFC30121);
const Color _kSecondary = Color(0xFF2B2B2B);
const Color _kBorderIdle = Color(0xFFE8DADA);

const List<String> _kBloodGroups = [
  'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-',
];

const List<String> _kComponents = ['WHOLE', 'RBC', 'PLATELETS', 'PLASMA'];

const List<_UrgencyOption> _kUrgencies = [
  _UrgencyOption('CRITICAL_2H', 'Critical', 'Within 2 h', Color(0xFFC30121)),
  _UrgencyOption('URGENT_6H', 'Urgent', 'Within 6 h', Color(0xFFCC7722)),
  _UrgencyOption('TODAY_24H', 'Today', 'Within 24 h', Color(0xFF0D68AA)),
  _UrgencyOption('SCHEDULED', 'Scheduled', 'Planned', Color(0xFF1A7A3F)),
];

const List<String> _kConditions = [
  'SURGERY',
  'ACCIDENT',
  'THALASSEMIA',
  'CANCER',
  'DENGUE',
  'DELIVERY',
  'OTHER',
];

class _UrgencyOption {
  const _UrgencyOption(this.value, this.label, this.sub, this.color);

  final String value;
  final String label;
  final String sub;
  final Color color;
}

// ─────────────────────────────────────────────────────────────────────────────
// DIRECT REQUEST SCREEN  (/blood-hub/request/direct)
// ─────────────────────────────────────────────────────────────────────────────

/// Priority Requisition form — direct EMERGENCY blood request.
/// Connects to POST /api/emergency/requests/ (mode=EMERGENCY).
class PersonalEmergencyScreen extends ConsumerStatefulWidget {
  const PersonalEmergencyScreen({
    super.key,
    this.prefillBloodGroup,
    this.prefillComponent,
    this.prefillDistrict,
    this.mode,
  });

  final String? prefillBloodGroup;
  final String? prefillComponent;
  final String? prefillDistrict;
  final String? mode; // e.g. "REQUEST_ALL"

  @override
  ConsumerState<PersonalEmergencyScreen> createState() =>
      _PersonalEmergencyScreenState();
}


const Map<String, List<String>> _kDivisionDistricts = {
  'Dhaka': ['Dhaka', 'Gazipur', 'Narayanganj', 'Tangail', 'Faridpur', 'Manikganj', 'Munshiganj', 'Narsingdi', 'Gopalganj', 'Kishoreganj', 'Madaripur', 'Rajbari', 'Shariatpur'],
  'Chattogram': ['Chattogram', "Cox's Bazar", 'Cumilla', 'Feni', 'Brahmanbaria', 'Chandpur', 'Noakhali', 'Lakshmipur', 'Khagrachhari', 'Rangamati', 'Bandarban'],
  'Rajshahi': ['Rajshahi', 'Bogura', 'Pabna', 'Sirajganj', 'Naogaon', 'Natore', 'Chapai Nawabganj', 'Joypurhat'],
  'Khulna': ['Khulna', 'Jashore', 'Kushtia', 'Satkhira', 'Bagerhat', 'Chuadanga', 'Jhenaidah', 'Magura', 'Meherpur', 'Narail'],
  'Barishal': ['Barishal', 'Bhola', 'Jhalokati', 'Patuakhali', 'Pirojpur', 'Barguna'],
  'Sylhet': ['Sylhet', 'Moulvibazar', 'Habiganj', 'Sunamganj'],
  'Rangpur': ['Rangpur', 'Dinajpur', 'Kurigram', 'Gaibandha', 'Nilphamari', 'Panchagarh', 'Thakurgaon', 'Lalmonirhat'],
  'Mymensingh': ['Mymensingh', 'Jamalpur', 'Netrokona', 'Sherpur'],
};

class _PersonalEmergencyScreenState
 extends ConsumerState<PersonalEmergencyScreen> {
  final _formKey = GlobalKey<FormState>();


  // ── Form fields ──────────────────────────────────────────────────────────
  String? _bloodGroup;
  String _component = 'WHOLE';
  int _unitsNeeded = 1;
  String _urgency = 'URGENT_6H';
  String _condition = 'OTHER';
  String? _conditionNote;
  
  // Scope & Geography
  String _scope = 'LOCAL';
  String? _division;
  String? _district;


  // Hospital
  final _hospitalController = TextEditingController();
  HospitalModel? _selectedHospital;
  Timer? _hospitalDebounce;
  List<HospitalModel> _hospitalSuggestions = [];
  bool _loadingHospitals = false;

  // Attendant / contact
  final _patientNameController = TextEditingController();
  final _attendantController = TextEditingController();
  final _contactController = TextEditingController();
  final _wardBedController = TextEditingController();
  final _conditionNoteController = TextEditingController();

  // Photo & slip
  Uint8List? _patientPhotoBytes;
  Uint8List? _slipBytes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _bloodGroup = widget.prefillBloodGroup;
    if (widget.prefillComponent != null &&
        _kComponents.contains(widget.prefillComponent)) {
      _component = widget.prefillComponent!;
    }
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _patientNameController.dispose();
    _attendantController.dispose();
    _contactController.dispose();
    _wardBedController.dispose();
    _conditionNoteController.dispose();
    _hospitalDebounce?.cancel();
    super.dispose();
  }

  // ── Hospital autocomplete ─────────────────────────────────────────────────

  void _onHospitalChanged(String value) {
    _hospitalDebounce?.cancel();
    setState(() {
      _selectedHospital = null;
      _hospitalSuggestions = [];
    });
    if (value.trim().length < 2) return;
    _hospitalDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _loadingHospitals = true);
      try {
        final results = await ref
            .read(bloodHubApiServiceProvider)
            .searchHospitals(value.trim());
        if (mounted) {
          setState(() {
            _hospitalSuggestions = results;
            _loadingHospitals = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _loadingHospitals = false);
      }
    });
  }

  // ── Image picker ──────────────────────────────────────────────────────────

  Future<void> _pickPatientPhoto() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (xfile == null || !mounted) return;
    final bytes = await xfile.readAsBytes();
    setState(() => _patientPhotoBytes = bytes);
  }

  Future<void> _pickRequisitionSlip() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 90,
    );
    if (xfile == null || !mounted) return;
    final bytes = await xfile.readAsBytes();
    setState(() => _slipBytes = bytes);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();
    if (_bloodGroup == null) {
      _showError('Please select a blood group.');
      return;
    }
    if (_contactController.text.trim().isEmpty) {
      _showError('Attendant contact phone is required.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final payload = <String, dynamic>{
        'mode': 'EMERGENCY',
        'blood_group': _bloodGroup,
        'component': _component,
        'units_needed': _unitsNeeded,
        'urgency': _urgency,
        'condition_category': _condition,
        'scope': _scope,
        if (_division != null) 'division_id': _division,
        if (_district != null) 'district': _district,
        if (_conditionNote != null && _conditionNote!.isNotEmpty)
          'condition_note': _conditionNote,
        'patient_name': _patientNameController.text.trim(),
        'attendant_name': _attendantController.text.trim(),
        'contact_phone': _contactController.text.trim(),
        if (_wardBedController.text.trim().isNotEmpty)
          'ward_bed': _wardBedController.text.trim(),
        if (_selectedHospital != null)
          'hospital': _selectedHospital!.id
        else if (_hospitalController.text.trim().isNotEmpty)
          'hospital_name_other': _hospitalController.text.trim(),
        if (_patientPhotoBytes != null)
          'patient_photo_b64': base64Encode(_patientPhotoBytes!),
        if (_slipBytes != null)
          'requisition_slip_b64': base64Encode(_slipBytes!),
      };

      final result = await ref
          .read(bloodHubApiServiceProvider)
          .createEmergencyRequest(payload);

      if (!mounted) return;
      final requestId = result['id']?.toString();
      if (requestId != null) {
        context.go('/journeys/$requestId');
      } else {
        context.go('/emergency/personal');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to submit request: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: _kPrimary,
      ),
    );
  }

  // ── Section builders ──────────────────────────────────────────────────────

  Widget _sectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8E7D7F),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _bloodGroupGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kBloodGroups.map((g) {
        final selected = _bloodGroup == g;
        return GestureDetector(
          onTap: () => setState(() => _bloodGroup = g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 56,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? _kPrimary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: selected ? _kPrimary : _kBorderIdle),
            ),
            child: Center(
              child: Text(
                g,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : _kSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _componentRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _kComponents.map((c) {
        final selected = _component == c;
        return GestureDetector(
          onTap: () => setState(() => _component = c),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color:
                  selected ? const Color(0xFF0D68AA) : Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                color: selected
                    ? const Color(0xFF0D68AA)
                    : _kBorderIdle,
              ),
            ),
            child: Text(
              c,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _kSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _urgencyGrid() {
    return Column(
      children: _kUrgencies.map((opt) {
        final selected = _urgency == opt.value;
        return GestureDetector(
          onTap: () => setState(() => _urgency = opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? opt.color.withAlpha(18) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? opt.color : _kBorderIdle,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? opt.color : const Color(0xFFDDD0D0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: selected ? opt.color : _kSecondary,
                        ),
                      ),
                      Text(
                        opt.sub,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF8E7D7F),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded,
                      color: opt.color, size: 18),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _unitsStepper() {
    return Row(
      children: [
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFEE9EB),
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.remove, color: _kPrimary, size: 18),
          onPressed: _unitsNeeded > 1
              ? () => setState(() => _unitsNeeded--)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          '$_unitsNeeded ${_unitsNeeded == 1 ? 'unit' : 'units'}',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _kSecondary,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFFEE9EB),
            shape: const CircleBorder(),
          ),
          icon: const Icon(Icons.add, color: _kPrimary, size: 18),
          onPressed: _unitsNeeded < 10
              ? () => setState(() => _unitsNeeded++)
              : null,
        ),
      ],
    );
  }

  Widget _buildScopeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('DISPATCH BROADCAST SCOPE'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['LOCAL', 'DISTRICT', 'DIVISION', 'NATIONWIDE'].map((s) {
            final isSelected = _scope == s;
            String label = s == 'LOCAL' ? 'Local (5-10 km)' : s.substring(0, 1) + s.substring(1).toLowerCase();
            return ChoiceChip(
              label: Text(label),
              selected: isSelected,
              selectedColor: _kPrimary,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? Colors.white : _kSecondary,
              ),
              side: BorderSide(
                color: isSelected ? _kPrimary : _kBorderIdle,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(50),
              ),
              onSelected: (selected) {
                if (selected) setState(() => _scope = s);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        const Text(
          'Wider reach needs a higher trust level. Nationwide needs admin approval.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: Color(0xFF8E7D7F),
          ),
        ),
        const SizedBox(height: 16),
        if (_scope == 'DISTRICT' || _scope == 'DIVISION') ...[
          _buildGeoSelectors(),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildGeoSelectors() {
    final divisions = _kDivisionDistricts.keys.toList();
    final districts = _division != null ? _kDivisionDistricts[_division!] ?? [] : [];
    
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'Division',
              labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF8E7D7F)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: _kBorderIdle)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: _kBorderIdle)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            value: _division,
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('Select')),
              ...divisions.map((d) => DropdownMenuItem(value: d, child: Text(d))),
            ],
            onChanged: (val) {
              setState(() {
                _division = val;
                _district = null;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
              labelText: 'District',
              labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF8E7D7F)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: _kBorderIdle)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: _kBorderIdle)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            value: _district,
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('Select')),
              ...districts.map((d) => DropdownMenuItem(value: d, child: Text(d))),
            ],
            onChanged: _division == null ? null : (val) {
              setState(() {
                _district = val;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _hospitalField() {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _textField(
          controller: _hospitalController,
          label: 'Hospital / Clinic',
          hint: 'Type to search hospitals...',
          suffixIcon: _loadingHospitals
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kPrimary,
                  ),
                )
              : null,
          onChanged: _onHospitalChanged,
        ),
        if (_hospitalSuggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: _hospitalSuggestions.take(6).map((h) {
                return ListTile(
                  dense: true,
                  leading: Icon(
                    h.isVerified
                        ? Icons.local_hospital_rounded
                        : Icons.business_rounded,
                    color: h.isVerified
                        ? _kPrimary
                        : const Color(0xFF8E7D7F),
                    size: 18,
                  ),
                  title: Text(
                    h.nameEn,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${h.district}, ${h.division}',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF8E7D7F),
                    ),
                  ),
                  onTap: () {
                    setState(() {
                      _selectedHospital = h;
                      _hospitalController.text = h.nameEn;
                      _hospitalSuggestions = [];
                    });
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _photoUploader({
    required String label,
    required String hint,
    required Uint8List? bytes,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: bytes != null
              ? const Color(0xFFFEE9EB)
              : const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: bytes != null ? _kPrimary : _kBorderIdle,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            if (bytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  bytes,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              )
            else
              const Icon(Icons.add_photo_alternate_outlined,
                  color: Color(0xFF8E7D7F), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kSecondary,
                    ),
                  ),
                  Text(
                    bytes != null ? 'Tap to change' : hint,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: Color(0xFF8E7D7F),
                    ),
                  ),
                ],
              ),
            ),
            if (bytes != null)
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: _kPrimary),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    Widget? suffixIcon,
    bool optional = false,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    void Function(String?)? onSaved,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      onSaved: onSaved,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator ??
          (optional
              ? null
              : (v) => (v == null || v.trim().isEmpty)
                  ? '$label is required'
                  : null),
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        color: _kSecondary,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Color(0xFFBBAAAA),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Color(0xFF8E7D7F),
        ),
        suffix: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: _kBorderIdle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: _kBorderIdle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: _kPrimary),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
      ),
    );
  }

  // ── Main build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ResponsiveCenterWrapper(
        maxWidth: 560,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                // ── Blood Group ──────────────────────────────────────────
                _sectionLabel('BLOOD GROUP *'),
                _bloodGroupGrid(),

                const SizedBox(height: 20),
                // ── Component ────────────────────────────────────────────
                _sectionLabel('BLOOD COMPONENT'),
                _componentRow(),

                const SizedBox(height: 20),
                // ── Units Needed ─────────────────────────────────────────
                _sectionLabel('UNITS NEEDED'),
                _unitsStepper(),

                const SizedBox(height: 20),
                // ── Urgency ──────────────────────────────────────────────
                _sectionLabel('URGENCY LEVEL *'),
                _urgencyGrid(),

                const SizedBox(height: 20),
                // ── Patient Info ─────────────────────────────────────────
                _sectionLabel('PATIENT INFORMATION'),
                _textField(
                  controller: _patientNameController,
                  label: 'Patient Name',
                  hint: 'Full name of patient',
                ),
                const SizedBox(height: 12),

                // ── Hospital ─────────────────────────────────────────────
                _hospitalField(),
                const SizedBox(height: 12),

                _textField(
                  controller: _wardBedController,
                  label: 'Ward / Bed',
                  hint: 'e.g. Ward 4, Bed 12 (optional)',
                  optional: true,
                ),
                const SizedBox(height: 12),

                // ── Condition ────────────────────────────────────────────
                _sectionLabel('CONDITION'),
                DropdownButtonFormField<String>(
                  initialValue: _condition,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: _kSecondary,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: const BorderSide(color: _kBorderIdle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide: const BorderSide(color: _kBorderIdle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(50),
                      borderSide:
                          const BorderSide(color: _kPrimary, width: 1.5),
                    ),
                  ),
                  items: _kConditions
                      .map((c) => DropdownMenuItem<String>(
                            value: c,
                            child: Text(c),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _condition = v);
                  },
                ),
                const SizedBox(height: 12),

                _textField(
                  controller: _conditionNoteController,
                  label: 'Condition Note (optional)',
                  hint: 'Brief description — max 80 chars',
                  optional: true,
                  maxLines: 2,
                  onSaved: (v) => _conditionNote = v?.trim(),
                ),

                const SizedBox(height: 32),
                _buildScopeSection(),
                
                // ── Attendant / Contact ──────────────────────────────────

                _sectionLabel('ATTENDANT INFORMATION'),
                _textField(
                  controller: _attendantController,
                  label: 'Attendant Name',
                  hint: 'Name of person managing this request',
                ),
                const SizedBox(height: 12),
                _textField(
                  controller: _contactController,
                  label: 'Contact Phone *',
                  hint: '+880 ...',
                  keyboardType: TextInputType.phone,
                ),

                const SizedBox(height: 20),
                // ── Patient Photo ────────────────────────────────────────
                _sectionLabel('PATIENT PHOTO (OPTIONAL)'),
                _photoUploader(
                  label: 'Add Patient Photo',
                  hint: 'EXIF/GPS stripped on upload',
                  bytes: _patientPhotoBytes,
                  onPick: _pickPatientPhoto,
                  onRemove: () =>
                      setState(() => _patientPhotoBytes = null),
                ),

                const SizedBox(height: 12),
                // ── Prescription Slip ────────────────────────────────────
                _sectionLabel('PRESCRIPTION SLIP (OPTIONAL)'),
                _photoUploader(
                  label: 'Add Prescription / Lab Slip',
                  hint: 'Doctors note or blood test result',
                  bytes: _slipBytes,
                  onPick: _pickRequisitionSlip,
                  onRemove: () => setState(() => _slipBytes = null),
                ),

              ],
            ),
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F7), // same as _kSurface
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              offset: const Offset(0, -4),
              blurRadius: 12,
            )
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Broadcast Emergency Alert',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ),
    ],
  ),
      ),
    );
  }
}
