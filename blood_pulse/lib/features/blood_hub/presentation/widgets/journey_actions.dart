import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/blood_hub_api_service.dart';

const Color _kPrimary = Color(0xFFC30121);

class JourneyRequesterActions extends ConsumerStatefulWidget {
  final int journeyId;
  final String status;
  final VoidCallback onRefresh;
  final VoidCallback onIssueReport;

  const JourneyRequesterActions({
    super.key,
    required this.journeyId,
    required this.status,
    required this.onRefresh,
    required this.onIssueReport,
  });

  @override
  ConsumerState<JourneyRequesterActions> createState() => _JourneyRequesterActionsState();
}

class _JourneyRequesterActionsState extends ConsumerState<JourneyRequesterActions> {
  bool _loading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await ref.read(bloodHubApiServiceProvider).updateJourneyStatus(widget.journeyId, newStatus);
      widget.onRefresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == 'DONATED') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
                onPressed: _loading ? null : () => _updateStatus('COMPLETED'),
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Confirm Donation Received'),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.status == 'ACCEPTED' || widget.status == 'ON_THE_WAY' || widget.status == 'ARRIVED') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextButton.icon(
          onPressed: widget.onIssueReport,
          icon: const Icon(Icons.report_problem_rounded, color: _kPrimary),
          label: const Text('Report Donation Issue', style: TextStyle(color: _kPrimary)),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class JourneyDonorActions extends ConsumerStatefulWidget {
  final int journeyId;
  final String status;
  final VoidCallback onRefresh;
  final VoidCallback onCancel;

  const JourneyDonorActions({
    super.key,
    required this.journeyId,
    required this.status,
    required this.onRefresh,
    required this.onCancel,
  });

  @override
  ConsumerState<JourneyDonorActions> createState() => _JourneyDonorActionsState();
}

class _JourneyDonorActionsState extends ConsumerState<JourneyDonorActions> {
  bool _loading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);
    try {
      await ref.read(bloodHubApiServiceProvider).updateJourneyStatus(widget.journeyId, newStatus);
      widget.onRefresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == 'ACCEPTED') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
                onPressed: _loading ? null : () => _updateStatus('ON_THE_WAY'),
                child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("I'm On My Way (Start Tracking)"),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onCancel,
              child: const Text("Can't Make It", style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      );
    }

    if (widget.status == 'ON_THE_WAY') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary, foregroundColor: Colors.white),
            onPressed: _loading ? null : () => _updateStatus('ARRIVED'),
            child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("I've Arrived at Hospital"),
          ),
        ),
      );
    }

    if (widget.status == 'ARRIVED') {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A7A3F), foregroundColor: Colors.white),
            onPressed: _loading ? null : () => _updateStatus('DONATED'),
            child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text("I've Donated"),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
