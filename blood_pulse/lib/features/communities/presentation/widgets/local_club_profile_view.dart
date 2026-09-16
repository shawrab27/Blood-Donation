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
        subtitle: club.name,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover & Profile Area
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    color: const Color(0xFFF3DDE0),
                    child: club.coverPhotoUrl != null 
                        ? Image.network(club.coverPhotoUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.groups_rounded, size: 64, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    club.name,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.secondary),
                  ),
                  if (club.isVerified) ...[
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified, color: AppColors.tertiary, size: 16),
                        SizedBox(width: 4),
                        Text('Verified Official Club', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.tertiary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '${club.upazilaName}, ${club.districtName}, ${club.divisionName}',
                    style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.neutral),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Stats row
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatBox(label: 'Total Donors', value: club.totalDonors),
                  _StatBox(label: 'Active Donors', value: club.activeDonors),
                  _StatBox(label: 'Contributions', value: club.contributions),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Details
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('About Club', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  const SizedBox(height: 8),
                  Text(club.description, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.neutral, height: 1.5)),
                  const SizedBox(height: 24),
                  
                  const Text('Executive Committee', style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                  const SizedBox(height: 12),
                  
                  // President First
                  _ECMemberTile(
                    name: club.presidentName,
                    designation: 'President',
                    phone: club.contactNumber,
                  ),
                  
                  ...club.executiveMembers.map((ec) => Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: _ECMemberTile(
                      name: ec.name,
                      designation: ec.designation,
                      phone: ec.phoneNumber,
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

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
      ],
    );
  }
}

class _ECMemberTile extends StatelessWidget {
  const _ECMemberTile({required this.name, required this.designation, required this.phone});
  
  final String name;
  final String designation;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.primary)),
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
          )
        ],
      ),
    );
  }
}
