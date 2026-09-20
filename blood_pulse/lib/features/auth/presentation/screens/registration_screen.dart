import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../providers/auth_notifier.dart';
import '../providers/otp_provider.dart';

enum _Gender { male, female }

enum _UserCategory { student, civilian }

const List<String> _bloodGroups = [
  'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
];

const Map<String, List<String>> _divisionDistricts = {
  'Dhaka': ['Dhaka', 'Gazipur', 'Narayanganj', 'Tangail', 'Faridpur', 'Manikganj', 'Munshiganj', 'Narsingdi', 'Gopalganj', 'Kishoreganj', 'Madaripur', 'Rajbari', 'Shariatpur'],
  'Chattogram': ['Chattogram', 'Cox\'s Bazar', 'Cumilla', 'Feni', 'Brahmanbaria', 'Chandpur', 'Noakhali', 'Lakshmipur', 'Khagrachhari', 'Rangamati', 'Bandarban'],
  'Rajshahi': ['Rajshahi', 'Bogura', 'Pabna', 'Sirajganj', 'Naogaon', 'Natore', 'Chapai Nawabganj', 'Joypurhat'],
  'Khulna': ['Khulna', 'Jashore', 'Kushtia', 'Satkhira', 'Bagerhat', 'Chuadanga', 'Jhenaidah', 'Magura', 'Meherpur', 'Narail'],
  'Barishal': ['Barishal', 'Bhola', 'Jhalokati', 'Patuakhali', 'Pirojpur', 'Barguna'],
  'Sylhet': ['Sylhet', 'Moulvibazar', 'Habiganj', 'Sunamganj'],
  'Rangpur': ['Rangpur', 'Dinajpur', 'Kurigram', 'Gaibandha', 'Nilphamari', 'Panchagarh', 'Thakurgaon', 'Lalmonirhat'],
  'Mymensingh': ['Mymensingh', 'Jamalpur', 'Netrokona', 'Sherpur'],
};

