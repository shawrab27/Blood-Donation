import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/blood_pulse_app_bar.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        subtitle: 'Admin Operations',
        showBackButton: true,
        onBack: () => context.go('/dashboard'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Harassment Filter Panel',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Review flagged users and enforce trust & safety compliance.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.neutral,
                ),
              ),
              const SizedBox(height: 20),

              // Queue Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Pending Verifications',
                      count: '142',
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      title: 'Flagged Users',
                      count: '12',
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Action Queue',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/admin-dashboard'),
                    icon: const Icon(Icons.dashboard_outlined, size: 16, color: AppColors.tertiary),
                    label: const Text(
                      'Dashboard',
                      style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold, color: AppColors.tertiary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildFlaggedUserCard(
                context,
                name: 'User 9912',
                reason: 'Spamming requests (5 in 1 hr)',
                date: 'Just now',
              ),
              const SizedBox(height: 10),
              _buildFlaggedUserCard(
                context,
                name: 'User 3041',
                reason: 'Inappropriate language in request',
                date: '2 hrs ago',
              ),
              const SizedBox(height: 10),
              _buildFlaggedUserCard(
                context,
                name: 'User 8812',
                reason: 'Failed NID verification repeatedly',
                date: '5 hrs ago',
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required String count, required Color color}) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              count,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlaggedUserCard(BuildContext context, {required String name, required String reason, required String date}) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.tertiary.withAlpha(30),
              child: const Icon(Icons.person, color: AppColors.tertiary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    reason,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.neutral,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.block_rounded, color: AppColors.primary),
              tooltip: 'Block User',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Action recorded for $name', style: const TextStyle(fontFamily: 'Inter')),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
