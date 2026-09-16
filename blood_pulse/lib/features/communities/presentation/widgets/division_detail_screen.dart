import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/capsule_button.dart';
import '../../domain/models/community_models.dart';
import '../../domain/providers/communities_provider.dart';

class DivisionDetailScreen extends ConsumerWidget {
  const DivisionDetailScreen({
    super.key,
    required this.divisionName,
    this.divisionId,
  });

  final String divisionName;
  final int? divisionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = LocalClubFilter(divisionId: divisionId);
    final clubsAsync = ref.watch(localClubsProvider(filter));
    final donorsAsync = ref.watch(localDonorsProvider(divisionName));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        showBackButton: true,
        subtitle: '$divisionName Division',
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(localClubsProvider(filter));
          ref.invalidate(localDonorsProvider(divisionName));
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ── Section 1: Local Blood Clubs ─────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Local Blood Clubs',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/register-club'),
                  child: const Text(
                    '+ Register Club',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            clubsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => Center(
                child: Text('Error loading clubs: $err'),
              ),
              data: (clubs) {
                if (clubs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'No registered clubs found in this division.',
                        style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral),
                      ),
                    ),
                  );
                }
                return Column(
                  children: clubs.map((club) => _ClubCardItem(club: club)).toList(),
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Section 2: Local Donors in Division ────────────────────────────
            Text(
              'Local Donors in $divisionName',
              style: const TextStyle(
                fontFamily: 'Georgia',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 12),

            donorsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (donors) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                    children: donors.asMap().entries.map((entry) {
                      final isLast = entry.key == donors.length - 1;
                      final donor = entry.value;
                      return Column(
                        children: [
                          _DonorListItem(donor: donor),
                          if (!isLast)
                            Divider(height: 1, indent: 64, color: Colors.grey.shade100),
                        ],
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Section 3: CTA Banner ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF0F0),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF3D2D5)),
              ),
              child: Column(
                children: [
                  Text(
                    'Join 1.2k+ heroes in $divisionName. Register as a verified donor to save lives.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CapsuleButton(
                      label: 'Become a Local Donor',
                      icon: Icons.water_drop_rounded,
                      onPressed: () => context.push('/register'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ClubCardItem extends StatelessWidget {
  const _ClubCardItem({required this.club});
  final LocalClub club;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club.name,
                  style: const TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: club.isVerified
                        ? const Color(0xFFEDF4FF)
                        : const Color(0xFFEDF8EE),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    club.isVerified ? 'Verified' : 'Active',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: club.isVerified ? AppColors.tertiary : Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/club-profile', extra: club),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View Club',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DonorListItem extends StatelessWidget {
  const _DonorListItem({required this.donor});
  final LocalDonorItem donor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFF3DDE0),
            child: Text(
              donor.name.isNotEmpty ? donor.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  donor.name,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                Text(
                  'Last donation: ${donor.lastDonationDate}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.neutral,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFF2C2C6)),
            ),
            child: Text(
              donor.bloodGroup,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
