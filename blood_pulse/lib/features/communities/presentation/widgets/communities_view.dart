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

class _CommunitiesViewState extends ConsumerState<CommunitiesView> {
  int _selectedTab = 0; // 0 = National, 1 = Local
  int _nationalSubFilter = 0; // 0 = Organizations, 1 = Medical Partners
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Title & Subtitle ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Communities',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedTab == 0
                      ? 'Connect with national blood donation organizations.'
                      : 'Find donors and drives in your area.',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Top Segmented Pill Toggle: [National] [Local] ─────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8E8),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: _selectedTab == 0
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withAlpha(50),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'National',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _selectedTab == 0 ? Colors.white : AppColors.neutral,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(50),
                          boxShadow: _selectedTab == 1
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withAlpha(50),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Local',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _selectedTab == 1 ? Colors.white : AppColors.neutral,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Tab Body with smooth animated switcher ────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _selectedTab == 0
                  ? _NationalTabContent(
                      subFilter: _nationalSubFilter,
                      onSubFilterChanged: (idx) => setState(() => _nationalSubFilter = idx),
                    )
                  : const _LocalTabContent(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 1: NATIONAL COMMUNITIES & MEDICAL PARTNERS
// ─────────────────────────────────────────────────────────────────────────────

class _NationalTabContent extends ConsumerStatefulWidget {
  const _NationalTabContent({
    required this.subFilter,
    required this.onSubFilterChanged,
  });

  final int subFilter;
  final ValueChanged<int> onSubFilterChanged;

  @override
  ConsumerState<_NationalTabContent> createState() => _NationalTabContentState();
}

class _NationalTabContentState extends ConsumerState<_NationalTabContent> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final nationalAsync = ref.watch(nationalCommunitiesProvider);
    final medicalAsync = ref.watch(medicalPartnersProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(nationalCommunitiesProvider);
        ref.invalidate(medicalPartnersProvider);
      },
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Sub-filter pill buttons: [Organizations] [Medical Partners]
          Row(
            children: [
              _SubFilterChip(
                label: 'Organizations',
                isSelected: widget.subFilter == 0,
                onTap: () => widget.onSubFilterChanged(0),
              ),
              const SizedBox(width: 8),
              _SubFilterChip(
                label: 'Medical Partners',
                isSelected: widget.subFilter == 1,
                onTap: () => widget.onSubFilterChanged(1),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Field: 🔍 Search national networks...
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search national networks...',
                hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.neutral, size: 20),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Organizations View
          if (widget.subFilter == 0) ...[
            nationalAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => Center(child: Text('Error loading networks: $err')),
              data: (networks) {
                final filtered = networks.where((n) {
                  return n.name.toLowerCase().contains(_searchQuery) ||
                      n.description.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No national organizations found.', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)),
                    ),
                  );
                }

                return Column(
                  children: filtered.asMap().entries.map((entry) {
                    return _NationalOrgCard(org: entry.value, index: entry.key);
                  }).toList(),
                );
              },
            ),
          ],

          // Medical Partners View or Bottom Section
          if (widget.subFilter == 1 || widget.subFilter == 0) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Medical Partners',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'View All',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.tertiary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            medicalAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => Center(child: Text('Error loading partners: $err')),
              data: (partners) {
                return Column(
                  children: partners.map((p) => _MedicalPartnerCard(partner: p)).toList(),
                );
              },
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SubFilterChip extends StatelessWidget {
  const _SubFilterChip({required this.label, required this.isSelected, required this.onTap});
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF680010) : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: isSelected ? const Color(0xFF680010) : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.secondary,
          ),
        ),
      ),
    );
  }
}

class _NationalOrgCard extends StatelessWidget {
  const _NationalOrgCard({required this.org, required this.index});
  final NationalCommunity org;
  final int index;

  static const List<IconData> _orgIcons = [
    Icons.water_drop_rounded,
    Icons.health_and_safety_rounded,
    Icons.favorite_rounded,
    Icons.medical_services_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final icon = _orgIcons[index % _orgIcons.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Logo/Icon + Name + Member Badge
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE8E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  org.name,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8E9),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  org.activeDonors,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            org.description,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.neutral,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),

