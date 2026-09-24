import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/blood_hub_api_service.dart';

class DeferralNoticeCard extends ConsumerStatefulWidget {
  const DeferralNoticeCard({super.key});

  @override
  ConsumerState<DeferralNoticeCard> createState() => _DeferralNoticeCardState();
}

class _DeferralNoticeCardState extends ConsumerState<DeferralNoticeCard> {
  bool _loading = true;
  Map<String, dynamic>? _deferralData;

  @override
  void initState() {
    super.initState();
    _fetchDeferral();
  }

  Future<void> _fetchDeferral() async {
    try {
      final res = await ref.read(bloodHubApiServiceProvider).getActiveDeferral();
      if (mounted) {
        setState(() {
          _deferralData = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _appealDeferral(int id) async {
    try {
      await ref.read(bloodHubApiServiceProvider).appealDeferral(id);
      _fetchDeferral();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appeal submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_deferralData == null || _deferralData!['has_deferral'] != true) {
      return const SizedBox.shrink();
    }

    final reason = _deferralData!['reason'] ?? 'Medical condition';
    final appealStatus = _deferralData!['appeal_status'] ?? 'NONE';
    final id = _deferralData!['id'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFBB8B8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, color: Color(0xFFC30121)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Temporary Deferral Active',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFC30121),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You have been temporarily deferred from donating blood (90-day cooldown) due to: $reason.',
            style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFF2B2B2B)),
          ),
          const SizedBox(height: 12),
          if (appealStatus == 'NONE' && id != null)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC30121),
                  side: const BorderSide(color: Color(0xFFC30121)),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => _appealDeferral(id),
                child: const Text('Appeal Deferral'),
              ),
            )
          else if (appealStatus == 'PENDING')
            const Text(
              'Your appeal is currently under review.',
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFFC30121), fontWeight: FontWeight.bold),
            )
          else
            Text(
              'Appeal status: $appealStatus',
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: Color(0xFFC30121), fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }
}
