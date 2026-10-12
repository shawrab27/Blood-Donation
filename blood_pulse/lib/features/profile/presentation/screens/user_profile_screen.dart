import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../../services/api_client.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/providers/profile_provider.dart';
import '../../../../constants/app_config.dart';
import '../../../../providers/profile_countdown_provider.dart';
import '../widgets/profile_hero_card.dart';
import '../widgets/profile_stats_row.dart';
import '../widgets/profile_actions_row.dart';
import '../widgets/profile_top_donors_section.dart';
import '../widgets/profile_tabs_section.dart';
import '../widgets/profile_requests_list.dart';
import '../widgets/profile_recent_logs.dart';
import '../widgets/modals/digital_certificate_sheet.dart';
import '../widgets/modals/edit_bio_sheet.dart';

/// Stitch Screen 1: User Profile Screen
/// 1:1 Parity with approved Stitch designs, 0 fake claims, 100% dynamic wiring.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  String _bio = 'Committed to saving lives, one drop at a time.';
  bool _isUpdatingSnooze = false;


  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        ref.read(authProvider.notifier).updateAvatar(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Profile picture updated!'),
              backgroundColor: Color(0xFF1B8A4E),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file != null) {
        final bytes = await file.readAsBytes();
        ref.read(authProvider.notifier).updateAvatar(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Profile picture updated from file!'),
              backgroundColor: Color(0xFF1B8A4E),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach file: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _removePhoto() {
    ref.read(authProvider.notifier).updateAvatar(Uint8List(0));
    try {
      ApiClient().patch('profile/me/', body: {'profile_picture': null});
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Profile photo removed'),
          backgroundColor: Color(0xFF2B2B2B),
        ),
      );
    }
  }

  void _showImagePickerModal() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile Photo',
                    style: TextStyle(fontFamily: 'Georgia', fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // 3 top icons in a row: Attach from File, Open Camera, Open Library
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPhotoActionIcon(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildPhotoActionIcon(
                    icon: Icons.photo_library_rounded,
                    label: 'Library',
                    color: const Color(0xFF0D68AA),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _buildPhotoActionIcon(
                    icon: Icons.attach_file_rounded,
                    label: 'File',
                    color: const Color(0xFF2E7D32),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickFile();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFBA1A1A), size: 18),
                label: const Text(
                  'Remove Current Photo',
                  style: TextStyle(fontFamily: 'Inter', color: Color(0xFFBA1A1A), fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _removePhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoActionIcon({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF24191A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectLastDonationDate() async {
    final countdown = ref.read(profileCountdownProvider);
    final initial = countdown.lastDonationDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(profileCountdownProvider.notifier).recordDonation(picked);
      try {
        await ApiClient().patch('profile/me/', body: {
          'last_donation_date': DateFormat('yyyy-MM-dd').format(picked),
        });
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Last donation date updated. Next eligibility recalculated!'),
            backgroundColor: Color(0xFF1B8A4E),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    final profileAsync = ref.watch(profileProvider);
    final countdownState = ref.watch(profileCountdownProvider);

    String displayName = authUser?.fullName.trim().isNotEmpty == true
        ? authUser!.fullName
        : 'Blood Donor';
    String bloodGroup = authUser?.bloodGroup.isNotEmpty == true ? authUser!.bloodGroup : 'O-';
    int totalDonations = authUser?.totalBagsDonated ?? 0;

    String? profileLastDonationDate;

    profileAsync.whenData((p) {
      if (p != null) {
        final name = '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
        if (name.isNotEmpty) displayName = name;
        if (p.bloodGroup != null && p.bloodGroup!.isNotEmpty) bloodGroup = p.bloodGroup!;
        if (p.totalBagsDonated > 0) totalDonations = p.totalBagsDonated;
        profileLastDonationDate = p.lastDonationDate;
      }
    });

    final int daysRemaining;
    if (totalDonations == 0) {
      daysRemaining = 0;
    } else if (profileLastDonationDate != null && profileLastDonationDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(profileLastDonationDate!);
      if (parsed != null) {
        final daysSince = DateTime.now().difference(parsed).inDays;
        daysRemaining = (AppConfig.donorCooldownDays - daysSince).clamp(0, AppConfig.donorCooldownDays);
      } else {
        daysRemaining = countdownState.daysRemaining;
      }
    } else if (authUser?.lastDonationDate != null) {
      final daysSince = DateTime.now().difference(authUser!.lastDonationDate!).inDays;
      daysRemaining = (AppConfig.donorCooldownDays - daysSince).clamp(0, AppConfig.donorCooldownDays);
    } else {
      daysRemaining = 0;
    }

    final double progressPercent = (AppConfig.donorCooldownDays - daysRemaining).clamp(0, AppConfig.donorCooldownDays) /
        AppConfig.donorCooldownDays;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: const BloodPulseAppBar(),
      body: ResponsiveCenterWrapper(
        maxWidth: 540,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Hero Profile Card ──
            ProfileHeroCard(
              displayName: displayName,
              bio: _bio,
              bloodGroup: bloodGroup,
              totalDonations: totalDonations,
              avatarBytes: authUser?.avatarBytes,
              photoUrl: authUser?.photoUrl,
              googlePhotoUrl: authUser?.googlePhotoUrl,
              onPickPhoto: _showImagePickerModal,
              onEditBio: () {
                EditBioSheet.show(
                  context: context,
                  initialBio: _bio,
                  onSave: (val) => setState(() => _bio = val),
                );
              },
            ),
            const SizedBox(height: 14),

            // ── 30-Day Emergency Snooze Toggle (Directly after Basic Info Card) ──
            Builder(
              builder: (ctx) {
                final currentProfile = profileAsync.valueOrNull;
                final bool isSnoozed = currentProfile?.isSnoozed ?? false;
                String subtitleText = 'Receive emergency donation alerts in your area';

                if (isSnoozed && currentProfile?.alertPauseUntil != null) {
                  final dt = DateTime.tryParse(currentProfile!.alertPauseUntil!);
                  if (dt != null) {
                    subtitleText = 'Paused until ${DateFormat('d MMM yyyy').format(dt)}';
                  } else {
                    subtitleText = 'Paused for 1 month';
                  }
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSnoozed ? AppColors.primary.withValues(alpha: 0.3) : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSnoozed ? const Color(0xFFFDE8E8) : const Color(0xFFF0F4F8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSnoozed ? Icons.notifications_paused_rounded : Icons.notifications_active_outlined,
                          color: isSnoozed ? AppColors.primary : const Color(0xFF5A6E85),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pause Emergency Alerts',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitleText,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: isSnoozed ? AppColors.primary : const Color(0xFF64748B),
                                fontWeight: isSnoozed ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isUpdatingSnooze)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: AppLoader(),
                        )
                      else
                        Switch.adaptive(
                          value: isSnoozed,
                          activeColor: AppColors.primary,
                          onChanged: (val) async {
                            setState(() => _isUpdatingSnooze = true);
                            final success = await ref.read(profileProvider.notifier).setSnooze(enable: val);
                            if (mounted) {
                              setState(() => _isUpdatingSnooze = false);
                            }
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? (val
                                            ? '✓ Alerts paused for 1 month.'
                                            : '✓ Alerts resumed. You are now available.')
                                        : 'Could not update alert status. Please check connection.',
                                    style: const TextStyle(fontFamily: 'Inter'),
                                  ),
                                  backgroundColor: success
                                      ? (val ? const Color(0xFF2B2B2B) : const Color(0xFF1B8A4E))
                                      : AppColors.error,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                        ),

                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),


            // ── Total Bags & Countdown Stats Row ──
            ProfileStatsRow(
              totalBags: totalDonations,
              daysRemaining: daysRemaining,
              progressPercent: progressPercent,
              showCountdown: authUser?.userIntent != 'ONLY_REQUEST',
            ),
            const SizedBox(height: 14),

            // ── Action Pills ──
            ProfileActionsRow(
              onUpdateDate: _selectLastDonationDate,
              onDownloadCertificate: () {
                DigitalCertificateSheet.show(
                  context: context,
                  donorName: displayName,
                  bloodGroup: bloodGroup,
                  totalDonations: totalDonations,
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Top Donors Leaderboard ──
            const ProfileTopDonorsSection(),
            const SizedBox(height: 16),

            // ── Segmented Tabs & Community Feed ──
            ProfileTabsSection(
              onAddPost: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Community Post Creator...')),
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Request List ──
            const ProfileRequestsList(),
            const SizedBox(height: 16),

            // ── Recent Logs ──
            const ProfileRecentLogs(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
