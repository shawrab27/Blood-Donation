import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../../../core/widgets/custom_input_field.dart';
import '../../../../core/widgets/responsive_layout.dart';

/// Communities & Hub — 3-Segment Discovery View with Independent Search Filters.
class CommunitiesView extends StatefulWidget {
  const CommunitiesView({super.key});

  @override
  State<CommunitiesView> createState() => _CommunitiesViewState();
}

class _CommunitiesViewState extends State<CommunitiesView> {
  final _networkSearchCtrl = TextEditingController();
  final _hospitalSearchCtrl = TextEditingController();
  final _guideSearchCtrl = TextEditingController();

  String _networkQuery = '';
  String _hospitalQuery = '';
  String _guideQuery = '';

  final List<Map<String, dynamic>> _networks = [
    {
      'name': 'Badhan',
      'rating': '4.9/5',
      'members': '1.2M Members',
      'desc': 'A voluntary blood donors\' organization across Bangladesh universities.',
      'color': AppColors.primary,
      'icon': Icons.diversity_3_rounded,
    },
    {
      'name': 'Sandhani',
      'rating': '4.8/5',
      'members': '850k Members',
      'desc': 'Serving humanity through blood donation in medical college units.',
      'color': AppColors.tertiary,
      'icon': Icons.volunteer_activism_rounded,
    },
    {
      'name': 'Ashar Alo',
      'rating': '4.7/5',
      'members': '420k Members',
      'desc': 'Illuminating lives in remote rural areas with emergency blood dispatch.',
      'color': const Color(0xFFE65100),
      'icon': Icons.lightbulb_rounded,
    },
  ];

  final List<Map<String, dynamic>> _hospitals = [
    {
      'name': 'Evercare Blood Center',
      'location': 'Bashundhara, Dhaka',
      'availability': {'A+': 'High', 'O-': 'URGENT', 'B+': 'Med', 'AB+': 'Low'},
    },
    {
      'name': 'Dhaka Medical College Transfusion Unit',
      'location': 'Secretariat Road, Dhaka',
      'availability': {'O+': 'High', 'A-': 'URGENT', 'B-': 'URGENT', 'AB-': 'Low'},
    },
    {
      'name': 'Chittagong Medical College Blood Bank',
      'location': 'KB Fazlul Kader Rd, Chattogram',
      'availability': {'AB+': 'High', 'O+': 'High', 'A+': 'Med', 'B-': 'URGENT'},
    },
  ];

  final List<Map<String, String>> _guides = [
    {'name': 'Dr. Rahman Kabir', 'area': 'Uttara, Dhaka', 'phone': '01711-000111'},
    {'name': 'Tanvir Hossain', 'area': 'Dhanmondi, Dhaka', 'phone': '01811-000222'},
    {'name': 'Nusrat Jahan', 'area': 'Agrabad, Chattogram', 'phone': '01911-000333'},
    {'name': 'Alim Uddin', 'area': 'Kazipara, Mirpur, Dhaka', 'phone': '01611-000444'},
  ];

  @override
  void dispose() {
    _networkSearchCtrl.dispose();
    _hospitalSearchCtrl.dispose();
    _guideSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredNetworks = _networks
        .where((n) => (n['name'] as String).toLowerCase().contains(_networkQuery.toLowerCase()))
        .toList();

    final filteredHospitals = _hospitals
        .where((h) =>
            (h['name'] as String).toLowerCase().contains(_hospitalQuery.toLowerCase()) ||
            (h['location'] as String).toLowerCase().contains(_hospitalQuery.toLowerCase()))
        .toList();

    final filteredGuides = _guides
        .where((g) =>
            g['name']!.toLowerCase().contains(_guideQuery.toLowerCase()) ||
            g['area']!.toLowerCase().contains(_guideQuery.toLowerCase()))
        .toList();

    return ResponsiveLayout(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ListView(
        children: [
          const SizedBox(height: 8),

          // ── Segment 1: Volunteer Networks with Independent Search ─────────
          _sectionHeader('1. Volunteer Networks'),
          const SizedBox(height: 8),
          CustomInputField(
            controller: _networkSearchCtrl,
            hint: 'Search volunteer networks...',
            prefixIcon: Icons.search_rounded,
            onChanged: (v) => setState(() => _networkQuery = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: filteredNetworks.isEmpty
                ? const Center(child: Text('No volunteer networks match search.', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filteredNetworks.length,
                    itemBuilder: (ctx, idx) {
                      final item = filteredNetworks[idx];
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _VolunteerNetworkCard(
                          name: item['name'] as String,
                          rating: item['rating'] as String,
                          members: item['members'] as String,
                          desc: item['desc'] as String,
                          color: item['color'] as Color,
                          icon: item['icon'] as IconData,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 28),

          // ── Segment 2: Hospital Partners & Blood Banks with Independent Search ─
          _sectionHeader('2. Medical Partners & Blood Banks'),
          const SizedBox(height: 8),
          CustomInputField(
            controller: _hospitalSearchCtrl,
            hint: 'Search hospitals or blood banks...',
            prefixIcon: Icons.local_hospital_outlined,
            onChanged: (v) => setState(() => _hospitalQuery = v),
          ),
          const SizedBox(height: 12),
          if (filteredHospitals.isEmpty)
            const Center(child: Text('No hospital partners match search.', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)))
          else
            ...filteredHospitals.map(
              (h) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MedicalPartnerCard(
                  name: h['name'] as String,
                  location: h['location'] as String,
                  availability: Map<String, String>.from(h['availability'] as Map),
                ),
              ),
            ),
          const SizedBox(height: 28),

          // ── Segment 3: Local Area Guides with Independent Search ───────────
          _sectionHeader('3. Personal Contacts & Local Guides'),
          const SizedBox(height: 8),
          CustomInputField(
            controller: _guideSearchCtrl,
            hint: 'Search guides by name or location...',
            prefixIcon: Icons.person_search_outlined,
            onChanged: (v) => setState(() => _guideQuery = v),
          ),
          const SizedBox(height: 12),
          if (filteredGuides.isEmpty)
            const Center(child: Text('No local guides match search.', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral)))
          else
            ...filteredGuides.map(
              (g) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LocalGuideTile(
                  name: g['name']!,
                  area: g['area']!,
                  phone: g['phone']!,
                ),
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.secondary,
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

          Row(
            children: availability.entries.map((e) {
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

class _LocalGuideTile extends StatelessWidget {
  const _LocalGuideTile({required this.name, required this.area, required this.phone});

  final String name;
  final String area;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                Text(area, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('📞 Calling local guide $name ($phone)...'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.tertiary),
            onPressed: () {
              context.push('/chat');
            },
          ),
        ],
      ),
    );
  }
}
