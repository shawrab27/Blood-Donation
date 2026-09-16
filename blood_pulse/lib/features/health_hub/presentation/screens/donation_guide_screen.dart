import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../domain/providers/health_hub_provider.dart';
import '../../domain/models/health_hub_models.dart';

class DonationGuideScreen extends ConsumerWidget {
  const DonationGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guideAsyncValue = ref.watch(donationGuideProvider);

    return Scaffold(
      appBar: BloodPulseAppBar(
        subtitle: 'Your Guide to Giving Life',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: guideAsyncValue.when(
          loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
          error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: AppColors.error))),
          data: (guides) {
            // Group the guides by category
            final Map<String, List<DonationGuideSection>> groupedGuides = {};
            for (var guide in guides) {
              groupedGuides.putIfAbsent(guide.category, () => []).add(guide);
            }

            return ListView(
              children: [
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Guide to Giving Life',
                        style: TextStyle(fontFamily: 'Georgia', fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.success),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Everything you need to know before, during, and after donating blood to ensure a safe and comfortable experience.',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                ...groupedGuides.entries.map((entry) {
                  final category = entry.key;
                  final sections = entry.value;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeader(category),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: sections.map((section) {
                            final isLast = section == sections.last;
                            return Column(
                              children: [
                                _RequirementItem(
                                  icon: Icons.check_circle_outline,
                                  title: section.title,
                                  value: section.content,
                                ),
                                if (!isLast) const Divider(),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],
                  );
                }),

                const SizedBox(height: 32),
              ],
            );
          },
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
}

class _RequirementItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _RequirementItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.neutral, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.secondary),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