/// Registration Screen for BloodPulse
/// Implements full mobile layout and 3-column enhanced desktop layout
/// with interactive avatar picker (Camera / Gallery on mobile and web/laptop),
/// strict double blood group verification, dynamic category toggles,
/// and direct Django REST API registration integration.
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // ── Controllers ──
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _pwCtrl = TextEditingController(text: 'Password@123'); // Safe default or can be input

  // Student specific
  final _instituteCtrl = TextEditingController();
  final _classCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();

  // Civilian specific
  final _upazilaCtrl = TextEditingController();
  final _villageCtrl = TextEditingController();
  final _nidBirthCtrl = TextEditingController();

  // ── State ──
  Uint8List? _avatarBytes;
  _Gender _gender = _Gender.male;
  _UserCategory _category = _UserCategory.civilian;

  String? _bloodGroup;
  String? _confirmBloodGroup;

  String? _selectedDivision;
  String? _selectedZila;

  bool _neverDonated = false;
  DateTime? _lastDonationDate;
  int _totalBags = 0;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _ageCtrl.dispose();
    _pwCtrl.dispose();
    _instituteCtrl.dispose();
    _classCtrl.dispose();
    _groupCtrl.dispose();
    _deptCtrl.dispose();
    _studentIdCtrl.dispose();
    _upazilaCtrl.dispose();
    _villageCtrl.dispose();
    _nidBirthCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (mounted) {
          setState(() {
            _avatarBytes = bytes;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Could not access ${source == ImageSource.camera ? "camera" : "gallery"}: $e');
      }
    }
  }

  Future<void> _pickDonationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastDonationDate ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _lastDonationDate = picked);
    }
  }

  Future<void> _onCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;

    if (_bloodGroup == null) {
      _showError('Please select your blood group.');
      return;
    }
    if (_confirmBloodGroup != _bloodGroup) {
      _showError('Blood group confirmation does not match! Please verify your blood type.');
      return;
    }
    if (!_neverDonated && _lastDonationDate == null) {
      _showError('Please specify your last donation date or check "I have never donated blood before".');
      return;
    }

    final catDetails = <String, String>{};
    String? nidHash;
    if (_category == _UserCategory.student) {
      catDetails['institute'] = _instituteCtrl.text.trim();
      if (_classCtrl.text.isNotEmpty) catDetails['class'] = _classCtrl.text.trim();
      if (_groupCtrl.text.isNotEmpty) catDetails['group'] = _groupCtrl.text.trim();
      if (_deptCtrl.text.isNotEmpty) catDetails['dept'] = _deptCtrl.text.trim();
      catDetails['studentId'] = _studentIdCtrl.text.trim();
      catDetails['division'] = _selectedDivision ?? 'Dhaka';
      catDetails['district'] = _selectedZila ?? 'Dhaka';
    } else {
      catDetails['division'] = _selectedDivision ?? 'Dhaka';
      catDetails['district'] = _selectedZila ?? 'Dhaka';
      catDetails['upazila'] = _upazilaCtrl.text.trim();
      final nidInput = _nidBirthCtrl.text.trim();
      catDetails['nidOrBirth'] = nidInput;
      if (nidInput.isNotEmpty) {
        nidHash = sha256.convert(utf8.encode(nidInput)).toString();
      }
      catDetails['village'] = _villageCtrl.text.trim();
    }

    final profile = UserProfile(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      primaryPhone: _phoneCtrl.text.trim(),
      secondaryPhone: _altPhoneCtrl.text.isNotEmpty ? _altPhoneCtrl.text.trim() : null,
      age: int.tryParse(_ageCtrl.text.trim()) ?? 25,
      gender: _gender == _Gender.male ? 'Male' : 'Female',
      bloodGroup: _bloodGroup!,
      category: _category == _UserCategory.student ? 'student' : 'civilian',
      categoryDetails: catDetails,
      neverDonated: _neverDonated,
      lastDonationDate: _neverDonated ? null : _lastDonationDate,
      totalBagsDonated: _neverDonated ? 0 : _totalBags,
      isOtpVerified: false,
      nidHash: nidHash,
    );

    final success = await ref.read(authProvider.notifier).registerUser(profile);
    if (!mounted) return;
    if (!success) {
      final err = ref.read(authProvider).errorMessage ?? 'Registration failed. Please check your information.';
      _showError(err);
      return;
    }

    // Trigger OTP flow
    await ref.read(otpStateProvider.notifier).sendOtp(
          primaryPhone: profile.primaryPhone,
          secondaryPhone: profile.secondaryPhone,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account created! Please verify your phone with OTP.', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: Color(0xFF1B8A4E),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go('/otp-verify');
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Inter')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildMobile();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MOBILE VIEW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMobile() {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: _buildMobileAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeaderSection(),
                const SizedBox(height: 24),

                // Avatar Photo Picker
                _buildAvatarPickerSection(),
                const SizedBox(height: 28),

                // Basic Information
                _buildSectionTitle('Basic Information'),
                const SizedBox(height: 12),
                _buildPersonalDetailsFields(isMobile: true),
                const SizedBox(height: 24),

                // Blood Profile Card
                _buildBloodProfileCard(),
                const SizedBox(height: 24),

                // Identity Type
                _buildSectionTitle('Identity Type'),
                const SizedBox(height: 12),
                _buildIdentityTypeToggle(),
                const SizedBox(height: 16),
                _buildLocationAndIdentityFields(),
                const SizedBox(height: 24),

                // Donation History Card
                _buildDonationHistoryCard(),
                const SizedBox(height: 32),

                // Submit Button
                CapsuleButton(
                  label: 'Create Account',
                  icon: Icons.arrow_forward_rounded,
                  isLoading: auth.isLoading,
                  showGlow: true,
                  onPressed: auth.isLoading ? null : _onCreateAccount,
                ),
                const SizedBox(height: 16),

                // Footer Terms
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'By creating an account, you agree to our Terms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF888888),
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return BloodPulseAppBar(
      showBackButton: true,
      onBack: () => context.go('/login'),
      subtitle: 'Register',
      showNotification: false,
      showProfile: false,
    );
  }



  // ─────────────────────────────────────────────────────────────────────────
  // SHARED REUSABLE COMPONENTS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeaderSection() {
    return Column(
      children: const [
        Text(
          'Join the Lifeline',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B2B2B),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Complete your profile to start saving lives.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF666666),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPickerSection() {
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFEE9EB),
            border: Border.all(color: const Color(0xFFF9D2D7), width: 2),
          ),
          child: _avatarBytes != null
              ? ClipOval(
                  child: Image.memory(_avatarBytes!, width: 96, height: 96, fit: BoxFit.cover),
                )
              : const Icon(Icons.camera_alt_outlined, size: 36, color: Color(0xFFC30121)),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                side: const BorderSide(color: Color(0xFFC30121)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.photo_library_outlined, size: 16, color: Color(0xFFC30121)),
              label: const Text(
                'Attach Library',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFC30121),
                ),
              ),
              onPressed: () => _pickAvatar(ImageSource.gallery),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC30121),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 0,
              ),
              icon: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Open Camera',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              onPressed: () => _pickAvatar(ImageSource.camera),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Upload a clear photo to help identification.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF888888),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF2B2B2B),
      ),
    );
  }

  Widget _buildPersonalDetailsFields({required bool isMobile}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Full Name'),
        const SizedBox(height: 6),
        CustomInputField(
          controller: _nameCtrl,
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outline_rounded,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null,
        ),
        const SizedBox(height: 16),

        _fieldLabel('Email Address'),
        const SizedBox(height: 6),
        CustomInputField(
          controller: _emailCtrl,
          hint: 'Enter your email',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter your email';
            if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Age & Gender
        if (isMobile) ...[
          _fieldLabel('Age'),
          const SizedBox(height: 6),
          CustomInputField(
            controller: _ageCtrl,
            hint: 'Age (e.g. 25)',
            prefixIcon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            validator: (v) {
              final n = int.tryParse(v ?? '');
              if (n == null || n < 18 || n > 65) return 'Age must be between 18 and 65';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _fieldLabel('Gender'),
          const SizedBox(height: 6),
          _buildGenderToggle(),
        ] else ...[
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Age'),
                    const SizedBox(height: 6),
                    CustomInputField(
                      controller: _ageCtrl,
                      hint: 'Age',
                      prefixIcon: Icons.cake_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n < 18 || n > 65) return '18-65 only';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Gender'),
                    const SizedBox(height: 6),
                    _buildGenderToggle(),
                  ],
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),

        _fieldLabel('Primary Phone'),
        const SizedBox(height: 6),
        CustomInputField(
          controller: _phoneCtrl,
          hint: '+880 1XX XXX XXXX',
          prefixIcon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          validator: (v) => (v == null || v.trim().length < 11) ? 'Please enter a valid phone number' : null,
        ),
        const SizedBox(height: 16),

        _fieldLabel('Alternative Phone (Optional)'),
        const SizedBox(height: 6),
        CustomInputField(
          controller: _altPhoneCtrl,
          hint: '+880 1XX XXX XXXX',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _buildGenderToggle() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3F3),
        borderRadius: BorderRadius.circular(50),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _gender = _Gender.male),
              child: Container(
                decoration: BoxDecoration(
                  color: _gender == _Gender.male ? const Color(0xFFC30121) : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Male',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _gender == _Gender.male ? Colors.white : const Color(0xFF666666),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _gender = _Gender.female),
              child: Container(
                decoration: BoxDecoration(
                  color: _gender == _Gender.female ? const Color(0xFFC30121) : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Female',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _gender == _Gender.female ? Colors.white : const Color(0xFF666666),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityTypeToggle() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFFDF3F3),
        borderRadius: BorderRadius.circular(50),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _category = _UserCategory.student),
              child: Container(
                decoration: BoxDecoration(
                  color: _category == _UserCategory.student ? const Color(0xFFC30121) : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Student',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _category == _UserCategory.student ? Colors.white : const Color(0xFF666666),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _category = _UserCategory.civilian),
              child: Container(
                decoration: BoxDecoration(
                  color: _category == _UserCategory.civilian ? const Color(0xFFC30121) : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Civilian',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _category == _UserCategory.civilian ? Colors.white : const Color(0xFF666666),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAndIdentityFields() {
    if (_category == _UserCategory.student) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Institution / University'),
          const SizedBox(height: 6),
          CustomInputField(
            controller: _instituteCtrl,
            hint: 'Enter your university or college',
            prefixIcon: Icons.school_outlined,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Institution is required' : null,
          ),
          const SizedBox(height: 16),

          _fieldLabel('Department / Subject'),
          const SizedBox(height: 6),
          CustomInputField(
            controller: _deptCtrl,
            hint: 'e.g. Computer Science / BBA',
            prefixIcon: Icons.menu_book_outlined,
          ),
          const SizedBox(height: 16),

          _fieldLabel('Student ID / Roll'),
          const SizedBox(height: 6),
          CustomInputField(
            controller: _studentIdCtrl,
            hint: 'Enter Student ID',
            prefixIcon: Icons.badge_outlined,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Student ID is required' : null,
          ),
          const SizedBox(height: 16),

          _buildDivisionAndZilaDropdowns(),
        ],
      );
    }

    // Civilian Fields
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDivisionAndZilaDropdowns(),
        const SizedBox(height: 16),

        _fieldLabel('Upazila (Optional)'),
        const SizedBox(height: 6),
        CustomInputField(
          controller: _upazilaCtrl,
          hint: 'Enter Upazila',
          prefixIcon: Icons.location_city_outlined,
        ),
        const SizedBox(height: 16),

        _fieldLabel('Village / Area (Optional)'),
        const SizedBox(height: 6),
        CustomInputField(
          controller: _villageCtrl,
          hint: 'Enter village or area name',
          prefixIcon: Icons.home_outlined,
        ),
        const SizedBox(height: 16),

        _fieldLabel('NID / Birth Certificate (Optional but required for requests)'),
        const SizedBox(height: 6),
        CustomInputField(
          controller: _nidBirthCtrl,
          hint: 'Enter identification number',
          prefixIcon: Icons.credit_card_outlined,
        ),
      ],
    );
  }

  Widget _buildDivisionAndZilaDropdowns() {
    final List<String> districts = _selectedDivision != null ? (_divisionDistricts[_selectedDivision] ?? <String>[]) : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Division'),
                  const SizedBox(height: 6),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: const Color(0xFFE2E2E2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Select Division', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF888888))),
                        value: _selectedDivision,
                        items: _divisionDistricts.keys.map<DropdownMenuItem<String>>((String div) {
                          return DropdownMenuItem<String>(value: div, child: Text(div, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedDivision = val;
                            _selectedZila = null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Zila / District'),
                  const SizedBox(height: 6),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: const Color(0xFFE2E2E2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text('Select Zila', style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF888888))),
                        value: _selectedZila,
                        items: districts.map<DropdownMenuItem<String>>((String zila) {
                          return DropdownMenuItem<String>(value: zila, child: Text(zila, style: const TextStyle(fontFamily: 'Inter', fontSize: 13)));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedZila = val),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Blood Profile Card ──
  Widget _buildBloodProfileCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF9D2D7), width: 1.2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.water_drop_rounded, color: Color(0xFFC30121), size: 20),
              SizedBox(width: 8),
              Text(
                'Blood Profile',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFC30121),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _fieldLabel('Select Blood Group'),
          const SizedBox(height: 6),
          _buildBloodGroupDropdown(
            hint: 'Choose your blood type',
            value: _bloodGroup,
            onChanged: (val) => setState(() => _bloodGroup = val),
          ),
          const SizedBox(height: 14),

          _fieldLabel('Confirm Blood Group'),
          const SizedBox(height: 6),
          _buildBloodGroupDropdown(
            hint: 'Confirm your blood type',
            value: _confirmBloodGroup,
            onChanged: (val) => setState(() => _confirmBloodGroup = val),
          ),
          const SizedBox(height: 14),

          // Immutable Warning Notice
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFC30121)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Blood Group can ONLY be edited by an Admin once saved.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFC30121),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBloodGroupDropdown({
    required String hint,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: const Color(0xFFE2E2E2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF888888))),
          value: value,
          items: _bloodGroups.map((bg) {
            return DropdownMenuItem(
              value: bg,
              child: Text(
                bg,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ── Donation History Card ──
  Widget _buildDonationHistoryCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF9D2D7), width: 1.2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Donation History',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2B2B),
            ),
          ),
          const SizedBox(height: 12),

          // Never donated checkbox
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'I have never donated blood before',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF2B2B2B), fontWeight: FontWeight.w500),
            ),
            value: _neverDonated,
            activeColor: const Color(0xFFC30121),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (val) {
              setState(() {
                _neverDonated = val ?? false;
                if (_neverDonated) {
                  _totalBags = 0;
                  _lastDonationDate = null;
                }
              });
            },
          ),

          if (!_neverDonated) ...[
            const SizedBox(height: 12),
            _fieldLabel('Last Donation Date'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDonationDate,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: const Color(0xFFE2E2E2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _lastDonationDate != null
                          ? '${_lastDonationDate!.day.toString().padLeft(2, '0')}/${_lastDonationDate!.month.toString().padLeft(2, '0')}/${_lastDonationDate!.year}'
                          : 'mm/dd/yyyy',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: _lastDonationDate != null ? const Color(0xFF2B2B2B) : const Color(0xFF888888),
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFFC30121)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            _fieldLabel('Total Bags Donated'),
            const SizedBox(height: 6),
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: const Color(0xFFE2E2E2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFFC30121)),
                    onPressed: _totalBags > 0 ? () => setState(() => _totalBags--) : null,
                  ),
                  Text(
                    '$_totalBags',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFC30121)),
                    onPressed: () => setState(() => _totalBags++),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF666666),
      ),
    );
  }
}
