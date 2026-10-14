// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../services/api_client.dart';
import '../../domain/providers/profile_provider.dart';

/// Sanitized Public Profile Screen for other donors (/profile/:id).
/// Enforces zero leak of sensitive PII:
/// - Never shows phone, email, nid_hash, weight, or exact GPS coordinates.
/// - Redirects to own profile (/profile) if user views their own id.
class PublicDonorProfileScreen extends ConsumerStatefulWidget {
  final int donorId;

  const PublicDonorProfileScreen({super.key, required this.donorId});

  @override
  ConsumerState<PublicDonorProfileScreen> createState() => _PublicDonorProfileScreenState();
}

class _PublicDonorProfileScreenState extends ConsumerState<PublicDonorProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPublicProfile();
  }

  Future<void> _fetchPublicProfile() async {
    final currentProfileId = ref.read(profileProvider).value?.id;
    if (currentProfileId != null && currentProfileId == widget.donorId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/profile');
      });
      return;
    }

    try {
      final res = await ApiClient().get('profile/${widget.donorId}/');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      } else if (res.statusCode == 404) {
        setState(() {
          _errorMessage = 'Donor profile not found or profile has been kept private.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Could not load donor profile.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: const CustomAppBar(
        title: 'Donor Profile',
        showLogo: false,
        showBackButton: true,
        showNotification: false,
        showProfile: false,
      ),
      body: _isLoading
          ? const Center(child: AppLoader())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_off_outlined, size: 48, color: Color(0xFFBA1A1A)),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: Color(0xFF5F5E5E)),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () => context.pop(),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    final data = _profileData!;
    final name = (data['name'] ?? 'Donor Hero').toString();
    final photo = data['photo']?.toString();
    final bio = (data['bio'] ?? '').toString();
    final bloodGroup = (data['blood_group'] ?? 'O+').toString();
    final tier = (data['tier'] ?? 'Active Donor').toString();
    final rank = (data['rank'] as num?)?.toInt() ?? 0;
    final bags = (data['bags'] as num?)?.toInt() ?? (data['verified_bags'] as num?)?.toInt() ?? 0;
    final ratingAvg = (data['rating_avg'] as num?)?.toDouble() ?? 5.0;
    final ratingCount = (data['rating_count'] as num?)?.toInt() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero Card ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF0E5E5)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Avatar with Blood Group & Rank
                    Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFFC30121),
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFFFFF0F1),
                            backgroundImage: photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                            child: photo == null || photo.isEmpty
                                ? Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'D',
                                    style: const TextStyle(
                                      fontFamily: 'Georgia',
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC30121),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        // Blood group pill at bottom
                        Positioned(
                          bottom: -8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC30121),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Text(
                              bloodGroup,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        // Rank pill at top right
                        if (rank > 0)
                          Positioned(
                            top: -2,
                            right: -6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC30121),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Text(
                                '#$rank',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF24191A),
                      ),
                    ),
                    const SizedBox(height: 4),

                    Text(
                      tier,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC30121),
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (bio.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '"$bio"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF5F5E5E),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Key Metrics (2 Cards) ──
              Row(
                children: [
                  // Bags Donated
                  Expanded(
                    child: Container(
                      height: 110,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF0E5E5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$bags',
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC30121),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Bags Donated',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                          ),
                          const Text(
                            'donations completed',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF5F5E5E)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Rating
                  Expanded(
                    child: Container(
                      height: 110,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF0E5E5)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ratingAvg.toStringAsFixed(1),
                                style: const TextStyle(fontFamily: 'Georgia', fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.star_rounded, size: 22, color: Color(0xFFFFD700)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Donor Rating',
                            style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                          ),
                          Text(
                            ratingCount > 0 ? '$ratingCount reviews' : 'New verified donor',
                            style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF5F5E5E)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Privacy & Trust Disclosure ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.verified_user_rounded, size: 20, color: Color(0xFF16A34A)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Verified Clinical Member • Transfusion Safety Guarded',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
