// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:blood_pulse/services/api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../l10n/app_localizations.dart';
import '../providers/auth_notifier.dart';
import '../widgets/institution_autocomplete.dart';
import '../../../../core/access/access_guard.dart';
import '../../../feed/presentation/providers/feed_provider.dart';


enum _Gender { male, female }

enum _UserCategory { student, civilian }

enum _UserIntent { donateAndRequest, onlyRequest }

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
  const RegistrationScreen({
    super.key,
    this.imagePicker,
    this.pickImageFunction,
    this.pickFileFunction,
    this.openAppSettingsFunction,
    this.targetRoute,
    this.prefillName,
    this.prefillEmail,
    this.isGoogleUser = false,
  });

  final ImagePicker? imagePicker;
  final Future<XFile?> Function(ImageSource source)? pickImageFunction;
  final Future<PlatformFile?> Function()? pickFileFunction;
  final Future<bool> Function()? openAppSettingsFunction;
  final String? targetRoute;
  final String? prefillName;
  final String? prefillEmail;
  final bool isGoogleUser;

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ImagePicker _picker;

  // ── Controllers ──
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _pwCtrl = TextEditingController(); // User password input
  final _confirmPwCtrl = TextEditingController();

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
  _UserIntent _userIntent = _UserIntent.donateAndRequest;
  _Gender _gender = _Gender.male;
  _UserCategory _category = _UserCategory.civilian;

  String? _bloodGroup;
  String? _confirmBloodGroup;
  String? _selectedInstitutionId;
  String? _selectedUpazilaId;
  final _apiClient = ApiClient();


  String? _selectedDivision;
  String? _selectedZila;

  bool _neverDonated = false;
  DateTime? _lastDonationDate;
  int _totalBags = 0;

  bool get _isGoogleUser =>
      widget.isGoogleUser ||
      (ref.read(authProvider).user?.authProvider == 'google');

  @override
  void initState() {
    super.initState();
    _picker = widget.imagePicker ?? ImagePicker();
    if (widget.prefillName != null && widget.prefillName!.isNotEmpty) {
      _nameCtrl.text = widget.prefillName!;
    }
    if (widget.prefillEmail != null && widget.prefillEmail!.isNotEmpty) {
      _emailCtrl.text = widget.prefillEmail!;
    }
    _pwCtrl.addListener(_onPasswordChanged);
    _confirmPwCtrl.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _altPhoneCtrl.dispose();
    _ageCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
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

  static const int _maxImageBytes = 5 * 1024 * 1024; // 5 MB
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp'};
  bool _cameraPermanentlyDenied = false;

  Future<void> _processAndSetAvatar(XFile picked) async {
    final name = picked.name.toLowerCase();
    String ext = name.contains('.') ? name.split('.').last : '';
    if (ext.isEmpty && picked.path.contains('.')) {
      ext = picked.path.split('.').last.toLowerCase();
    }

    if (ext.isNotEmpty && !_allowedExtensions.contains(ext)) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showError(l10n?.invalidImageFormat ?? 'Only JPG, JPEG, PNG, and WEBP formats are supported.');
      }
      return;
    }

    final length = await picked.length();
    if (length > _maxImageBytes) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showError(l10n?.imageSizeTooLarge ?? 'Image size must not exceed 5 MB.');
      }
      return;
    }

    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > _maxImageBytes) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        _showError(l10n?.imageSizeTooLarge ?? 'Image size must not exceed 5 MB.');
      }
      return;
    }

    if (mounted) {
      setState(() {
        _avatarBytes = bytes;
      });
    }
  }

  Future<void> _pickAvatarFromGallery() async {
    try {
      final picked = widget.pickImageFunction != null
          ? await widget.pickImageFunction!(ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      await _processAndSetAvatar(picked);
    } catch (e) {
      if (mounted) {
        _showError('Could not access gallery: $e');
      }
    }
  }

  Future<void> _pickAvatarFromFile() async {
    try {
      final file = widget.pickFileFunction != null
          ? await widget.pickFileFunction!()
          : await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
            );
      if (file == null) return;

      final name = file.name.toLowerCase();
      final ext = (file.extension ?? (name.contains('.') ? name.split('.').last : '')).toLowerCase();

      if (!_allowedExtensions.contains(ext)) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _showError(l10n?.invalidImageFormat ?? 'Only JPG, JPEG, PNG, and WEBP formats are supported.');
        }
        return;
      }

      final fileSize = (await file.length()) ?? file.lengthSync();
      if (fileSize != null && fileSize > _maxImageBytes) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _showError(l10n?.imageSizeTooLarge ?? 'Image size must not exceed 5 MB.');
        }
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > _maxImageBytes) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _showError(l10n?.imageSizeTooLarge ?? 'Image size must not exceed 5 MB.');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _avatarBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Could not access file picker: $e');
      }
    }
  }

  Future<void> _pickAvatarFromCamera() async {
    try {
      final picked = widget.pickImageFunction != null
          ? await widget.pickImageFunction!(ImageSource.camera)
          : await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (picked == null) return;
      await _processAndSetAvatar(picked);
    } on PlatformException catch (e) {
      _handleCameraPermissionError(e);
    } catch (e) {
      if (mounted) {
        _showError('Could not access camera: $e');
      }
    }
  }

  void _handleCameraPermissionError(PlatformException e) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final code = e.code.toLowerCase();
    final message = (e.message ?? '').toLowerCase();

    final isPermissionIssue = code.contains('camera_access_denied') ||
        code.contains('permission') ||
        message.contains('denied') ||
        message.contains('permission');

    if (isPermissionIssue) {
      final isPermanent = _cameraPermanentlyDenied ||
          code.contains('permanent') ||
          message.contains('permanent') ||
          message.contains('settings');

      _cameraPermanentlyDenied = true;

      if (isPermanent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.cameraPermissionPermanentlyDenied ??
                  'Camera permission is permanently denied. Please enable it in Settings.',
              style: const TextStyle(fontFamily: 'Inter'),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: const StadiumBorder(),
            action: SnackBarAction(
              label: l10n?.openSettings ?? 'Settings',
              textColor: Colors.white,
              onPressed: () async {
                if (widget.openAppSettingsFunction != null) {
                  await widget.openAppSettingsFunction!();
                } else {
                  await Geolocator.openAppSettings();
                }
              },
            ),
          ),
        );
      } else {
        _showError(l10n?.cameraPermissionDenied ?? 'Camera permission denied.');
      }
    } else {
      _showError('Could not access camera: ${e.message ?? e.code}');
    }
  }

  void _removeAvatarPhoto() {
    if (mounted) {
      setState(() {
        _avatarBytes = null;
      });
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
    if (_nameCtrl.text.trim().isEmpty) {
      _showError('Please enter your full name.');
      return;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _showError('Please enter your phone number.');
      return;
    }
    if (!_isGoogleUser) {
      if (_pwCtrl.text.isEmpty) {
        _showError('Please enter a password.');
        return;
      }
      if (_pwCtrl.text.length < 6) {
        _showError('Password must be at least 6 characters.');
        return;
      }
      if (_pwCtrl.text != _confirmPwCtrl.text) {
        _showError('Passwords do not match. Please re-enter your password.');
        return;
      }
    }
    if (!_formKey.currentState!.validate()) return;

    final isOnlyReq = _userIntent == _UserIntent.onlyRequest;
    if (!isOnlyReq) {
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
    }

    final catDetails = <String, String>{};
    String? nidHash;
    if (_category == _UserCategory.student) {
      if (_selectedInstitutionId != null) {
        catDetails['institution_id'] = _selectedInstitutionId!;
      }
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
      if (_selectedUpazilaId != null) {
        catDetails['upazila_id'] = _selectedUpazilaId!;
      } else {
        catDetails['upazila'] = _upazilaCtrl.text.trim();
      }
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
      bloodGroup: isOnlyReq ? '' : (_bloodGroup ?? ''),
      category: _category == _UserCategory.student ? 'student' : 'civilian',
      categoryDetails: catDetails,
      neverDonated: isOnlyReq ? true : _neverDonated,
      lastDonationDate: (isOnlyReq || _neverDonated) ? null : _lastDonationDate,
      totalBagsDonated: (isOnlyReq || _neverDonated) ? 0 : _totalBags,
      isOtpVerified: true,
      isProfileComplete: true,
      nidHash: nidHash,
      avatarBytes: _avatarBytes,
      authProvider: _isGoogleUser ? 'google' : null,
      userIntent: isOnlyReq ? 'ONLY_REQUEST' : 'DONATE_AND_REQUEST',
    );

    final success = await ref.read(authProvider.notifier).registerUser(
      profile,
      password: _isGoogleUser ? null : _pwCtrl.text,
    );
    if (!mounted) return;
    if (!success) {
      final err = ref.read(authProvider).errorMessage ?? 'Registration failed. Please check your information.';
      _showError(err);
      return;
    }

    // Clear guest mode upon registration
    ref.read(isGuestProvider.notifier).state = false;

    // Immediately authenticate and navigate to target feature or dashboard
    ref.read(authProvider.notifier).setUserForTesting(profile.copyWith(
      isProfileComplete: true,
      isOtpVerified: true,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account created! Welcome to BloodPulse.', style: TextStyle(fontFamily: 'Inter')),
        backgroundColor: Color(0xFF1B8A4E),
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (mounted) {
      final extra = GoRouterState.of(context).extra;
      String? targetRoute;
      if (extra is Map<String, dynamic>) {
        targetRoute = (extra['returnTo'] ?? extra['targetRoute']) as String?;
      }
      targetRoute ??= widget.targetRoute;
      targetRoute ??= ref.read(pendingRedirectRouteProvider);
      ref.read(pendingRedirectRouteProvider.notifier).state = null;

      if (targetRoute != null && targetRoute.isNotEmpty) {
        if (targetRoute == '/blood-hub' || targetRoute == '1') {
          ref.read(shellTabProvider.notifier).state = 1;
          context.go('/dashboard');
        } else if (targetRoute == '/communities' || targetRoute == '2') {
          ref.read(shellTabProvider.notifier).state = 2;
          context.go('/dashboard');
        } else if (targetRoute == '/profile' || targetRoute == '4') {
          ref.read(shellTabProvider.notifier).state = 4;
          context.go('/dashboard');
        } else {
          context.go(targetRoute);
        }
      } else {
        context.go('/dashboard');
      }
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
                const SizedBox(height: 20),

                // Avatar Photo Picker
                _buildAvatarPickerSection(),
                const SizedBox(height: 28),

                // Basic Information
                _buildSectionTitle('Basic Information'),
                const SizedBox(height: 12),
                _buildPersonalDetailsFields(isMobile: true),
                const SizedBox(height: 24),

                // Blood Profile Card (Animated hide for Only Request Blood)
                AnimatedCrossFade(
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBloodProfileCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                  crossFadeState: _userIntent == _UserIntent.donateAndRequest
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 300),
                ),

                // Identity Type
                _buildSectionTitle('Identity Type'),
                const SizedBox(height: 12),
                _buildIdentityTypeToggle(),
                const SizedBox(height: 16),
                _buildLocationAndIdentityFields(),
                const SizedBox(height: 24),

                // Donation History Card (Animated hide for Only Request Blood)
                AnimatedCrossFade(
                  firstChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDonationHistoryCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                  secondChild: const SizedBox.shrink(),
                  crossFadeState: _userIntent == _UserIntent.donateAndRequest
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  duration: const Duration(milliseconds: 300),
                ),

                // Intent Selector (directly ABOVE CapsuleButton submit)
                _buildIntentSelector(),
                const SizedBox(height: 24),

                // Submit Button
                CapsuleButton(
                  label: auth.isLoading
                      ? (_isGoogleUser ? 'Saving Profile...' : 'Creating Account...')
                      : (_isGoogleUser ? 'Complete Registration' : 'Create Account'),
                  icon: Icons.arrow_forward_rounded,
                  isLoading: auth.isLoading,
                  showGlow: true,
                  onPressed: auth.isLoading ? null : _onCreateAccount,
                ),
                if (auth.isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(
                      child: Text(
                        'Please wait up to 60 seconds. The server might be waking up.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFFC30121),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
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
                SizedBox(height: 24 + MediaQuery.viewPaddingOf(context).bottom),
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
      
      actions: const [],
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

  Widget _buildIntentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('I want to:'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFFDEAEB),
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _userIntent = _UserIntent.donateAndRequest),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _userIntent == _UserIntent.donateAndRequest
                          ? const Color(0xFFC30121)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: _userIntent == _UserIntent.donateAndRequest
                          ? [
                              BoxShadow(
                                color: const Color(0xFFC30121).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        'Donate & Request Blood',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _userIntent == _UserIntent.donateAndRequest
                              ? Colors.white
                              : const Color(0xFF2B2B2B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _userIntent = _UserIntent.onlyRequest),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _userIntent == _UserIntent.onlyRequest
                          ? const Color(0xFFC30121)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: _userIntent == _UserIntent.onlyRequest
                          ? [
                              BoxShadow(
                                color: const Color(0xFFC30121).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        'Only Request Blood',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _userIntent == _UserIntent.onlyRequest
                              ? Colors.white
                              : const Color(0xFF2B2B2B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_userIntent == _UserIntent.onlyRequest)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF0D68AA)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'You can request blood when needed. Your profile will not appear in donor searches or maps.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF0D68AA),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarPickerSection() {
    final l10n = AppLocalizations.of(context);
    final hasPhoto = _avatarBytes != null;

    return Center(
      child: Column(
        children: [
          Semantics(
            button: true,
            label: hasPhoto ? 'Change profile photo' : 'Select profile photo',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.none,
              child: InkWell(
                key: const ValueKey('registration_avatar_tap_target'),
                customBorder: const CircleBorder(),
                onTap: _showAvatarPickerModal,
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFDEAEB),
                        ),
                        child: hasPhoto
                            ? ClipOval(
                                child: Image.memory(
                                  _avatarBytes!,
                                  key: const ValueKey('avatar_user_image'),
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Center(
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 36,
                                  color: Color(0xFFC30121),
                                ),
                              ),
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          size: const Size(96, 96),
                          painter: const _DashedCirclePainter(
                            color: Color(0xFFC30121),
                            strokeWidth: 2.0,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        child: hasPhoto
                            ? Container(
                                key: const ValueKey('avatar_edit_badge'),
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC30121),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              )
                            : Container(
                                key: const ValueKey('avatar_optional_badge'),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC30121),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(color: Colors.white, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  l10n?.optionalBadge ?? 'Optional',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n?.photoHelperText ?? 'Upload a clear photo to help identification.',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: Color(0xFF888888),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAvatarPickerModal() {
    final l10n = AppLocalizations.of(context);
    final hasPhoto = _avatarBytes != null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFFFDEAEB),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        final bottomPadding = MediaQuery.viewPaddingOf(modalContext).bottom;
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC30121).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: Color(0xFFC30121),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    l10n?.chooseFromGallery ?? 'Choose from Gallery',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _pickAvatarFromGallery();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      color: Color(0xFFC30121),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    l10n?.chooseFromFile ?? 'Choose from File',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _pickAvatarFromFile();
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xFFC30121),
                      size: 22,
                    ),
                  ),
                  title: Text(
                    l10n?.openCamera ?? 'Open Camera',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    _pickAvatarFromCamera();
                  },
                ),
                if (hasPhoto)
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFC30121),
                        size: 22,
                      ),
                    ),
                    title: Text(
                      l10n?.removePhoto ?? 'Remove photo',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC30121),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(modalContext);
                      _removeAvatarPhoto();
                    },
                  ),
              ],
            ),
          ),
        ),
      );
    },
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
          readOnly: _isGoogleUser,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Please enter your email';
            if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 16),

        if (!_isGoogleUser) ...[
          _fieldLabel('Password'),
          const SizedBox(height: 6),
          CustomInputField(
            controller: _pwCtrl,
            hint: 'Create a strong password',
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter a password';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _fieldLabel('Confirm Password'),
          const SizedBox(height: 6),
          CustomInputField(
            controller: _confirmPwCtrl,
            hint: 'Re-enter your password',
            prefixIcon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please confirm your password';
              if (v != _pwCtrl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 16),
        ],

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
          InstitutionAutocomplete(
            controller: _instituteCtrl,
            apiClient: _apiClient,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Institution is required' : null,
            onSelected: (suggestion) {
              _selectedInstitutionId = suggestion?['id']?.toString();
            },
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
        TypeAheadField<Map<String, dynamic>>(
          controller: _upazilaCtrl,
          builder: (context, controller, focusNode) {
            return CustomInputField(
              controller: controller,
              focusNode: focusNode,
              hint: 'Search Upazila',
              prefixIcon: Icons.location_city_outlined,
            );
          },
          debounceDuration: const Duration(milliseconds: 300),
          suggestionsCallback: (pattern) async {
            if (pattern.trim().length < 2) return [];
            return await _apiClient.searchUpazilas(pattern);
          },
          itemBuilder: (context, suggestion) {
            return ListTile(
              title: Text(suggestion['name'] ?? ''),
              subtitle: Text(suggestion['district_name'] ?? ''),
            );
          },
          onSelected: (suggestion) {
            _upazilaCtrl.text = suggestion['name'] ?? '';
            _selectedUpazilaId = suggestion['id']?.toString();
          },
          emptyBuilder: (context) => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No upazilas found.'),
          ),
        ),
        const SizedBox(height: 16),

        _fieldLabel('Village / Area (Optional)'),
        const SizedBox(height: 6),
        CustomInputField(
          controller: _villageCtrl,
          hint: 'Enter village or area name',
          prefixIcon: Icons.home_outlined,
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
              Expanded(
                child: Text(
                  'Blood Profile',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC30121),
                  ),
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
          Material(
            color: Colors.transparent,
            child: CheckboxListTile(
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

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _DashedCirclePainter({
    this.color = const Color(0xFFC30121),
    this.strokeWidth = 2.0,
  });

  static const double dashLength = 6.0;
  static const double gapLength = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final circumference = 2 * math.pi * radius;
    final totalDash = dashLength + gapLength;
    final count = (circumference / totalDash).floor();
    final sweepPerDash = (2 * math.pi) / count;
    final dashSweep = sweepPerDash * (dashLength / totalDash);

    for (int i = 0; i < count; i++) {
      final startAngle = i * sweepPerDash;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashSweep,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}


