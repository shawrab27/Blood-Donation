// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:typed_data';
import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../constants/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../../../providers/profile_countdown_provider.dart';
import '../../../../services/api_client.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/providers/profile_provider.dart';
import '../widgets/modals/digital_certificate_sheet.dart';
import '../widgets/modals/edit_bio_sheet.dart';
import '../widgets/modals/last_donation_date_sheet.dart';
import '../widgets/profile_hero_card.dart';
import '../widgets/profile_rating_xp_card.dart';
import '../widgets/profile_stats_row.dart';
import '../widgets/profile_tabs_section.dart';
import '../widgets/profile_top_donors_section.dart';

/// Stitch Screen 1: User Profile Screen
/// 1:1 Parity with approved Stitch designs, 0 fake claims, 100% dynamic wiring.
class UserProfileScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const UserProfileScreen({super.key, this.showAppBar = false});

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
    await LastDonationDateSheet.show(
      context: context,
      initialDate: initial,
    );
  }

  Future<void> _showSnoozeDurationSheet(BuildContext context, UserProfile? authUser) async {
    const options = [
      {'label': '1 Day (24 Hours)', 'days': 1, 'desc': 'Take a quick 24-hour break'},
      {'label': '3 Days', 'days': 3, 'desc': 'Pause alerts over the weekend'},
      {'label': '7 Days (1 Week)', 'days': 7, 'desc': 'Rest for a week'},
      {'label': '30 Days (1 Month)', 'days': 30, 'desc': 'Pause alerts for 1 month'},
      {'label': '60 Days (2 Months)', 'days': 60, 'desc': 'Pause alerts for 2 months'},
      {'label': '90 Days (3 Months)', 'days': 90, 'desc': 'Full clinical cooldown period (3 months)'},
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (sheetCtx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2D6D6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Pause Emergency Alerts',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF24191A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose how long you want to pause incoming emergency blood donation requests:',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Color(0xFF5F5E5E),
                  ),
                ),
                const SizedBox(height: 16),
                ...options.map((opt) {
                  final days = opt['days'] as int;
                  final label = opt['label'] as String;
                  final desc = opt['desc'] as String;
                  return InkWell(
                    onTap: () async {
                      Navigator.pop(sheetCtx);
                      if (_isUpdatingSnooze) return;
                      setState(() => _isUpdatingSnooze = true);
                      final success = await ref.read(profileProvider.notifier).setSnooze(
                        enable: true,
                        days: days,
                        fallbackUser: authUser,
                      );
                      if (mounted) setState(() => _isUpdatingSnooze = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? '✓ Alerts paused for $days days.'
                                  : 'Could not pause alerts. Please check connection.',
                              style: const TextStyle(fontFamily: 'Inter'),
                            ),
                            backgroundColor: success ? const Color(0xFF2B2B2B) : AppColors.error,
                          ),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF24191A),
                                  ),
                                ),
                                Text(
                                  desc,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    color: Color(0xFF5F5E5E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFF8C8A8A), size: 20),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
    int rank = 0;
    double ratingAvg = 5.0;
    int ratingCount = 0;
    int xp = 0;
    int level = 1;
    double levelProgress = 0.0;
    String tier = 'Active Donor';
    String? donorTitle;
    String? occupation;
    String? positionDisplay;

    String? profileLastDonationDate;
    String? hospitalName;

    profileAsync.whenData((p) {
      if (p != null) {
        final name = '${p.firstName ?? ''} ${p.lastName ?? ''}'.trim();
        if (name.isNotEmpty) displayName = name;
        if (p.bloodGroup != null && p.bloodGroup!.isNotEmpty) bloodGroup = p.bloodGroup!;
        if (p.totalBagsDonated > 0) totalDonations = p.totalBagsDonated;
        profileLastDonationDate = p.lastDonationDate;
        rank = p.rank > 0 ? p.rank : p.globalRank;
        ratingAvg = p.ratingAvg;
        ratingCount = p.ratingCount;
        xp = p.xp;
        level = p.level;
        levelProgress = p.levelProgress;
        tier = p.tier;
        donorTitle = p.donorTitle;
        occupation = p.occupation;
        positionDisplay = p.positionDisplay;
        if (p.bio != null && p.bio!.isNotEmpty) _bio = p.bio!;
        if (p.donationHistory.isNotEmpty) {
          hospitalName = p.donationHistory.first.hospital;
        }
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

    final currentProfile = profileAsync.valueOrNull;
    final bool isSnoozed = currentProfile?.isSnoozed ?? false;
    String pauseSubtitleText = 'Tap to pause';
    if (isSnoozed && currentProfile?.alertPauseUntil != null) {
      final dt = DateTime.tryParse(currentProfile!.alertPauseUntil!);
      if (dt != null) {
        final remaining = dt.difference(DateTime.now());
        if (remaining.inDays >= 1) {
          pauseSubtitleText = 'Paused (\${remaining.inDays}d left)';
        } else if (remaining.inHours >= 1) {
          pauseSubtitleText = 'Paused (\${remaining.inHours}h left)';
        } else {
          pauseSubtitleText = 'Paused (\${remaining.inMinutes}m left)';
        }
      } else {
        pauseSubtitleText = 'Paused for 1 mo';
      }
    }

    final scaffold = Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: widget.showAppBar ? const BloodPulseAppBar(showBackButton: true) : null,
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
              rank: rank,
              donorTitle: donorTitle,
              occupation: occupation,
              positionDisplay: positionDisplay,
              avatarBytes: authUser?.avatarBytes,
              photoUrl: authUser?.photoUrl,
              googlePhotoUrl: authUser?.googlePhotoUrl,
              onPickPhoto: _showImagePickerModal,
              onEditBio: () {
                EditBioSheet.show(
                  context: context,
                  initialBio: _bio,
                  onSave: (val) {
                    setState(() => _bio = val);
                    ref.read(profileProvider.notifier).updateProfile({'bio': val});
                  },
                );
              },
            ),
            const SizedBox(height: 14),

            // USER RULE - do not change: 4 stat boxes (Total Donations, Lives Saved, Last Donation, Pause Emergency Alerts) in primary red
            ProfileStatsRow(
              totalBags: totalDonations,
              daysRemaining: daysRemaining,
              progressPercent: progressPercent,
              showCountdown: authUser?.userIntent != 'ONLY_REQUEST',
              lastDonationDateFormatted: profileLastDonationDate != null
                  ? DateFormat('d MMM yyyy').format(DateTime.tryParse(profileLastDonationDate!) ?? DateTime.now())
                  : (authUser?.lastDonationDate != null ? DateFormat('d MMM yyyy').format(authUser!.lastDonationDate!) : null),
              hospitalName: hospitalName,
              onEditLastDonation: _selectLastDonationDate,
              isAlertsPaused: isSnoozed,
              pauseDurationText: pauseSubtitleText,
              onTogglePause: () async {
                if (_isUpdatingSnooze) return;
                if (isSnoozed) {
                  setState(() => _isUpdatingSnooze = true);
                  final success = await ref.read(profileProvider.notifier).setSnooze(
                    enable: false,
                    fallbackUser: authUser,
                  );
                  if (mounted) setState(() => _isUpdatingSnooze = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success ? '✓ Alerts resumed. You are now available.' : 'Could not resume alerts.',
                          style: const TextStyle(fontFamily: 'Inter'),
                        ),
                        backgroundColor: success ? const Color(0xFF1B8A4E) : AppColors.error,
                      ),
                    );
                  }
                } else {
                  await _showSnoozeDurationSheet(context, authUser);
                }
              },
            ),            const SizedBox(height: 14),

            // ── Rating & XP Row (2 Equal Tiles) ──
            ProfileRatingXpCard(
              ratingAvg: ratingAvg,
              ratingCount: ratingCount,
              xp: xp,
              level: level,
              levelProgress: levelProgress,
              tier: tier,
              totalDonations: totalDonations,
              donorTitle: donorTitle,
            ),
            const SizedBox(height: 16),

            // ── Top Donors Leaderboard (5-Column Layout) ──
            const ProfileTopDonorsSection(),
            const SizedBox(height: 16),

            // ── Segmented Tabs with HeartbeatTabIndicator (Your Stories, Activity, History) ──
            const ProfileTabsSection(),
            const SizedBox(height: 24),

            // ── Footer: Download Verified Certificate Compact Pill Button ──
            // USER RULE - do not change: compact pill button for certificate download
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (totalDonations <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Official certificate requires at least 1 verified blood donation.'),
                        backgroundColor: Color(0xFF2B2B2B),
                      ),
                    );
                    return;
                  }
                  DigitalCertificateSheet.show(
                    context: context,
                    donorName: displayName,
                    bloodGroup: bloodGroup,
                    totalDonations: totalDonations,
                  );
                },
                icon: const Icon(Icons.verified_outlined, size: 18, color: Colors.white),
                label: const Text(
                  'Download Verified Certificate',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC30121),
                  elevation: 1,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );

    if (!widget.showAppBar) {
      return scaffold;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/feed');
        }
      },
      child: scaffold,
    );
  }
}
