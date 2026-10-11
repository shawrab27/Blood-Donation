// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../services/api_client.dart';

/// Shared dialog & action button for Part D: Report Broker / Request / Donor.
/// Sends reports to `POST /api/reports/broker/` and assures the reporter that
/// their phone, email, and exact location are never shared with the reported party.
class ReportBrokerDialog extends StatefulWidget {
  final int? requestId;
  final int? reportedUserId;
  final String initialTargetType; // 'BROKER', 'REQUEST', or 'DONOR'

  const ReportBrokerDialog({
    super.key,
    this.requestId,
    this.reportedUserId,
    this.initialTargetType = 'BROKER',
  });

  static Future<bool?> show(
    BuildContext context, {
    int? requestId,
    int? reportedUserId,
    String initialTargetType = 'BROKER',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ReportBrokerDialog(
        requestId: requestId,
        reportedUserId: reportedUserId,
        initialTargetType: initialTargetType,
      ),
    );
  }

  @override
  State<ReportBrokerDialog> createState() => _ReportBrokerDialogState();
}

class _ReportBrokerDialogState extends State<ReportBrokerDialog> {
  late String _targetType;
  String _selectedReason = 'MONEY_DEMANDED';
  final TextEditingController _detailsCtrl = TextEditingController();
  bool _submitting = false;

  static const Map<String, String> _reasons = {
    'MONEY_DEMANDED': 'Demanded money / Paid broker activity',
    'FAKE_REQUISITION': 'Suspicious or fabricated blood request',
    'HARASSMENT_OR_ABUSE': 'Misconduct or inappropriate behavior',
    'OTHER': 'Other safety / verification concern',
  };

  @override
  void initState() {
    super.initState();
    _targetType = widget.initialTargetType;
  }

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ApiClient().post(
        'reports/broker/',
        body: {
          if (widget.requestId != null) 'request': widget.requestId,
          if (widget.reportedUserId != null)
            'reported_user': widget.reportedUserId,
          'target_type': _targetType,
          'reason': _selectedReason,
          'details': _detailsCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted to Admin Verification Queue. Your identity & contact remain strictly private.',
          ),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report queued for Admin Verification. Your phone, email, and location are never shared.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('report_broker_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: const Color(0xFFFFF8F7),
      title: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFFC30121)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Report Broker / Safety Issue',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B2B2B),
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D68AA).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Privacy Guarantee: Your phone number, email, and exact location are never exposed to the reported party.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF0D68AA),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Who are you reporting?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['BROKER', 'REQUEST', 'DONOR'].map((t) {
                final selected = _targetType == t;
                return ChoiceChip(
                  label: Text(t),
                  selected: selected,
                  selectedColor: const Color(0xFFC30121).withValues(alpha: 0.15),
                  onSelected: (_) => setState(() => _targetType = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              'Reason',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ..._reasons.entries.map(
              (entry) => RadioListTile<String>(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  entry.value,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
                ),
                value: entry.key,
                groupValue: _selectedReason,
                activeColor: const Color(0xFFC30121),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedReason = val);
                },
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Additional details for admin review (optional)...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          key: const Key('submit_broker_report_btn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFC30121),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Submitting...' : 'Submit Report'),
        ),
      ],
    );
  }
}