          // Details Button (Outlined Capsule)
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF8B0014), width: 1.5),
                shape: const StadiumBorder(),
              ),
              onPressed: () {
                _showDetailsBottomSheet(context, org);
              },
              child: const Text(
                'Details',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF8B0014),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailsBottomSheet(BuildContext context, NationalCommunity org) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    org.name,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFFDE8E9), borderRadius: BorderRadius.circular(50)),
                  child: Text(org.activeDonors, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(org.description, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.neutral, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: CapsuleButton(
                label: 'Connect with Organization',
                onPressed: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Connected with ${org.name}!'), backgroundColor: AppColors.primary),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalPartnerCard extends StatelessWidget {
  const _MedicalPartnerCard({required this.partner});
  final MedicalPartner partner;

  @override
  Widget build(BuildContext context) {
    final stock = partner.stockStatus;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Image
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [Colors.blueGrey.shade100, Colors.blueGrey.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: partner.imageUrl != null
                ? Image.network(partner.imageUrl!, fit: BoxFit.cover)
                : Center(
                    child: Icon(Icons.local_hospital_rounded, size: 52, color: Colors.blueGrey.shade400),
                  ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        partner.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDF4FF),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Text(
                        'Verified',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stock badges row (A+ HIGH, B+ URGENT, O- LOW, AB+ MED)
                if (stock.isNotEmpty)
                  Row(
                    children: stock.entries.take(4).map((e) {
                      final isUrgent = e.value.toString().toUpperCase() == 'URGENT';
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isUrgent ? const Color(0xFFFDE8E9) : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isUrgent ? const Color(0xFFF3B8BC) : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                e.key,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isUrgent ? AppColors.primary : AppColors.secondary,
                                ),
                              ),
                              Text(
                                e.value.toString(),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: isUrgent ? AppColors.primary : AppColors.neutral,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 14),

                // Buttons: [Call] and [Message]
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF8B0014)),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Calling Blood Center...')),
                          );
                        },
                        icon: const Icon(Icons.call_rounded, size: 16, color: Color(0xFF8B0014)),
                        label: const Text('Call', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Color(0xFF8B0014))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => context.push('/chat'),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.secondary),
                        label: const Text('Message', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.secondary)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 2: LOCAL COMMUNITIES (AREA GUIDES & 8 DIVISIONS GRID)
// ─────────────────────────────────────────────────────────────────────────────

class _LocalTabContent extends ConsumerStatefulWidget {
  const _LocalTabContent();

  @override
  ConsumerState<_LocalTabContent> createState() => _LocalTabContentState();
}

class _LocalTabContentState extends ConsumerState<_LocalTabContent> {
  int? _selectedDivisionId;
  String? _selectedDivisionName;
  int? _selectedDistrictId;
  String? _selectedDistrictName;
  int? _selectedUpazilaId;
  String? _selectedUpazilaName;

  static const List<Map<String, dynamic>> _divisionsCatalog = [
    {'name': 'Dhaka', 'icon': Icons.location_city_rounded},
    {'name': 'Chattogram', 'icon': Icons.anchor_rounded},
    {'name': 'Rajshahi', 'icon': Icons.mosque_rounded},
    {'name': 'Khulna', 'icon': Icons.forest_rounded},
    {'name': 'Barishal', 'icon': Icons.directions_boat_rounded},
    {'name': 'Sylhet', 'icon': Icons.eco_rounded},
    {'name': 'Rangpur', 'icon': Icons.agriculture_rounded},
    {'name': 'Mymensingh', 'icon': Icons.set_meal_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final divisionsAsync = ref.watch(divisionsProvider);
    final districtsAsync = ref.watch(districtsProvider(_selectedDivisionId));
    final upazilasAsync = ref.watch(upazilasProvider(_selectedDistrictId));
    final guidesAsync = ref.watch(areaGuidesProvider);

    return ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Search Input: 🔍 Search by division, district, or upazila...
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'Search by division, district, or upazila...',
              hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.neutral, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Stepper: ❶ Division > ❷ District > ❸ Upazila
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepBadge(number: '1', label: 'Division', isActive: true),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.neutral),
              const SizedBox(width: 8),
              _StepBadge(number: '2', label: 'District', isActive: _selectedDivisionId != null),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.neutral),
              const SizedBox(width: 8),
              _StepBadge(number: '3', label: 'Upazila', isActive: _selectedUpazilaId != null),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Dropdown selection row (All Divisions, Select District, Select Upazila)
        Row(
          children: [
            Expanded(
              child: divisionsAsync.when(
                loading: () => const _LoadingPill(),
                error: (err, _) => const SizedBox.shrink(),
                data: (divisions) => _DropdownPill<int?>(
                  label: _selectedDivisionName ?? 'All Divisions',
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Divisions', style: TextStyle(fontFamily: 'Inter', fontSize: 12))),
                    ...divisions.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 12)))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedDivisionId = val;
                      _selectedDivisionName = val != null ? divisions.firstWhere((d) => d.id == val).name : null;
                      _selectedDistrictId = null;
                      _selectedUpazilaId = null;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: districtsAsync.when(
                loading: () => const _LoadingPill(),
                error: (err, _) => const SizedBox.shrink(),
                data: (districts) => _DropdownPill<int?>(
                  label: _selectedDistrictName ?? 'Select District',
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Districts', style: TextStyle(fontFamily: 'Inter', fontSize: 12))),
                    ...districts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 12)))),
                  ],
                  onChanged: (val) => setState(() {
                    _selectedDistrictId = val;
                    _selectedDistrictName = val != null ? districts.firstWhere((d) => d.id == val).name : null;
                    _selectedUpazilaId = null;
                    _selectedUpazilaName = null;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: upazilasAsync.when(
                loading: () => const _LoadingPill(),
                error: (err, _) => const SizedBox.shrink(),
                data: (upazilas) => _DropdownPill<int?>(
                  label: _selectedUpazilaName ?? 'Select Upazila',
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Upazilas', style: TextStyle(fontFamily: 'Inter', fontSize: 12))),
                    ...upazilas.map((u) => DropdownMenuItem(value: u.id, child: Text(u.name, style: const TextStyle(fontFamily: 'Inter', fontSize: 12)))),
                  ],
                  onChanged: (val) => setState(() {
                    _selectedUpazilaId = val;
                    _selectedUpazilaName = val != null ? upazilas.firstWhere((u) => u.id == val).name : null;
                  }),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── 8 Divisions Grid (2 Columns x 4 Rows) ────────────────────────────
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.7,
          ),
          itemCount: _divisionsCatalog.length,
          itemBuilder: (ctx, idx) {
            final div = _divisionsCatalog[idx];
            return _DivisionGridCard(
              name: div['name'] as String,
              icon: div['icon'] as IconData,
              onTap: () {
                // Navigate to Division Detail Screen (Screen 3)
                context.push('/division-view', extra: {
                  'name': div['name'],
                  'id': idx + 1, // approximate id matching DB
                });
              },
            );
          },
        ),
        const SizedBox(height: 24),

        // ── Local Area Guides Section ────────────────────────────────────────
        const Text(
          'Local Area Guides',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 8),

        // Search guides bar: 🔍 Search guides by name or area...
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const TextField(
            decoration: InputDecoration(
              hintText: 'Search guides by name or area...',
              hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
              prefixIcon: Icon(Icons.search_rounded, color: AppColors.neutral, size: 20),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Guide Card: Dr. Rahman Kabir
        guidesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, _) => const SizedBox.shrink(),
          data: (guides) {
            return Column(
              children: guides.map((guide) => _GuideCard(guide: guide)).toList(),
            );
          },
        ),
        const SizedBox(height: 12),

        // "Become a Guide" Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFDF3F3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3D2D5)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFFDE8E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Become a Guide',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                    Text(
                      'Support your local community',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.neutral,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B0014),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Guide application submitted for review!'), backgroundColor: AppColors.primary),
                  );
                },
                child: const Text('Apply Now', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number, required this.label, required this.isActive});
  final String number;
  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppColors.secondary : AppColors.neutral,
          ),
        ),
      ],
    );
  }
}

class _DropdownPill<T> extends StatelessWidget {
  const _DropdownPill({required this.label, required this.items, required this.onChanged});
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          hint: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.secondary, fontWeight: FontWeight.w600),
          ),
          items: items,
          onChanged: onChanged,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.neutral),
        ),
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(50)),
      child: const Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))),
    );
  }
}

class _DivisionGridCard extends StatelessWidget {
  const _DivisionGridCard({required this.name, required this.icon, required this.onTap});
  final String name;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFDE8E9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide});
  final AreaGuide guide;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFF3DDE0),
            child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  guide.areaName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.primary, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Calling ${guide.name} (${guide.phone})...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.tertiary, size: 20),
            onPressed: () => context.push('/chat'),
          ),
        ],
      ),
    );
  }
}
