import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';

class ResourcesHubScreen extends StatelessWidget {
  const ResourcesHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Resources Hub',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveLayout(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: ListView(
          children: [
            const SizedBox(height: 8),

            const Text(
              'Verified Resources & Hotlines',
              style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.secondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Direct access to national emergency blood hotlines, blood banks, and partnered hospital networks.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.neutral),
            ),
            const SizedBox(height: 20),

            // ── Section 1: Emergency Hotlines ──────────────────────────────
            _sectionHeader('Emergency Hotlines'),
            const SizedBox(height: 12),
            _hotlineCard('National Emergency Service', '999', '24/7 Police, Ambulance, Blood Emergency', Icons.phone_in_talk_rounded, AppColors.primary),
            const SizedBox(height: 10),
            _hotlineCard('National Health Line', '16263', 'DGHS Health Call Center & Medical Assistance', Icons.medical_services_rounded, AppColors.tertiary),
            const SizedBox(height: 10),
            _hotlineCard('BloodPulse Emergency Helpline', '+880 9612-000999', 'Instant P2P Donor Dispatch Desk', Icons.headset_mic_rounded, const Color(0xFF1B8A4E)),
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
                Text(title, style: const TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(50)),
            child: Text(number, style: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.bloodtype_rounded, color: AppColors.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                Text('$location • $stats', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: AppColors.primary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _hospitalItem(String name, String address, String facility) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD0E4FF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_hospital_rounded, color: AppColors.tertiary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                Text('$address\n$facility', style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: AppColors.neutral, height: 1.3)),
              ],
            ),
          ),
          const Icon(Icons.location_on_outlined, color: AppColors.tertiary),
        ],
      ),
    );
  }
}
