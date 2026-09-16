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

class _CommunitiesViewState extends ConsumerState<CommunitiesView>
    with SingleTickerProviderStateMixin {
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
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontFamily: 'Georgia',
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            unselectedLabelStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'National'),
              Tab(text: 'Local Area'),
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

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(nationalCommunitiesProvider);
        ref.invalidate(medicalPartnersProvider);
      },
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFC30121), Color(0xFF8B000E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'National Volunteer Network',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join Bangladesh\'s premier blood donation communities and save lives together.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white70, height: 1.4),
                ),
                const SizedBox(height: 16),
                nationalAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, err) => const SizedBox.shrink(),
                  data: (networks) => Text(
                    '${networks.length} national communities',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white54, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Featured Communities',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal community cards
          SizedBox(
            height: 200,
            child: nationalAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, _) => Center(child: Text('Could not load communities.\n$err', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', color: AppColors.neutral))),
              data: (networks) {
                if (networks.isEmpty) {
                  return const Center(
                    child: Text('No national communities found.', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)),
                  );
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: networks.length,
                  itemBuilder: (ctx, idx) {
                    final item = networks[idx];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _NationalCommunityCard(network: item, colorIndex: idx),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'Medical Partners & Blood Banks',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All', style: TextStyle(fontFamily: 'Inter', color: AppColors.tertiary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          medicalAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (err, _) => Center(child: Text('Could not load partners.\n$err', textAlign: TextAlign.center)),
            data: (partners) {
              if (partners.isEmpty) {
                return const Center(child: Text('No medical partners found.', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)));
              }
              return Column(
                children: partners.map((h) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _MedicalPartnerCard(partner: h),
                )).toList(),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _NationalCommunityCard extends StatelessWidget {
  const _NationalCommunityCard({required this.network, required this.colorIndex});

  final NationalCommunity network;
  final int colorIndex;

  static const List<Color> _cardColors = [
    Color(0xFFC30121),
    AppColors.tertiary,
    Color(0xFF2B2B2B),
    Color(0xFF6D4C41),
  ];

  static const List<IconData> _icons = [
    Icons.diversity_3_rounded,
    Icons.volunteer_activism_rounded,
    Icons.local_hospital_rounded,
    Icons.favorite_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _cardColors[colorIndex % _cardColors.length];
    final icon = _icons[colorIndex % _icons.length];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(network.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    Text('${network.activeDonors} members', maxLines: 1,
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(network.description, maxLines: 3, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral, height: 1.4)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: CapsuleButton(
              label: 'Join Community',
              height: 36,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Joined ${network.name}!'),
                    backgroundColor: color,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalPartnerCard extends StatelessWidget {
  const _MedicalPartnerCard({required this.partner});
  final MedicalPartner partner;

  @override
  Widget build(BuildContext context) {
    final availability = (partner.stockStatus).map((key, value) => MapEntry(key, value.toString()));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(partner.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFEDF4FF), borderRadius: BorderRadius.circular(50)),
                child: const Text('Verified', style: TextStyle(fontFamily: 'Inter', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppColors.neutral),
              const SizedBox(width: 4),
              Text(partner.location, style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral)),
            ],
          ),
          if (availability.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: availability.entries.take(4).map((e) {
                final isUrgent = e.value.toUpperCase() == 'URGENT';
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
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📞 Dialing hospital...'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating),
                    );
                  },
                  icon: const Icon(Icons.call_outlined, size: 16, color: AppColors.primary),
                  label: const Text('Call', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  onPressed: () => context.push('/chat'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.tertiary),
                  label: const Text('Message', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.tertiary, fontSize: 13)),
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
  String? _selectedDivisionName;
  int? _selectedDistrictId;
  int? _selectedUpazilaId;

  // Quick-filter: Dhaka division ID (will be resolved from the API)


  void _quickFilterDhaka(List<Division> divisions) {
    final dhaka = divisions.where((d) => d.name.toLowerCase().contains('dhaka')).toList();
    if (dhaka.isNotEmpty) {
      setState(() {
        _selectedDivisionId = dhaka.first.id;
        _selectedDivisionName = dhaka.first.name;
        _selectedDistrictId = null;
        _selectedUpazilaId = null;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedDivisionId = null;
      _selectedDivisionName = null;
      _selectedDistrictId = null;
      _selectedUpazilaId = null;
    });
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with Register CTA
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Local Clubs & Area Guide',
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    Text('Find clubs in your area or register yours',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => context.push('/register-club'),
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 18),
                label: const Text('Register Club', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 13)),
              ),
            ],
          ),
        ),

        // Quick-filter chips row
        divisionsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, err) => const SizedBox.shrink(),
          data: (divisions) => Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // All chip
                  _FilterChip(
                    label: 'All Divisions',
                    isSelected: _selectedDivisionId == null,
                    onTap: _clearFilters,
                    icon: Icons.public_rounded,
                  ),
                  const SizedBox(width: 8),
                  // Dhaka quick filter
                  _FilterChip(
                    label: 'Dhaka Division',
                    isSelected: _selectedDivisionName?.toLowerCase().contains('dhaka') == true,
                    onTap: () => _quickFilterDhaka(divisions),
                    icon: Icons.location_city_rounded,
                  ),
                  const SizedBox(width: 8),
                  // All other divisions
                  ...divisions.where((d) => !d.name.toLowerCase().contains('dhaka')).map((d) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _FilterChip(
                      label: d.name,
                      isSelected: _selectedDivisionId == d.id,
                      onTap: () {
                        setState(() {
                          _selectedDivisionId = d.id;
                          _selectedDivisionName = d.name;
                          _selectedDistrictId = null;
                          _selectedUpazilaId = null;
                        });
                      },
                    ),
                  )),
                ],
              ),
            ),
          ),
        ),

        // District & Upazila dropdowns (appear contextually)
        if (_selectedDivisionId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: districtsAsync.when(
              loading: () => const LinearProgressIndicator(color: AppColors.primary),
              error: (e, _) => Text('Error: $e'),
              data: (districts) => DropdownButtonFormField<int>(
                initialValue: _selectedDistrictId,
                decoration: InputDecoration(
                  labelText: 'Select District',
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Districts', style: TextStyle(fontFamily: 'Inter'))),
                  ...districts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontFamily: 'Inter')))),
                ],
                onChanged: (val) => setState(() {
                  _selectedDistrictId = val;
                  _selectedUpazilaId = null;
                }),
              ),
            ),
          ),

        if (_selectedDistrictId != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: upazilasAsync.when(
              loading: () => const LinearProgressIndicator(color: AppColors.primary),
              error: (e, _) => Text('Error: $e'),
              data: (upazilas) => DropdownButtonFormField<int>(
                initialValue: _selectedUpazilaId,
                decoration: InputDecoration(
                  labelText: 'Select Upazila',
                  labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Upazilas', style: TextStyle(fontFamily: 'Inter'))),
                  ...upazilas.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name, style: const TextStyle(fontFamily: 'Inter')))),
                ],
                onChanged: (val) => setState(() => _selectedUpazilaId = val),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Club list
        Expanded(
          child: localClubsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Center(child: Text('Error: $e', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter'))),
            data: (clubs) {
              if (clubs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.groups_outlined, size: 64, color: AppColors.neutral),
                      const SizedBox(height: 12),
                      const Text('No clubs found in this area.', style: TextStyle(fontFamily: 'Georgia', fontSize: 16, color: AppColors.secondary)),
                      const SizedBox(height: 4),
                      const Text('Be the first to register one!', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)),
                      const SizedBox(height: 16),
                      CapsuleButton(
                        label: 'Register Your Club',
                        height: 44,
                        onPressed: () => context.push('/register-club'),
                      ),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                itemCount: clubs.length,
                itemBuilder: (ctx, idx) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LocalClubTile(club: clubs[idx], index: idx),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.isSelected, required this.onTap, this.icon});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.neutral),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalClubTile extends StatelessWidget {
  const _LocalClubTile({required this.club, required this.index});
  final LocalClub club;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOut,
      builder: (ctx, val, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - val)),
        child: Opacity(opacity: val, child: child),
      ),
      child: InkWell(
        onTap: () => context.push('/club-profile', extra: club),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(6), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Hero(
                tag: 'club_avatar_${club.name}',
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: Color(0xFFF3DDE0), shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(club.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        ),
                        if (club.isVerified)
                          const Icon(Icons.verified_rounded, color: AppColors.tertiary, size: 18),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${club.upazilaName}, ${club.districtName}'.trim().replaceAll(RegExp(r'^,\s*'), ''),
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${club.activeDonors} active donors',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: AppColors.neutral),
            ],
          ),
        ),
      ),
    );
  }
}
