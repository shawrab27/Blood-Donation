// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:blood_pulse/core/widgets/avatar_helper.dart';
import 'package:blood_pulse/core/widgets/responsive_center_wrapper.dart';
import 'package:blood_pulse/services/api_client.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/providers/profile_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/profile_models.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7), // Surface Color
      body: ResponsiveCenterWrapper(
        child: profileState.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC30121))),
          error: (err, stack) => _buildErrorState(context, ref, err.toString()),
          data: (profile) {
            if (profile == null) {
              return _buildGuestDashboard(context);
            }
            return _buildMobileLayout(context, profile);
          },
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, ProfileModel profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        children: [
          _buildHeader(context, profile),
          const SizedBox(height: 24),
          _buildStatsRow(profile),
          const SizedBox(height: 24),
          _buildDownloadCertificateBtn(profile),
          const SizedBox(height: 32),
          _buildTabs(profile),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProfileModel profile) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AvatarHelper(radius: 50, fallbackName: profile.fullName, serverPhotoUrl: profile.profilePicture != null ? '${ApiClient.defaultBaseUrl}${profile.profilePicture}' : null),
            Positioned(
              top: 0,
              right: -10,
              child: IconButton(
                icon: const Icon(Icons.edit, color: Color(0xFFC30121)),
                onPressed: () => _openEditProfile(context, profile),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          profile.fullName,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B2B2B),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE5F1FF),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                profile.badge,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF0D68AA), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEB),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                profile.bloodGroup ?? 'Unknown',
                style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFFC30121), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (profile.bio != null && profile.bio!.isNotEmpty)
          Text(
            '"${profile.bio}"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontStyle: FontStyle.italic, color: Colors.black54),
          ),
      ],
    );
  }

  Widget _buildStatsRow(ProfileModel profile) {
    return Row(
      children: [
        Expanded(
          child: _buildStatBox('TOTAL BAGS\nDONATED', profile.totalBagsDonated.toString(), 'Bags'),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatBox('NEXT DONATION', '74d', ''),
        ),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFC30121))),
          if (unit.isNotEmpty) Text(unit, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDownloadCertificateBtn(ProfileModel profile) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          final url = Uri.parse('${ApiClient.defaultBaseUrl}/api/donor_profiles/${profile.id}/certificate/');

          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          }
        },
        icon: const Icon(Icons.download_rounded, color: Colors.white),
        label: const Text('Download Verified Digital Certificate', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC30121),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        ),
      ),
    );
  }

  Widget _buildTabs(ProfileModel profile) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            indicatorColor: Color(0xFFC30121),
            labelColor: Color(0xFFC30121),
            unselectedLabelColor: Colors.grey,
            labelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: 'Your Stories'),
              Tab(text: 'Activity Summary'),
              Tab(text: 'Donation History'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400, // Fixed height for demo; ideally use shrinkWrap or CustomScrollView
            child: TabBarView(
              children: [
                _buildStoriesTab(profile),
                const Center(child: Text('Activity Summary Content')),
                const Center(child: Text('Donation History Content')),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStoriesTab(ProfileModel profile) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
          ),
          child: Row(
            children: [
              AvatarHelper(
                radius: 16,
                fallbackName: profile.fullName,
                serverPhotoUrl: profile.profilePicture != null
                    ? '${ApiClient.defaultBaseUrl}${profile.profilePicture}'
                    : null,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Write your journey...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(icon: const Icon(Icons.send, color: Color(0xFFC30121)), onPressed: () {})
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Mock post
        Card(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Oct 15, 2023', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Just completed my 12th donation today! Always a wonderful feeling knowing you can help someone in need...',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  void _openEditProfile(BuildContext context, ProfileModel profile) {
    // Navigate to edit profile screen. Since it's a sub-route, you can use push
    context.push('/edit-profile');
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    final cleanMessage = error.contains('ApiException:')
        ? error.replaceAll('ApiException:', '').trim()
        : error;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEB),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 36,
                color: Color(0xFFC30121),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Could not load profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              cleanMessage.isEmpty
                  ? 'Unable to reach the server. Please check your internet connection or log in again.'
                  : cleanMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Color(0xFF8E7D7F),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => ref.read(profileProvider.notifier).fetchProfile(),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Retry',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC30121),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () => context.push('/login'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC30121),
                    side: const BorderSide(color: Color(0xFFC30121), width: 1.5),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  child: const Text(
                    'Log In',
                    style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestDashboard(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Guest Profile Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFC30121), width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 42,
                    backgroundColor: Color(0xFFFFF0F1),
                    child: Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: Color(0xFFC30121),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Welcome, Lifesaver',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: const Text(
                    'GUEST MODE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Color(0xFFC30121),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sign in or create your profile to manage emergency blood requests, log your donations, earn verified badges, and connect with local donors.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF8E7D7F),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.push('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC30121),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sign In to BloodPulse',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.push('/registration'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC30121),
                      side: const BorderSide(color: Color(0xFFC30121), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: const Text(
                      'Create New Account',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Features Preview Header
          Align(
            alignment: Alignment.centerLeft,
            child: const Text(
              'Why Register with BloodPulse?',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Feature Cards matching Stitch Clean Overview
          _buildFeatureCard(
            icon: Icons.bloodtype_rounded,
            iconColor: const Color(0xFFC30121),
            title: 'Emergency Blood Requests',
            subtitle: 'Post urgent patient requests with AI trust verification and automated donor alerts.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.verified_user_rounded,
            iconColor: const Color(0xFF0D68AA),
            title: 'Verified Lifesaver Badges',
            subtitle: 'Authenticate with student or national ID to earn Platinum and verified donor status.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.workspace_premium_rounded,
            iconColor: const Color(0xFFD97706),
            title: 'Official Certificates',
            subtitle: 'Generate and download verified digital certificates for every blood donation.',
          ),
          const SizedBox(height: 10),
          _buildFeatureCard(
            icon: Icons.favorite_rounded,
            iconColor: const Color(0xFF10B981),
            title: 'Donation Recovery Tracking',
            subtitle: 'Track your 90-day cooldown period and monitor your physical health readiness.',
          ),
          const SizedBox(height: 24),

          // Quick Links
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded, color: Color(0xFF0D68AA)),
                  title: const Text('Language / ভাষা', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => context.push('/language'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded, color: Color(0xFFC30121)),
                  title: const Text('Blood Donation Guidelines', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => context.push('/donation-guide'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981)),
                  title: const Text('National Emergency Contacts', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onTap: () => context.push('/emergency-contacts'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B2B2B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF8E7D7F),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
