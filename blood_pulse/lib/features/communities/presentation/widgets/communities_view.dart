import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../domain/providers/communities_provider.dart';
import '../../domain/models/community_models.dart';

class CommunitiesView extends ConsumerStatefulWidget {
  const CommunitiesView({super.key});

  @override
  ConsumerState<CommunitiesView> createState() => _CommunitiesViewState();
}

class _CommunitiesViewState extends ConsumerState<CommunitiesView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.neutral,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontFamily: 'Georgia', fontWeight: FontWeight.bold, fontSize: 16),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 14),
            tabs: const [
              Tab(text: 'National Community'),
              Tab(text: 'Local Community'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              _NationalCommunityTab(),
              _LocalCommunityTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NATIONAL COMMUNITY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _NationalCommunityTab extends ConsumerWidget {
  const _NationalCommunityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nationalAsync = ref.watch(nationalCommunitiesProvider);
    final medicalAsync = ref.watch(medicalPartnersProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(nationalCommunitiesProvider);
          ref.invalidate(medicalPartnersProvider);
        },
        child: ListView(
          children: [
            const SizedBox(height: 8),
            const Text(
              'National Volunteer Networks',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: nationalAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (networks) {
                  if (networks.isEmpty) {
                    return const Center(child: Text('No national networks found.'));
                  }
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: networks.length,
                    itemBuilder: (ctx, idx) {
                      final item = networks[idx];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _VolunteerNetworkCard(
                          name: item.name,
                          rating: '4.9/5', // placeholder if not in model
                          members: item.activeDonors,
                          desc: item.description,
                          color: AppColors.primary,
                          icon: Icons.diversity_3_rounded,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'Medical Partners & Blood Banks',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 12),
            medicalAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (partners) {
                if (partners.isEmpty) {
                  return const Center(child: Text('No medical partners found.'));
                }
                return Column(
                  children: partners.map((h) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MedicalPartnerCard(
                      name: h.name,
                      location: h.location,
                      availability: (h.stockStatus).map((key, value) => MapEntry(key, value.toString())),
                    ),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _VolunteerNetworkCard extends StatelessWidget {
  const _VolunteerNetworkCard({
    required this.name,
    required this.rating,
    required this.members,
    required this.desc,
    required this.color,
    required this.icon,
  });

  final String name;
  final String rating;
  final String members;
  final String desc;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    Text('$rating • $members', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral, height: 1.3)),
          ),
          const SizedBox(height: 8),
          CapsuleButton(
            label: 'View Group',
            height: 36,
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Joined $name community network!'), backgroundColor: color, behavior: SnackBarBehavior.floating),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MedicalPartnerCard extends StatelessWidget {
  const _MedicalPartnerCard({required this.name, required this.location, required this.availability});

  final String name;
  final String location;
  final Map<String, String> availability;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFFEDF4FF), borderRadius: BorderRadius.circular(50)),
                child: const Text('Verified', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(location, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
          const SizedBox(height: 12),
          if (availability.isNotEmpty) ...[
            Row(
              children: availability.entries.take(4).map((e) {
                final isUrgent = e.value == 'URGENT';
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isUrgent ? const Color(0xFFFFECEE) : const Color(0xFFFDF3F3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isUrgent ? AppColors.primary : Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Text(e.key, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        Text(e.value, style: TextStyle(fontFamily: 'Inter', fontSize: 9, fontWeight: FontWeight.bold, color: isUrgent ? AppColors.primary : AppColors.neutral)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📞 Dialing hospital desk...'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating),
                    );
                  },
                  icon: const Icon(Icons.call_outlined, size: 16, color: AppColors.primary),
                  label: const Text('Call', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () {
                    context.push('/chat');
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.tertiary),
                  label: const Text('Message', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.tertiary)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOCAL COMMUNITY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _LocalCommunityTab extends ConsumerStatefulWidget {
  const _LocalCommunityTab();

  @override
  ConsumerState<_LocalCommunityTab> createState() => _LocalCommunityTabState();
}

class _LocalCommunityTabState extends ConsumerState<_LocalCommunityTab> {
  int? _selectedDivisionId;
  int? _selectedDistrictId;
  int? _selectedUpazilaId;

  @override
  Widget build(BuildContext context) {
    final divisionsAsync = ref.watch(divisionsProvider);
    final districtsAsync = ref.watch(districtsProvider(_selectedDivisionId));
    final upazilasAsync = ref.watch(upazilasProvider(_selectedDistrictId));

    final filter = LocalClubFilter(
      divisionId: _selectedDivisionId,
      districtId: _selectedDistrictId,
      upazilaId: _selectedUpazilaId,
    );

    final localClubsAsync = ref.watch(localClubsProvider(filter));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: const Text(
                  'Local Area Guide',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/register-club'),
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                label: const Text('Apply Now', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Filters
          divisionsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (divisions) => DropdownButtonFormField<int>(
              initialValue: _selectedDivisionId,
              decoration: const InputDecoration(labelText: 'Select Division', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('All Divisions')),
                ...divisions.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedDivisionId = val;
                  _selectedDistrictId = null;
                  _selectedUpazilaId = null;
                });
              },
            ),
          ),
          const SizedBox(height: 8),

          if (_selectedDivisionId != null)
            districtsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (districts) => DropdownButtonFormField<int>(
                initialValue: _selectedDistrictId,
                decoration: const InputDecoration(labelText: 'Select District', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Districts')),
                  ...districts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedDistrictId = val;
                    _selectedUpazilaId = null;
                  });
                },
              ),
            ),
          const SizedBox(height: 8),

          if (_selectedDistrictId != null)
            upazilasAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (upazilas) => DropdownButtonFormField<int>(
                initialValue: _selectedUpazilaId,
                decoration: const InputDecoration(labelText: 'Select Upazila', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Upazilas')),
                  ...upazilas.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name))),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedUpazilaId = val;
                  });
                },
              ),
            ),
          
          const SizedBox(height: 16),
          const Text('Local Clubs & Guides', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),

          Expanded(
            child: localClubsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (clubs) {
                if (clubs.isEmpty) {
                  return const Center(child: Text('No local clubs found for this area.'));
                }
                return ListView.builder(
                  itemCount: clubs.length,
                  itemBuilder: (ctx, idx) {
                    final club = clubs[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LocalClubTile(club: club),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalClubTile extends StatelessWidget {
  const _LocalClubTile({required this.club});

  final LocalClub club;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.push('/club-profile', extra: club);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFF3DDE0),
              child: Text(club.name.substring(0, 1).toUpperCase(), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  Text('${club.upazilaName}, ${club.districtName}', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                ],
              ),
            ),
            if (club.isVerified)
              const Icon(Icons.verified, color: AppColors.tertiary, size: 20),
            IconButton(
              icon: const Icon(Icons.call_outlined, color: AppColors.primary),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}
