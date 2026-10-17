// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/models/profile_models.dart';
import '../../domain/providers/profile_provider.dart';
import 'heartbeat_tab_indicator.dart';
import 'modals/donation_detail_sheet.dart';

/// Stitch Screen 1: Profile Tabs Section
/// 3 Tabs:
/// 1. Your Stories (composer + community feed timeline)
/// 2. Activity Summary (verification status, donor id, activity events)
/// 3. Donation History (verified vs self-reported, bags, hospital, date)
/// Active indicator: HeartbeatTabIndicator (3px red line with ECG spike)
class ProfileTabsSection extends ConsumerStatefulWidget {
  final VoidCallback? onAddPost;

  const ProfileTabsSection({super.key, this.onAddPost});

  @override
  ConsumerState<ProfileTabsSection> createState() => _ProfileTabsSectionState();
}

class _ProfileTabsSectionState extends ConsumerState<ProfileTabsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _storyCtrl = TextEditingController();
  bool _isPostingStory = false;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _storyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF0E5E5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tab Bar with Heartbeat Indicator ──
          Container(
            margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF3E5E5)),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(
                    painter: TabBaselinePainter(
                      color: Color(0xFFF3E5E5),
                      strokeWidth: 1.0,
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  indicator: HeartbeatTabIndicator(
                    color: const Color(0xFFC30121),
                    strokeWidth: 2.5,
                    spikeHeight: 6.0,
                    animation: _tabController.animation,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  labelColor: const Color(0xFFC30121),
                  unselectedLabelColor: const Color(0xFF5F5E5E),
                  labelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Your Stories'))),
                    Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Activity Summary'))),
                    Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Donation History'))),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                _dragDistance += details.primaryDelta ?? 0;
              },
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if ((velocity < -200 || _dragDistance < -40) && _tabController.index < 2) {
                  _tabController.animateTo(_tabController.index + 1);
                } else if ((velocity > 200 || _dragDistance > 40) && _tabController.index > 0) {
                  _tabController.animateTo(_tabController.index - 1);
                }
                _dragDistance = 0;
              },
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  switch (_tabController.index) {
                    case 0:
                      return _buildStoriesTab();
                    case 1:
                      return _buildActivityTab();
                    case 2:
                      return _buildDonationHistoryTab();
                    default:
                      return const SizedBox.shrink();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 1: Your Stories ──
  Widget _buildStoriesTab() {
    final storiesAsync = ref.watch(profileStoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Composer Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0E5E5)),
          ),
          child: Column(
            children: [
              TextField(
                controller: _storyCtrl,
                maxLines: 2,
                maxLength: 280,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 13.5),
                decoration: const InputDecoration(
                  hintText: 'Share your donation journey with the community...',
                  hintStyle: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isPostingStory)
                    const SizedBox(width: 20, height: 20, child: AppLoader())
                  else
                    SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: _postStory,
                        icon: const Icon(Icons.send_rounded, size: 14),
                        label: const Text('Share Story'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC30121),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Timeline Feed
        storiesAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(width: 24, height: 24, child: AppLoader()),
            ),
          ),
          error: (err, _) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Text(
              'Could not load stories. Tap to retry.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          data: (stories) {
            if (stories.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                alignment: Alignment.center,
                child: Column(
                  children: const [
                    Icon(Icons.edit_note_rounded, size: 36, color: Color(0xFFE2D6D6)),
                    SizedBox(height: 8),
                    Text(
                      'No stories shared yet.',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Inspire fellow donors in Bangladesh by sharing your donation journey!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: stories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final story = stories[i];
                return _buildStoryCard(story);
              },
            );
          },
        ),
      ],
    );
  }

  Future<void> _postStory() async {
    final text = _storyCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPostingStory = true);
    final ok = await ref.read(profileStoriesProvider.notifier).addStory(text);
    if (mounted) {
      setState(() => _isPostingStory = false);
      if (ok) {
        _storyCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Story posted to Community Feed!'),
            backgroundColor: Color(0xFF1B8A4E),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not post story. Please check connection.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildStoryCard(ProfileStoryModel story) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.water_drop_rounded, size: 16, color: Color(0xFFC30121)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  story.authorName,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                ),
              ),
              Text(
                story.timeAgo,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF8C8A8A)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            story.content,
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF24191A), height: 1.35),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 14, color: Color(0xFFC30121)),
              const SizedBox(width: 4),
              Text('${story.likesCount}', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5F5E5E))),
              const SizedBox(width: 14),
              const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: Color(0xFF5F5E5E)),
              const SizedBox(width: 4),
              Text('${story.commentsCount}', style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF5F5E5E))),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Activity Summary ──
  Widget _buildActivityTab() {
    final profileAsync = ref.watch(profileProvider);
    final activityAsync = ref.watch(profileActivityProvider);
    final profile = profileAsync.valueOrNull;

    final totalDonations = profile?.totalBagsDonated ?? 0;
    final donorId = (profile != null && totalDonations > 0)
        ? 'BP-D${profile.id.toString().padLeft(6, "0")}'
        : (profile != null ? 'Not yet issued' : 'BP-D------');
    final isVerified = (profile?.isVerified ?? false) && totalDonations > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Verification & Identity Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0E5E5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Donor Identifier',
                        style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF5F5E5E)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        donorId,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFC30121)),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isVerified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF4E5),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: isVerified ? const Color(0xFFA5D6A7) : const Color(0xFFFFD8A8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isVerified ? Icons.verified_rounded : Icons.pending_outlined,
                          size: 13,
                          color: isVerified ? const Color(0xFF1B8A4E) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isVerified ? 'Verified Donor' : 'Pending Verification',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isVerified ? const Color(0xFF1B8A4E) : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 18, color: Color(0xFFF0E5E5)),
              // Safety/Verification steps
              _buildVerificationStep('Mobile Number Verification', true),
              const SizedBox(height: 6),
              _buildVerificationStep('District Coverage Selected', profile?.district != null && profile!.district!.isNotEmpty),
              const SizedBox(height: 6),
              _buildVerificationStep('Clinical Blood Group Verification', isVerified),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Recent Activities',
          style: TextStyle(fontFamily: 'Georgia', fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
        ),
        const SizedBox(height: 8),

        // Activity events list
        activityAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(width: 24, height: 24, child: AppLoader()),
            ),
          ),
          error: (_, __) => Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.center,
            child: const Text('No recent activity records.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E))),
          ),
          data: (items) {
            if (items.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                alignment: Alignment.center,
                child: const Text(
                  'No recent activity records found.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF0E5E5)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded, size: 18, color: Color(0xFFC30121)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description,
                              style: const TextStyle(fontFamily: 'Inter', fontSize: 11, color: Color(0xFF5F5E5E)),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        item.timeAgo,
                        style: const TextStyle(fontFamily: 'Inter', fontSize: 10, color: Color(0xFF8C8A8A)),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildVerificationStep(String title, bool isDone) {
    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 15,
          color: isDone ? const Color(0xFF1B8A4E) : const Color(0xFF94A3B8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: isDone ? FontWeight.w600 : FontWeight.normal,
              color: isDone ? const Color(0xFF24191A) : const Color(0xFF5F5E5E),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab 3: Donation History ──
  Widget _buildDonationHistoryTab() {
    final donationsAsync = ref.watch(profileDonationsProvider);

    return donationsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: SizedBox(width: 24, height: 24, child: AppLoader()),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: const Text('Could not load donation history.', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E))),
      ),
      data: (donations) {
        if (donations.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            child: Column(
              children: const [
                Icon(Icons.history_rounded, size: 36, color: Color(0xFFE2D6D6)),
                SizedBox(height: 8),
                Text(
                  'No donations recorded yet.',
                  style: TextStyle(fontFamily: 'Georgia', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF24191A)),
                ),
                SizedBox(height: 4),
                Text(
                  'Your verified blood donations and voluntary reports will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: Color(0xFF5F5E5E)),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: donations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final item = donations[i];
            return _buildDonationCard(item);
          },
        );
      },
    );
  }

  Widget _buildDonationCard(DonationHistoryModel item) {
    final isVerified = item.verified;
    String formattedDate = item.date;
    try {
      final dt = DateTime.tryParse(item.date);
      if (dt != null) {
        formattedDate = DateFormat('d MMMM yyyy').format(dt);
      }
    } catch (_) {}

    final profile = ref.watch(profileProvider).valueOrNull;
    final donorName = profile?.fullName ?? 'Donor';
    final bloodGroup = profile?.bloodGroup ?? 'O+';

    return InkWell(
      onTap: () {
        DonationDetailSheet.show(
          context: context,
          donation: item,
          donorName: donorName,
          bloodGroup: bloodGroup,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0E5E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.hospital.isNotEmpty ? item.hospital : 'Direct Blood Donation',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF24191A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isVerified ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: isVerified ? const Color(0xFFA5D6A7) : const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVerified ? Icons.verified_rounded : Icons.history_toggle_off_rounded,
                      size: 11,
                      color: isVerified ? const Color(0xFF1B8A4E) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isVerified ? 'Verified' : 'Self-Reported',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isVerified ? const Color(0xFF1B8A4E) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF8C8A8A)),
              const SizedBox(width: 4),
              Text(
                formattedDate,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF5F5E5E)),
              ),
              if (item.city.isNotEmpty) ...[
                const SizedBox(width: 10),
                const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF8C8A8A)),
                const SizedBox(width: 3),
                Text(
                  item.city,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 11.5, color: Color(0xFF5F5E5E)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.water_drop_rounded, size: 13, color: Color(0xFFC30121)),
                const SizedBox(width: 4),
                Text(
                  '${item.bags} Bag (${item.volumeMl ?? 450} ml) • ${item.donationType}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFC30121),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
