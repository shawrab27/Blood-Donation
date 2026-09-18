import 'package:flutter/material.dart';
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
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFFC30121))),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found. Please log in again.'));
          }
          return _buildMobileLayout(context, profile);
        },
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
          _buildTopDonors(),
          const SizedBox(height: 32),
          _buildTabs(),
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
            CircleAvatar(
              radius: 50,
              backgroundImage: profile.profilePicture != null 
                  ? NetworkImage('https://blood-donation-liard.vercel.app${profile.profilePicture}') 
                  : const NetworkImage('https://ui-avatars.com/api/?name=User&background=random') as ImageProvider,

            ),
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
          final url = Uri.parse('https://blood-donation-liard.vercel.app/api/donor_profiles/${profile.id}/certificate/');

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

  Widget _buildTopDonors() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Top Donors', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
            TextButton(onPressed: () {}, child: const Text('Global Rank >', style: TextStyle(color: Color(0xFFC30121)))),
          ],
        ),
        SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildDonorAvatar('Mark R.', '18 Bags'),
              _buildDonorAvatar('Elena T.', '16 Bags'),
              _buildDonorAvatar('David K.', '14 Bags'),
              _buildDonorAvatar('Others', 'View'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDonorAvatar(String name, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage('https://ui-avatars.com/api/?name=User&background=random'),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold)),
          Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTabs() {
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
                _buildStoriesTab(),
                const Center(child: Text('Activity Summary Content')),
                const Center(child: Text('Donation History Content')),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStoriesTab() {
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
              const CircleAvatar(radius: 16, child: Text('SJ', style: TextStyle(fontSize: 10))),
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
}
