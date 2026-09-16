import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../domain/providers/health_hub_provider.dart';

class ResourcesHubScreen extends ConsumerWidget {
  const ResourcesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emergencyContactsAsync = ref.watch(emergencyContactsProvider);

    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Resources Hub',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
            const SizedBox(height: 8),

            const Text(
              'Verified Resources & Hotlines',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Direct access to national emergency blood hotlines, blood banks, and partnered hospital networks.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
            ),
            const SizedBox(height: 20),

            // ── Section 1: Emergency Hotlines (Dynamic) ────────────────────────
            _sectionHeader('Emergency Hotlines'),
            const SizedBox(height: 12),
            emergencyContactsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (contacts) {
                if (contacts.isEmpty) {
                  return const Text('No emergency contacts available.', style: TextStyle(fontFamily: 'Inter', color: AppColors.neutral));
                }
                return Column(
                  children: contacts.map((contact) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _hotlineCard(
                        contact.name,
                        contact.phoneNumber,
                        contact.description + (contact.is24Hours ? ' (24/7)' : ''),
                        Icons.phone_in_talk_rounded,
                        AppColors.primary,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 28),

            // ── Section 2: Partnered Blood Banks ────────────────────────────
            _sectionHeader('Partnered Blood Banks & Organizations'),
            const SizedBox(height: 12),
            _bloodBankItem('Badhan Blood Bank', 'Dhaka University Zone', '2,480 Active Donors', '01700-000000'),
            const SizedBox(height: 10),
            _bloodBankItem('Sandhani Blood Bank', 'DMC Unit, Dhaka', '1,920 Active Donors', '01800-000000'),
            const SizedBox(height: 10),
            _bloodBankItem('Red Crescent Blood Center', 'Mohakhali, Dhaka', 'Central Storage Facility', '02-9880000'),
            const SizedBox(height: 28),

            // ── Section 3: Hospital Network ─────────────────────────────────
            _sectionHeader('Partnered Hospital Network'),
            const SizedBox(height: 12),
            _hospitalItem('Dhaka Medical College Hospital', 'Secretariat Road, Dhaka', 'Full ICU & Transfusion Facility'),
            const SizedBox(height: 10),
            _hospitalItem('Square Hospital', 'Panthapath, Dhaka', '24/7 Blood Bank & Screening Lab'),
            const SizedBox(height: 10),
            _hospitalItem('Chittagong Medical College Hospital', 'K B Fazlul Kader Rd, Chattogram', 'Division 1 Emergency Unit'),

            const SizedBox(height: 32),
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

  Widget _hotlineCard(String title, String number, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                Text(subtitle, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(50)),
            child: Text(number, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _bloodBankItem(String name, String location, String stats, String phone) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary)),
              const Icon(Icons.verified, color: AppColors.success, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.neutral, size: 14),
              const SizedBox(width: 4),
              Text(location, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.groups_outlined, color: AppColors.neutral, size: 14),
              const SizedBox(width: 4),
              Text(stats, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral)),
              const Spacer(),
              Text(phone, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hospitalItem(String name, String location, String facility) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_hospital_outlined, color: AppColors.tertiary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const SizedBox(height: 4),
                Text(location, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.neutral)),
                const SizedBox(height: 4),
                Text(facility, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
