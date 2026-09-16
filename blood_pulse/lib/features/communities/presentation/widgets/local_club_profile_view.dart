import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../domain/models/community_models.dart';

class LocalClubProfileView extends StatelessWidget {
  const LocalClubProfileView({super.key, required this.club});
  final LocalClub club;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        showBackButton: true,
        showLogo: false,
        subtitle: club.name,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover + Avatar ──────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Cover photo
                Container(
                  height: 160,
                  width: double.infinity,
                  color: const Color(0xFFF3DDE0),
                  child: club.coverPhotoUrl != null && club.coverPhotoUrl!.isNotEmpty
                      ? Image.network(club.coverPhotoUrl!, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFC30121), Color(0xFFE53935)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.groups_rounded, size: 64, color: Colors.white30),
                          ),
                        ),
                ),
                // Hero Avatar overlapping
                Positioned(
                  bottom: -40,
                  left: 24,
                  child: Hero(
                    tag: 'club_avatar_${club.name}',
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFF3DDE0),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 10),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 28, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 52),

            // ── Club Name + Verified ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club.name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: AppColors.neutral),
                      const SizedBox(width: 4),
                      Text(
                    [club.upazilaName, club.districtName, club.divisionName]
                        .where((e) => e.isNotEmpty)
                        .join(', '),
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
                      ),
                    ],
                  ),
                  if (club.isVerified) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFEDF4FF), borderRadius: BorderRadius.circular(50)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, color: AppColors.tertiary, size: 14),
                          SizedBox(width: 4),
                          Text('Verified Official Club', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.tertiary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                  if (club.slogan.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${club.slogan}"',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral, fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Stats Row ──────────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AnimatedStatBox(label: 'Total Donors', value: club.totalDonors),
                  _Divider(),
                  _AnimatedStatBox(label: 'Active Donors', value: club.activeDonors),
                  _Divider(),
                  _AnimatedStatBox(label: 'Contributions', value: club.contributions),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── About ──────────────────────────────────────────────────
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('About Club', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  const SizedBox(height: 8),
                  Text(
                    club.description,
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.neutral, height: 1.6),
                  ),
                  if (club.establishedYear != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.neutral),
                        const SizedBox(width: 6),
                        Text('Established ${club.establishedYear}', style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Executive Committee ────────────────────────────────────
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Executive Committee', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  const SizedBox(height: 14),

                  // President card (highlighted)
                  _PresidentCard(
                    name: club.presidentName,
                    phone: club.contactNumber,
                  ),
                  const SizedBox(height: 10),

                  ...club.executiveMembers.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ECMemberTile(
                      name: entry.value.name,
                      designation: entry.value.designation,
                      phone: entry.value.phoneNumber,
                      index: entry.key,
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, color: Colors.grey.shade200);
  }
}

class _AnimatedStatBox extends StatelessWidget {
  const _AnimatedStatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (ctx, val, child) => Opacity(opacity: val, child: child),
          child: Text(value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
      ],
    );
  }
}

class _PresidentCard extends StatelessWidget {
  const _PresidentCard({required this.name, required this.phone});
  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFF0F0), Color(0xFFFDF3F3)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8B4B8)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: Color(0xFFC30121), shape: BoxShape.circle),
            child: Center(
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const Text('President', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppColors.primary, size: 22),
            onPressed: () {},
            tooltip: 'Call President',
          ),
        ],
      ),
    );
  }
}

class _ECMemberTile extends StatelessWidget {
  const _ECMemberTile({required this.name, required this.designation, required this.phone, required this.index});
  final String name;
  final String designation;
  final String phone;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 80)),
      curve: Curves.easeOut,
      builder: (ctx, val, child) => Transform.translate(
        offset: Offset(20 * (1 - val), 0),
        child: Opacity(opacity: val, child: child),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFF3DDE0),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  Text(designation, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 20),
              onPressed: () {},
              tooltip: 'Call $name',
            ),
          ],
        ),
      ),
    );
  }
}
