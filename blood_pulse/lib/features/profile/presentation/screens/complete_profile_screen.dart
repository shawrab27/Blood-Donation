import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../../services/api_client.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/providers/profile_provider.dart';

/// CompleteProfileScreen — Progressive Profiling Screen.
/// Enforces dark surface `#271816` with glassy red and white accents.
/// Only requests essential data: Blood Group, City, and Phone Number.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  String? _selectedBloodGroup;
  String? _selectedCity;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'
  ];

  static const List<String> _majorCities = [
    'Dhaka',
    'Chattogram',
    'Rajshahi',
    'Khulna',
    'Barishal',
    'Sylhet',
    'Rangpur',
    'Mymensingh',
    'Cumilla',
    'Gazipur',
    'Narayanganj',
    'Bogura',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileProvider).value;
      final authUser = ref.read(authProvider).user;

      if (profile != null) {
        if (profile.bloodGroup != null && _bloodGroups.contains(profile.bloodGroup)) {
          setState(() => _selectedBloodGroup = profile.bloodGroup);
        }
        if (profile.district != null && profile.district!.isNotEmpty) {
          setState(() {
            _selectedCity = profile.district;
            _cityCtrl.text = profile.district!;
          });
        }
        if (profile.phoneNumber != null && profile.phoneNumber!.isNotEmpty) {
          _phoneCtrl.text = profile.phoneNumber!;
        }
      } else if (authUser != null) {
        if (authUser.bloodGroup.isNotEmpty && _bloodGroups.contains(authUser.bloodGroup)) {
          setState(() => _selectedBloodGroup = authUser.bloodGroup);
        }
        if (authUser.primaryPhone.isNotEmpty) {
          _phoneCtrl.text = authUser.primaryPhone;
        }
      }
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBloodGroup == null) {
      setState(() => _errorMessage = 'Please select your blood group.');
      return;
    }

    final city = _selectedCity ?? _cityCtrl.text.trim();
    if (city.isEmpty) {
      setState(() => _errorMessage = 'Please select or enter your city.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final apiClient = ApiClient();
      final payload = {
        'blood_group': _selectedBloodGroup,
        'district': city,
        'phone_number': _phoneCtrl.text.trim(),
        'is_profile_complete': true,
      };

      final currentProfile = ref.read(profileProvider).value;
      if (currentProfile != null) {
        await apiClient.patch('donors/${currentProfile.id}/', body: payload);
      } else {
        await apiClient.post('donors/', body: payload);
      }

      await ref.read(profileProvider.notifier).fetchProfile();

      final currentUser = ref.read(authProvider).user;
      if (currentUser != null) {
        ref.read(authProvider.notifier).registerUser(
          currentUser.copyWith(
            bloodGroup: _selectedBloodGroup,
            primaryPhone: _phoneCtrl.text.trim(),
            isProfileComplete: true,
            categoryDetails: {
              ...currentUser.categoryDetails,
              'district': city,
            },
          ),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile completed successfully!', style: TextStyle(fontFamily: 'Inter')),
          backgroundColor: Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (context.canPop()) {
        context.pop();
        context.push('/emergency-request');
      } else {
        context.go('/emergency-request');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF271816),
      appBar: const CustomAppBar(
        title: 'Complete Your Profile',
        titleColor: Colors.white,
        backgroundColor: Color(0xFF271816),
        showLogo: false,
        showBackButton: true,
        showNotification: false,
        showProfile: false,
      ),
      body: SafeArea(
        child: ResponsiveCenterWrapper(
          maxWidth: 600,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlassyHeaderCard(),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0x33C30121),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x66C30121)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  _buildGlassyFormCard(),
                  const SizedBox(height: 32),

                  _buildGlassySubmitButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassyHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0x0AFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x14FFFFFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1FC30121),
            blurRadius: 30,
            spreadRadius: -6,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x33C30121),
                  border: Border.all(color: const Color(0x66C30121)),
                ),
                child: const Icon(Icons.emergency_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Almost Ready to Save Lives',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'BloodPulse requires only your essential blood group and location details before you can create requests or respond to urgent emergencies.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: Color(0xB8FFFFFF),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassyFormCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1AFFFFFF), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Blood Group *',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildBloodGroupSelector(),
          const SizedBox(height: 24),

          const Text(
            'City / District *',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildCitySelector(),
          const SizedBox(height: 24),

          const Text(
            'Phone Number *',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          _buildPhoneField(),
        ],
      ),
    );
  }

  Widget _buildBloodGroupSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: _selectedBloodGroup != null
              ? const Color(0x99C30121)
              : const Color(0x2EFFFFFF),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBloodGroup,
          isExpanded: true,
          dropdownColor: const Color(0xFF271816),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
          hint: const Text(
            'Select Blood Group (e.g. O+, A+)',
            style: TextStyle(fontFamily: 'Inter', color: Color(0x73FFFFFF), fontSize: 14),
          ),
          items: _bloodGroups.map((group) {
            return DropdownMenuItem<String>(
              value: group,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC30121),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    group,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedBloodGroup = val),
        ),
      ),
    );
  }

  Widget _buildCitySelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: _selectedCity != null
              ? const Color(0x99C30121)
              : const Color(0x2EFFFFFF),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCity,
          isExpanded: true,
          dropdownColor: const Color(0xFF271816),
          icon: const Icon(Icons.location_city_rounded, color: Colors.white70, size: 20),
          hint: const Text(
            'Select City / Division',
            style: TextStyle(fontFamily: 'Inter', color: Color(0x73FFFFFF), fontSize: 14),
          ),
          items: _majorCities.map((city) {
            return DropdownMenuItem<String>(
              value: city,
              child: Text(
                city,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedCity = val;
              _cityCtrl.text = val ?? '';
            });
          },
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneCtrl,
      keyboardType: TextInputType.phone,
      style: const TextStyle(fontFamily: 'Inter', color: Colors.white, fontSize: 14),
      validator: (val) {
        if (val == null || val.trim().isEmpty) {
          return 'Phone number is required';
        }
        if (val.trim().length < 9) {
          return 'Please enter a valid phone number';
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: 'e.g. 01712345678',
        hintStyle: const TextStyle(fontFamily: 'Inter', color: Color(0x73FFFFFF), fontSize: 14),
        prefixIcon: const Icon(Icons.phone_android_rounded, color: Color(0x99FFFFFF), size: 20),
        filled: true,
        fillColor: const Color(0x0FFFFFFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Color(0x2EFFFFFF)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Color(0xCCC30121), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Color(0xCCFF5252)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildGlassySubmitButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        gradient: const LinearGradient(
          colors: [
            Color(0x59C30121),
            Color(0x1FFFFFFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xBFC30121),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40C30121),
            blurRadius: 20,
            spreadRadius: -2,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: _isSubmitting ? null : _submitProfile,
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Save & Continue',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                        ],
                      ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
