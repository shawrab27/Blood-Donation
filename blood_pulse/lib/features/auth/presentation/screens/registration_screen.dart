import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/app_logo_slot.dart';
import '../providers/auth_notifier.dart';
import '../providers/otp_provider.dart';

enum _Gender { male, female }

enum _UserCategory { student, civilian }

const List<String> _bloodGroups = [
  'A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−',
];

const List<String> _divisions = [
  'Dhaka', 'Chattogram', 'Rajshahi', 'Khulna',
  'Barishal', 'Sylhet', 'Rangpur', 'Mymensingh',
];

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  // ── Controllers ──────────────────────────────────────────────────────────
  final _nameCtrl       = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _phoneCtrl      = TextEditingController();
  final _altPhoneCtrl   = TextEditingController();
  final _pwCtrl         = TextEditingController();
  final _confirmPwCtrl  = TextEditingController();
  final _ageCtrl        = TextEditingController();

  // Student specific
  final _instituteCtrl  = TextEditingController();
  final _classCtrl      = TextEditingController();
  final _groupCtrl      = TextEditingController();
  final _deptCtrl       = TextEditingController();
  final _studentIdCtrl  = TextEditingController();

  // Civilian specific
  final _zilaCtrl       = TextEditingController();
  final _upazilaCtrl    = TextEditingController();
  final _nidBirthCtrl   = TextEditingController();
  final _villageCtrl    = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  File? _avatarFile;
  _Gender _gender = _Gender.male;
  _UserCategory _category = _UserCategory.student;

  String? _bloodGroup;
  String? _confirmBloodGroup;

  String? _selectedDivision;

  bool _neverDonated = false;
  DateTime? _lastDonationDate;
  int _totalBags = 0;

  // Simulate Primary Number Failure Toggle
  bool _forcePrimaryFailure = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
    _ageCtrl.dispose();
    _instituteCtrl.dispose();
    _classCtrl.dispose();
    _groupCtrl.dispose();
    _deptCtrl.dispose();
    _studentIdCtrl.dispose();
    _zilaCtrl.dispose();
    _upazilaCtrl.dispose();
    _nidBirthCtrl.dispose();
    _villageCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null && mounted) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  Future<void> _showAvatarPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Upload Profile Photo',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE9EB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Camera', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppColors.secondary),
                ),
                title: const Text('Library', style: TextStyle(fontFamily: 'Inter')),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDonationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastDonationDate ?? now,
      firstDate: DateTime(2000),
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

    if (_pwCtrl.text != _confirmPwCtrl.text) {
      _showError('Password confirmation does not match.');
      return;
    }
    if (_bloodGroup == null) {
      _showError('Please select your blood group.');
      return;
    }
    if (_confirmBloodGroup != _bloodGroup) {
      _showError('Blood group confirmation does not match.');
      return;
    }
    if (!_neverDonated && _lastDonationDate == null) {
      _showError('Please select your last donation date or check "Never Donated".');
      return;
    }

    // ── Build UserProfile details ──────────────────────────────────────────
    final catDetails = <String, String>{};
    if (_category == _UserCategory.student) {
      catDetails['institute'] = _instituteCtrl.text.trim();
      if (_classCtrl.text.isNotEmpty) catDetails['class'] = _classCtrl.text.trim();
      if (_groupCtrl.text.isNotEmpty) catDetails['group'] = _groupCtrl.text.trim();
      if (_deptCtrl.text.isNotEmpty) catDetails['dept'] = _deptCtrl.text.trim();
      catDetails['studentId'] = _studentIdCtrl.text.trim();
    } else {
      catDetails['division'] = _selectedDivision ?? '';
      catDetails['district'] = _zilaCtrl.text.trim();
      catDetails['upazila'] = _upazilaCtrl.text.trim();
      catDetails['nidOrBirth'] = _nidBirthCtrl.text.trim();
      catDetails['village'] = _villageCtrl.text.trim();
    }

    final profile = UserProfile(
      fullName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      primaryPhone: _phoneCtrl.text.trim(),
      secondaryPhone: _altPhoneCtrl.text.isNotEmpty ? _altPhoneCtrl.text.trim() : null,
      age: int.parse(_ageCtrl.text),
      gender: _gender == _Gender.male ? 'Male' : 'Female',
      bloodGroup: _bloodGroup!,
      category: _category == _UserCategory.student ? 'student' : 'civilian',
      categoryDetails: catDetails,
      neverDonated: _neverDonated,
      lastDonationDate: _neverDonated ? null : _lastDonationDate,
      totalBagsDonated: _neverDonated ? 0 : _totalBags,
      isOtpVerified: false,
    );

    // Save in AuthNotifier state
    ref.read(authProvider.notifier).registerUser(profile);

    // Trigger OTP sending
    await ref.read(otpStateProvider.notifier).sendOtp(
          primaryPhone: profile.primaryPhone,
          secondaryPhone: profile.secondaryPhone,
          forcePrimaryFailure: _forcePrimaryFailure,
        );

    if (mounted) {
      context.go('/otp-verify');
    }
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
    return ResponsiveLayout(
      backgroundColor: AppColors.surface,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // AppBar
          _buildAppBar(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroHeader(),
                    const SizedBox(height: 24),

                    // Avatar Picker
                    _buildAvatarSection(),
                    const SizedBox(height: 24),

                    _sectionHeader('Account Credentials'),
                    const SizedBox(height: 12),
                    _buildCredentialsSection(),
                    const SizedBox(height: 28),

                    _sectionHeader('Basic Information'),
                    const SizedBox(height: 12),
                    _buildBasicInfoSection(),
                    const SizedBox(height: 28),

                    _sectionHeader('Blood Profile'),
                    const SizedBox(height: 12),
                    _buildBloodProfileSection(),
                    const SizedBox(height: 28),

                    _sectionHeader('Identity Category'),
                    const SizedBox(height: 12),
                    _buildCategorySection(),
                    const SizedBox(height: 28),

                    _sectionHeader('Donation History'),
                    const SizedBox(height: 12),
                    _buildDonationHistorySection(),
                    const SizedBox(height: 24),

                    // Fallback Simulator Switch
                    _buildFallbackSimulatorToggle(),
                    const SizedBox(height: 28),

                    CapsuleButton(
                      label: 'Create Account',
                      showGlow: true,
                      onPressed: _onCreateAccount,
                    ),
                    const SizedBox(height: 20),

                    Center(
                      child: GestureDetector(
                        onTap: () => context.go('/login'),
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontFamily: 'Inter', fontSize: 14),
                            children: [
                              TextSpan(
                                text: 'Already a member? ',
                                style: TextStyle(color: AppColors.neutral),
                              ),
                              TextSpan(
                                text: 'Sign In',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/login'),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: AppColors.secondary),
            ),
          ),
          const SizedBox(width: 12),
          const AppLogoSlot(size: AppLogoSize.header),
          const SizedBox(width: 8),
          const Text(
            'Blood Pulse',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Your Profile',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Join the national verified blood network',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showAvatarPicker,
            child: CircleAvatar(
              radius: 46,
              backgroundColor: const Color(0xFFF3DDE0),
              backgroundImage: _avatarFile != null ? FileImage(_avatarFile!) : null,
              child: _avatarFile == null
                  ? const Icon(Icons.camera_alt_rounded, size: 32, color: AppColors.primary)
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add Profile Photo',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.tertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsSection() {
    return Column(
      children: [
        CustomInputField(
          controller: _emailCtrl,
          hint: 'Email Address',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _phoneCtrl,
          hint: 'Primary Phone Number (Mandatory)',
          prefixIcon: Icons.phone_android_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Primary phone is required' : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _altPhoneCtrl,
          hint: 'Secondary Phone Number (Optional)',
          prefixIcon: Icons.phone_callback_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _pwCtrl,
          hint: 'Password',
          prefixIcon: Icons.lock_outline_rounded,
          isPassword: true,
          textInputAction: TextInputAction.next,
          validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _confirmPwCtrl,
          hint: 'Confirm Password',
          prefixIcon: Icons.lock_rounded,
          isPassword: true,
          textInputAction: TextInputAction.next,
          validator: (v) => (v == null || v.isEmpty) ? 'Please confirm your password' : null,
        ),
      ],
    );
  }

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomInputField(
          controller: _nameCtrl,
          hint: 'Full Name',
          prefixIcon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _ageCtrl,
          hint: 'Age',
          prefixIcon: Icons.cake_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: (v) {
            if (v == null || v.isEmpty) return 'Age is required';
            final age = int.tryParse(v);
            if (age == null || age < 18 || age > 65) {
              return 'Donors must be between 18 and 65 years old';
            }
            return null;
          },
        ),
        const SizedBox(height: 14),
        const Text(
          'Gender',
          style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF3DDE0),
            borderRadius: BorderRadius.circular(50),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildGenderPill(_Gender.male, 'Male'),
              _buildGenderPill(_Gender.female, 'Female'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGenderPill(_Gender g, String label) {
    final isSelected = _gender == g;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = g),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.neutral,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBloodProfileSection() {
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
          const Text(
            'Select Blood Group',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
          const SizedBox(height: 8),
          _buildBloodGroupDropdown(
            value: _bloodGroup,
            hint: 'Choose Group',
            onChanged: (v) => setState(() => _bloodGroup = v),
          ),
          const SizedBox(height: 14),
          const Text(
            'Confirm Blood Group',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
          ),
          const SizedBox(height: 8),
          _buildBloodGroupDropdown(
            value: _confirmBloodGroup,
            hint: 'Confirm Group',
            onChanged: (v) => setState(() => _confirmBloodGroup = v),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '🔒 Note: Blood Group can ONLY be edited by an Admin once saved',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
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
    required String? value,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.neutral)),
          isExpanded: true,
          items: _bloodGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      children: [
        Row(
          children: [
            _buildCategoryToggle(_UserCategory.student, 'Student'),
            const SizedBox(width: 12),
            _buildCategoryToggle(_UserCategory.civilian, 'Civilian'),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _category == _UserCategory.student ? _buildStudentFields() : _buildCivilianFields(),
        ),
      ],
    );
  }

  Widget _buildCategoryToggle(_UserCategory c, String label) {
    final isSelected = _category == c;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _category = c),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.secondary : const Color(0xFFF3DDE0),
            borderRadius: BorderRadius.circular(50),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.neutral,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentFields() {
    return Column(
      key: const ValueKey('student_fields'),
      children: [
        CustomInputField(
          controller: _instituteCtrl,
          hint: 'Educational Institution Name',
          prefixIcon: Icons.school_outlined,
          textInputAction: TextInputAction.next,
          validator: (v) => _category == _UserCategory.student && (v == null || v.trim().isEmpty)
              ? 'Institution is required'
              : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _studentIdCtrl,
          hint: 'Student ID (Must)',
          prefixIcon: Icons.badge_outlined,
          textInputAction: TextInputAction.next,
          validator: (v) => _category == _UserCategory.student && (v == null || v.trim().isEmpty)
              ? 'Student ID is required'
              : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _deptCtrl,
          hint: 'Department (Optional)',
          prefixIcon: Icons.account_tree_outlined,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: CustomInputField(
                controller: _classCtrl,
                hint: 'Class (Optional)',
                prefixIcon: Icons.class_outlined,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomInputField(
                controller: _groupCtrl,
                hint: 'Group (Optional)',
                prefixIcon: Icons.group_work_outlined,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCivilianFields() {
    return Column(
      key: const ValueKey('civilian_fields'),
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedDivision,
          decoration: InputDecoration(
            hintText: 'Select Division',
            prefixIcon: const Icon(Icons.map_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(50)),
          ),
          items: _divisions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => _selectedDivision = v),
          validator: (v) => _category == _UserCategory.civilian && v == null ? 'Division required' : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _zilaCtrl,
          hint: 'District (Zila)',
          prefixIcon: Icons.location_city_outlined,
          textInputAction: TextInputAction.next,
          validator: (v) => _category == _UserCategory.civilian && (v == null || v.trim().isEmpty)
              ? 'District required'
              : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _upazilaCtrl,
          hint: 'Upazila',
          prefixIcon: Icons.navigation_outlined,
          textInputAction: TextInputAction.next,
          validator: (v) => _category == _UserCategory.civilian && (v == null || v.trim().isEmpty)
              ? 'Upazila required'
              : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _nidBirthCtrl,
          hint: 'NID / Birth Certificate Number',
          prefixIcon: Icons.credit_card_outlined,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          validator: (v) => _category == _UserCategory.civilian && (v == null || v.trim().isEmpty)
              ? 'NID/Birth Certificate number is required'
              : null,
        ),
        const SizedBox(height: 14),
        CustomInputField(
          controller: _villageCtrl,
          hint: 'Village / Area',
          prefixIcon: Icons.home_outlined,
          textInputAction: TextInputAction.next,
          validator: (v) => _category == _UserCategory.civilian && (v == null || v.trim().isEmpty)
              ? 'Village is required'
              : null,
        ),
      ],
    );
  }

  Widget _buildDonationHistorySection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: _neverDonated,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() {
                  _neverDonated = v ?? false;
                  if (_neverDonated) {
                    _lastDonationDate = null;
                    _totalBags = 0;
                  }
                }),
              ),
              const Expanded(
                child: Text(
                  'I have never donated blood before',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.secondary),
                ),
              ),
            ],
          ),
          if (!_neverDonated) ...[
            const SizedBox(height: 16),
            const Text(
              'Last Donation Date',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDonationDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, color: AppColors.neutral, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      _lastDonationDate != null
                          ? '${_lastDonationDate?.day}/${_lastDonationDate?.month}/${_lastDonationDate?.year}'
                          : 'Select Date',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: _lastDonationDate != null ? AppColors.secondary : AppColors.neutral,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Total Bags Donated',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildCounterBtn(Icons.remove, () => setState(() => _totalBags = (_totalBags - 1).clamp(0, 99))),
                const SizedBox(width: 20),
                Text('$_totalBags', style: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 20),
                _buildCounterBtn(Icons.add, () => setState(() => _totalBags = (_totalBags + 1).clamp(0, 99))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCounterBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFFF3DDE0),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
    );
  }

  Widget _buildFallbackSimulatorToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0E4FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.track_changes_outlined, color: AppColors.tertiary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Simulate Primary Phone Delivery Failure (Force SMS Reroute)',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.tertiary),
            ),
          ),
          Switch(
            value: _forcePrimaryFailure,
            activeThumbColor: AppColors.tertiary,
            activeTrackColor: AppColors.tertiary.withAlpha(128),
            onChanged: (val) => setState(() => _forcePrimaryFailure = val),
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
