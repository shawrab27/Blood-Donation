import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../../data/blood_hub_api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const Color _kPrimary = Color(0xFFC30121);
const Color _kSecondary = Color(0xFF2B2B2B);
const Color _kTertiary = Color(0xFF0D68AA);
const Color _kNeutral = Color(0xFF8E7D7F);

// ─────────────────────────────────────────────────────────────────────────────
// NATIONAL EMERGENCY OVERVIEW  (/emergency/national)
// ─────────────────────────────────────────────────────────────────────────────

class NationalEmergencyScreen extends ConsumerWidget {
  const NationalEmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(nationalEmergencyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: _kSecondary),
        title: const Text(
          'National Overview',
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kSecondary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _kNeutral),
            onPressed: () => ref.invalidate(nationalEmergencyProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: asyncState.when(
          loading: () => const _Skeleton(),
          error: (e, _) => _ErrorRetry(
            message: '$e',
            onRetry: () => ref.invalidate(nationalEmergencyProvider),
          ),
          data: (state) => _NationalBody(state: state),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BODY — switches between frozen and active
// ─────────────────────────────────────────────────────────────────────────────

class _NationalBody extends StatelessWidget {
  const _NationalBody({required this.state});
  final NationalEmergencyState state;

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenterWrapper(
      maxWidth: 560,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          if (state.isActive) ...[
            SliverToBoxAdapter(child: _ActiveBanner(state: state)),
            SliverToBoxAdapter(child: _ProgressSection(state: state)),
          ] else ...[
            SliverToBoxAdapter(child: _FrozenBanner()),
          ],

          // Emergency hotlines — always shown
          const SliverToBoxAdapter(child: _HotlinesCard()),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FROZEN BANNER  (no active emergency)
// ─────────────────────────────────────────────────────────────────────────────

class _FrozenBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          // Status icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF5EE),
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF1A7A3F).withAlpha(60)),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 40,
              color: Color(0xFF1A7A3F),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Active Emergency',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _kSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'All systems normal. No mass-casualty event or national blood '
              'shortage is currently active in Bangladesh.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: _kNeutral,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          // Info strip
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE0DCDC)),
            ),
            child: const Column(
              children: [
                _InfoLine(
                  icon: Icons.notifications_active_rounded,
                  text:
                      'You will receive an alert if a national emergency is declared.',
                ),
                SizedBox(height: 10),
                _InfoLine(
                  icon: Icons.shield_rounded,
                  text:
                      'BloodPulse coordinates with health authorities and disaster management agencies.',
                ),
                SizedBox(height: 10),
                _InfoLine(
                  icon: Icons.volunteer_activism_rounded,
                  text:
                      'Keep your donor profile up to date so you can respond instantly.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _kTertiary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: _kSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE BANNER  (disaster declared)
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.state});
  final NationalEmergencyState state;

  @override
  Widget build(BuildContext context) {
    final pct = state.totalDonationsNeeded == 0
        ? 0.0
        : state.totalDonationsFulfilled / state.totalDonationsNeeded;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFAA0018), Color(0xFFC30121)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.crisis_alert_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'NATIONAL EMERGENCY ACTIVE',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white70,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            state.title ?? 'Emergency Blood Drive',
            style: const TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (state.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              state.subtitle!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Overall progress bar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${state.totalDonationsFulfilled} / ${state.totalDonationsNeeded} units',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(50),
                      child: LinearProgressIndicator(
                        value: pct.clamp(0.0, 1.0),
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(pct * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOSPITAL DEMAND PROGRESS BARS
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.state});
  final NationalEmergencyState state;

  @override
  Widget build(BuildContext context) {
    if (state.hospitalNeeds.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEE8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Hospital Demand',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _kSecondary,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EAEA)),
          ...state.hospitalNeeds.map(
            (need) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Blood group badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kPrimary,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Text(
                          need.bloodGroup,
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          need.hospitalName,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: _kSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${need.unitsFulfilled}/${need.unitsNeeded}',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: _kNeutral,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: LinearProgressIndicator(
                      value: need.progress,
                      backgroundColor: const Color(0xFFEEE8E8),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        need.progress >= 1.0
                            ? const Color(0xFF1A7A3F)
                            : _kPrimary,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMERGENCY HOTLINES CARD — always shown
// ─────────────────────────────────────────────────────────────────────────────

class _HotlinesCard extends StatelessWidget {
  const _HotlinesCard();

  static const _hotlines = [
    ('National Emergency', '999', Icons.local_police_rounded),
    ('Health Emergency', '16163', Icons.local_hospital_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEE8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.phone_rounded, size: 14, color: _kNeutral),
                SizedBox(width: 6),
                Text(
                  'Emergency Hotlines',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _kSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0EAEA)),
          ..._hotlines.map(
            (h) => ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE9EB),
                  shape: BoxShape.circle,
                ),
                child: Icon(h.$3, color: _kPrimary, size: 18),
              ),
              title: Text(
                h.$1,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kSecondary,
                ),
              ),
              trailing: GestureDetector(
                onTap: () async {
                  final uri = Uri(scheme: 'tel', path: h.$2);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Text(
                    h.$2,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKELETON & ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        const SizedBox(height: 20),
        _Bone(h: 120, r: 20),
        const SizedBox(height: 12),
        _Bone(h: 180, r: 16),
        const SizedBox(height: 12),
        _Bone(h: 120, r: 16),
      ]),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.h, required this.r});
  final double h;
  final double r;
  @override
  Widget build(BuildContext context) => Container(
        height: h,
        decoration: BoxDecoration(
          color: const Color(0xFFEEE8E8),
          borderRadius: BorderRadius.circular(r),
        ),
      );
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
            const Icon(Icons.cloud_off_rounded,
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
