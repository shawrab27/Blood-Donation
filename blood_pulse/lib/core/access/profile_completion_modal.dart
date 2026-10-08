// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_input_field.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/profile/domain/providers/profile_provider.dart';
import '../../services/api_client.dart';

/// Modal bottom sheet form for completing missing profile fields.
/// Shows only missing fields from backend: blood group, phone number, district.
/// Address is optional and shown below. Gender is NOT required.
class ProfileCompletionModal extends ConsumerStatefulWidget {
  const ProfileCompletionModal({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        enableDrag: true,
        builder: (ctx) => const ProfileCompletionModal(),
      );

  @override
  ConsumerState<ProfileCompletionModal> createState() => _ProfileCompletionModalState();
}

class _ProfileCompletionModalState extends ConsumerState<ProfileCompletionModal> {
  final _formKey = GlobalKey<FormState>();
  static const List<String> _kBloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  String? _selectedBloodGroup;
  final _phoneCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  bool _showBloodGroup = true;
  bool _showPhone = true;
  bool _showDistrict = true;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    final profile = ref.read(profileProvider).value;
    final user = ref.read(authProvider).user;
    final missing = profile?.missingFields.isNotEmpty == true
        ? profile!.missingFields
        : (user?.missingFields ?? <String>[]);

    final bg = profile?.bloodGroup ?? user?.bloodGroup;
    if (bg != null && _kBloodGroups.contains(bg)) _selectedBloodGroup = bg;

    final phone = profile?.phoneNumber ?? user?.primaryPhone;
    if (phone != null && phone.isNotEmpty && !missing.contains('phone_number')) {
      _phoneCtrl.text = phone;
    }

    final district = profile?.district ?? user?.categoryDetails['district'];
    if (district != null && district.isNotEmpty) _districtCtrl.text = district;

    final address = profile?.address ?? user?.categoryDetails['address'];
    if (address != null && address.isNotEmpty) _addressCtrl.text = address;

    if (missing.isNotEmpty) {
      _showBloodGroup = missing.contains('blood_group');
      _showPhone = missing.contains('phone_number');
      _showDistrict = missing.contains('district');
    } else {
      _showBloodGroup = _selectedBloodGroup == null;
      _showPhone = _phoneCtrl.text.isEmpty;
      _showDistrict = _districtCtrl.text.isEmpty;
    }
    if (!_showBloodGroup && !_showPhone && !_showDistrict) {
      _showBloodGroup = true; _showPhone = true; _showDistrict = true;
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _districtCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_showBloodGroup && (_selectedBloodGroup == null || _selectedBloodGroup!.isEmpty)) {
      setState(() => _errorMessage = 'Please select your blood group.');
      return;
    }
    setState(() { _isSubmitting = true; _errorMessage = null; });

    final payload = <String, dynamic>{
      if (_selectedBloodGroup != null) 'blood_group': _selectedBloodGroup,
      if (_phoneCtrl.text.trim().isNotEmpty) 'phone_number': _phoneCtrl.text.trim(),
      if (_districtCtrl.text.trim().isNotEmpty) 'district': _districtCtrl.text.trim(),
      if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
      'is_profile_complete': true,
    };

    try {
      final success = await ref.read(profileProvider.notifier).updateProfile(payload);
      if (!success) {
        final res = await ApiClient().patch('donors/me/', body: payload);
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw Exception('Failed to update profile: HTTP ${res.statusCode}');
        }
      }

      await ref.read(profileProvider.notifier).fetchProfile();
      final currentUser = ref.read(authProvider).user;
      if (currentUser != null) {
        final updatedUser = currentUser.copyWith(
          bloodGroup: _selectedBloodGroup ?? currentUser.bloodGroup,
          primaryPhone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : currentUser.primaryPhone,
          isProfileComplete: true,
          missingFields: const [],
          categoryDetails: {
            ...currentUser.categoryDetails,
            if (_districtCtrl.text.trim().isNotEmpty) 'district': _districtCtrl.text.trim(),
            if (_addressCtrl.text.trim().isNotEmpty) 'address': _addressCtrl.text.trim(),
          },
        );
        ref.read(authProvider.notifier).updateUser(updatedUser);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('প্রোফাইল সফলভাবে সম্পূর্ণ হয়েছে! সব ফিচার এখন উন্মুক্ত।',
              style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Could not save profile: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(50),
      borderSide: const BorderSide(color: Color(0xFFE2E2E2)),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: Color(0xFFFFF0F1), shape: BoxShape.circle),
                      child: const Center(child: Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 24)),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Complete Your Registration',
                              style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2B2B2B))),
                          Text('রেজিস্ট্রেশন সম্পূর্ণ করুন',
                              style: TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: const Color(0xFFFDE8E8), borderRadius: BorderRadius.circular(10)),
                    child: Text(_errorMessage!,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
                if (_showBloodGroup) ...[
                  _label('Blood Group / রক্তের গ্রুপ *'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedBloodGroup,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFFAFAFA),
                      prefixIcon: const Icon(Icons.water_drop_rounded, color: AppColors.primary),
                      border: border,
                      enabledBorder: border,
                    ),
                    items: _kBloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                    onChanged: (val) => setState(() => _selectedBloodGroup = val),
                    validator: (v) => (v == null || v.isEmpty) ? 'Please select blood group' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                if (_showPhone) ...[
                  _label('Phone Number / ফোন নম্বর *'),
                  const SizedBox(height: 6),
                  CustomInputField(
                    controller: _phoneCtrl,
                    hint: '01XXXXXXXXX',
                    prefixIcon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Phone number is required';
                      return v.trim().length < 10 ? 'Must be at least 11 digits' : null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],
                if (_showDistrict) ...[
                  _label('District / জেলা *'),
                  const SizedBox(height: 6),
                  CustomInputField(
                    controller: _districtCtrl,
                    hint: 'e.g. Dhaka, Chittagong, Sylhet',
                    prefixIcon: Icons.location_city_rounded,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'District is required' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                _label('Address / ঠিকানা (Optional)'),
                const SizedBox(height: 6),
                CustomInputField(
                  controller: _addressCtrl,
                  hint: 'Thana, Area, House / Thana, Area',
                  prefixIcon: Icons.home_rounded,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save & Complete Registration',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333)));
}
