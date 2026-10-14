// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/widgets/avatar_helper.dart';
import '../../domain/providers/profile_provider.dart';

/// Screen for editing personal profile details.
/// Includes bio (max 120 chars), confidential weight (kg),
/// ranking opt-in/opt-out toggle, and link to Blood Group Change request.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _weightController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _showInRankings = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(profileProvider).value;
      if (profile != null) {
        _firstNameController.text = profile.firstName ?? '';
        _lastNameController.text = profile.lastName ?? '';
        _bioController.text = profile.bio ?? '';
        _weightController.text = profile.weightKg != null ? profile.weightKg.toString() : '';
        _phoneController.text = profile.phoneNumber ?? '';
        _emailController.text = profile.email ?? '';
        _showInRankings = profile.showInRankings;
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _bioController.dispose();
    _weightController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final Map<String, dynamic> payload = {
      'first_name': _firstNameController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'bio': _bioController.text.trim(),
      'phone_number': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'show_in_rankings': _showInRankings,
    };

    final weightText = _weightController.text.trim();
    if (weightText.isNotEmpty) {
      final parsedWeight = int.tryParse(weightText);
      if (parsedWeight != null && parsedWeight >= 30 && parsedWeight <= 250) {
        payload['weight_kg'] = parsedWeight;
      }
    }

    final success = await ref.read(profileProvider.notifier).updateProfile(payload);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Profile updated successfully!'),
          backgroundColor: Color(0xFF1B8A4E),
        ),
      );
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update profile. Please check connection.'),
          backgroundColor: Color(0xFFBA1A1A),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: const CustomAppBar(
        subtitle: 'Edit Profile',
        showLogo: true,
        showBackButton: true,
        showNotification: false,
        showProfile: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Avatar ──
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        AvatarHelper(
                          radius: 52,
                          fallbackName: profile?.fullName ?? 'User',
                          serverPhotoUrl: profile?.profilePicture != null
                              ? '${ApiConfig.baseUrl}${profile!.profilePicture}'
                              : null,
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFC30121),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField('First Name', _firstNameController),
                  const SizedBox(height: 14),
                  _buildTextField('Last Name', _lastNameController),
                  const SizedBox(height: 14),

                  // Bio with character counter (max 120)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Bio',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E), fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_bioController.text.length} / 120',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: _bioController.text.length > 120 ? const Color(0xFFBA1A1A) : const Color(0xFF8C8A8A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _bioController,
                        maxLines: 2,
                        maxLength: 120,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'Short bio or donor motto (max 120 chars)',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2D6D6))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE2D6D6))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFC30121))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Confidential Weight Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text(
                            'Weight (kg)',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E), fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.shield_outlined, size: 13, color: Color(0xFF0D68AA)),
                          SizedBox(width: 2),
                          Text(
                            'Private Clinical Data',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF0D68AA), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5),
                        decoration: InputDecoration(
                          hintText: 'e.g. 65 (used only for donation eligibility)',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: Color(0xFFE2D6D6))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: Color(0xFFE2D6D6))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: Color(0xFFC30121))),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  _buildTextField('Phone Number', _phoneController),
                  const SizedBox(height: 14),
                  _buildTextField('Email Address', _emailController),
                  const SizedBox(height: 20),

                  // Show in rankings toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF0E5E5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.leaderboard_outlined, size: 22, color: Color(0xFFC30121)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Show in Top Donors & Global Rank',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'If turned off, you are hidden from public rankings but can still see your rank privately.',
                                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF5F5E5E)),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _showInRankings,
                          activeColor: const Color(0xFFC30121),
                          onChanged: (val) => setState(() => _showInRankings = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Locked Blood Group & Change Request Button
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.lock_rounded, size: 16, color: Color(0xFFD97706)),
                                const SizedBox(width: 6),
                                Text(
                                  'Current Blood Group: ${profile?.bloodGroup ?? "O+"}',
                                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDE8E8),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Text('Clinical Lock', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC30121))),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'For recipient and donor safety, blood group changes require verified laboratory documentation reviewed by administrators.',
                          style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF92400E)),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 38,
                          child: OutlinedButton.icon(
                            onPressed: () => context.push('/blood-group-change'),
                            icon: const Icon(Icons.biotech_rounded, size: 16, color: Color(0xFFC30121)),
                            label: const Text('Request Blood Group Change'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFC30121), width: 1.5),
                              foregroundColor: const Color(0xFFC30121),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                              textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Save Button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC30121),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(height: 22, width: 22, child: AppLoader())
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E), fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: Color(0xFFE2D6D6))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: Color(0xFFE2D6D6))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(50), borderSide: const BorderSide(color: Color(0xFFC30121))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }
}
