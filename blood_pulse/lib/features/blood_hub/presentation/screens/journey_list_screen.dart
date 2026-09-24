import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';

const Color _kPrimary = Color(0xFFC30121);
const Color _kSecondary = Color(0xFF2B2B2B);
const Color _kNeutral = Color(0xFF8E7D7F);

// ─────────────────────────────────────────────────────────────────────────────
// JOURNEY LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class JourneyListScreen extends ConsumerStatefulWidget {
  const JourneyListScreen({super.key});

  @override
  ConsumerState<JourneyListScreen> createState() => _JourneyListScreenState();
}

class _JourneyListScreenState extends ConsumerState<JourneyListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncJourneys = ref.watch(journeyListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: _kSecondary),
        title: const Text(
          'Active Journeys',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kSecondary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _kPrimary,
          unselectedLabelColor: _kNeutral,
          indicatorColor: _kPrimary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'My Requests'),
            Tab(text: 'My Donations'),
          ],
        ),
      ),
      body: SafeArea(
        child: asyncJourneys.when(
          loading: () => const _SkeletonList(),
          error: (e, _) => _ErrorRetry(
            message: '$e',
            onRetry: () => ref.invalidate(journeyListProvider),
          ),
          data: (journeys) {
            final requests = journeys
                .where((j) => j.viewerRole == JourneyViewerRole.requester)
                .toList();
            final donations = journeys
                .where((j) => j.viewerRole == JourneyViewerRole.donor)
                .toList();

            return ResponsiveCenterWrapper(
              maxWidth: 600,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ListTab(
                    items: requests,
                    emptyIcon: Icons.volunteer_activism_rounded,
                    emptyTitle: 'No Active Requests',
                    emptySubtitle:
                        'When you request blood and a donor accepts, track them here.',
                  ),
                  _ListTab(
                    items: donations,
                    emptyIcon: Icons.directions_run_rounded,
                    emptyTitle: 'No Active Donations',
                    emptySubtitle:
                        'When you accept a blood request, track your journey here.',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIST TAB
// ─────────────────────────────────────────────────────────────────────────────

class _ListTab extends StatelessWidget {
  const _ListTab({
    required this.items,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });

  final List<JourneyListItem> items;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(emptyIcon, size: 36, color: _kNeutral.withAlpha(120)),
              ),
              const SizedBox(height: 16),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _kSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: _kNeutral,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _JourneyCard(item: items[index]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOURNEY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.item});
  final JourneyListItem item;

  String _formatStatus(String s) {
    return s.replaceAll('_', ' ');
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'ACCEPTED':
        return const Color(0xFF0D68AA);
      case 'ON_THE_WAY':
        return const Color(0xFFCC7722);
      case 'ARRIVED':
      case 'DONATED':
        return const Color(0xFF1A7A3F);
      case 'FAILED':
      case 'CANCELLED':
        return _kNeutral;
      default:
        return _kSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sColor = _statusColor(item.status);
    final bool isActive =
        !['DONATED', 'FAILED', 'CANCELLED'].contains(item.status);

    return InkWell(
      onTap: () => context.push('/journeys/${item.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isActive ? sColor.withAlpha(80) : const Color(0xFFEEE8E8)),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: sColor.withAlpha(12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: Row(
          children: [
            // Left blood drop badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _kPrimary.withAlpha(isActive ? 25 : 12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  item.bloodGroup,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isActive ? _kPrimary : _kNeutral,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Middle info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.hospitalName,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isActive ? _kSecondary : _kNeutral,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: sColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _formatStatus(item.status),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: sColor,
                          ),
                        ),
                      ),
                      if (item.isStandby) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'STANDBY',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _kPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: isActive ? _kSecondary : _kNeutral),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON & ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFFEEE8E8),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFDDD0D0)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: _kNeutral)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder()),
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(fontFamily: 'Inter')),
            ),
          ],
        ),
      ),
    );
  }
}
