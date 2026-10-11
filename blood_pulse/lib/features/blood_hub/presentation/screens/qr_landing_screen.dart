// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/responsive_layout.dart';
import '../../../../services/api_client.dart';
import '../widgets/report_broker_dialog.dart';
import '../widgets/request_units_progress_card.dart';

/// Screen (5) of Part G: QR Landing & Closed QR Page (`/requests/:id/qr-landing`).
/// Keeps closed requests readable for anyone scanning a poster QR code,
/// renders the shared [RequestUnitsProgressCard] (`received / pending / needed`),
/// displays `"No longer needed — thank you"` when closed, and blocks new responses
/// once `units_received >= units_needed` or status is closed/expired.
class QRLandingScreen extends StatefulWidget {
  final int requestId;
  final String initialBloodGroup;
  final String initialHospital;
  final int initialUnitsNeeded;
  final int initialUnitsReceived;
  final int initialUnitsPending;
  final String initialRequestMode;
  final String initialStatus;
  final bool initialIsClosed;
  final bool autoFetch;

  const QRLandingScreen({
    super.key,
    required this.requestId,
    this.initialBloodGroup = 'O+',
    this.initialHospital = 'Dhaka Medical College Hospital',
    this.initialUnitsNeeded = 2,
    this.initialUnitsReceived = 2,
    this.initialUnitsPending = 0,
    this.initialRequestMode = 'PROXY',
    this.initialStatus = 'CLOSED',
    this.initialIsClosed = true,
    this.autoFetch = true,
  });

  @override
  State<QRLandingScreen> createState() => _QRLandingScreenState();
}

class _QRLandingScreenState extends State<QRLandingScreen> {
  late String _bloodGroup;
  late String _hospital;
  late int _unitsNeeded;
  late int _unitsReceived;
  late int _unitsPending;
  late String _requestMode;
  late String _status;
  late bool _isClosed;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _bloodGroup = widget.initialBloodGroup;
    _hospital = widget.initialHospital;
    _unitsNeeded = widget.initialUnitsNeeded;
    _unitsReceived = widget.initialUnitsReceived;
    _unitsPending = widget.initialUnitsPending;
    _requestMode = widget.initialRequestMode;
    _status = widget.initialStatus;
    _isClosed = widget.initialIsClosed;
    if (widget.autoFetch && widget.requestId > 0) {
      _fetchQrLanding();
    }
  }

  Future<void> _fetchQrLanding() async {
    setState(() => _loading = true);
    try {
      final response = await ApiClient().get(
        'requests/${widget.requestId}/qr-landing/',
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted && data is Map<String, dynamic>) {
          setState(() {
            _bloodGroup = data['blood_group']?.toString() ?? _bloodGroup;
            _hospital = data['hospital']?.toString() ?? _hospital;
            _unitsNeeded =
                int.tryParse(data['units_needed']?.toString() ?? '') ??
                _unitsNeeded;
            _unitsReceived =
                int.tryParse(data['units_received']?.toString() ?? '') ??
                _unitsReceived;
            _unitsPending =
                int.tryParse(data['units_pending']?.toString() ?? '') ??
                _unitsPending;
            _requestMode = data['request_mode']?.toString() ?? _requestMode;
            _status = data['status']?.toString() ?? _status;
            _isClosed =
                data['is_closed'] == true || _unitsReceived >= _unitsNeeded;
          });
        }
      }
    } catch (_) {
      // Keep fallback initial values for offline / widget test rendering
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectivelyClosed =
        _isClosed ||
        _unitsReceived >= _unitsNeeded ||
        const [
          'CLOSED',
          'FULFILLED',
          'EXPIRED',
          'CANCELLED',
        ].contains(_status.toUpperCase());

    return ResponsiveLayout(
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF8F7),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF2B2B2B),
            ),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/blood-hub'),
          ),
          title: const Text(
            'Requisition QR Status',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2B2B),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Report Broker or Issue',
              icon: const Icon(
                Icons.flag_outlined,
                color: Color(0xFFC30121),
              ),
              onPressed: () => ReportBrokerDialog.show(
                context,
                requestId: widget.requestId,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(
                      color: Color(0xFFC30121),
                    ),
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE8DADA),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC30121),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              _bloodGroup,
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Requisition #${widget.requestId}',
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B2B2B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _hospital,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: Color(0xFF8E7D7F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Shared Progress Widget (Part G #5: Closed QR Page)
                      RequestUnitsProgressCard(
                        title: 'QR Requisition Progress',
                        unitsReceived: _unitsReceived,
                        unitsPending: _unitsPending,
                        unitsNeeded: _unitsNeeded,
                        requestMode: _requestMode,
                        status: _status,
                        isClosed: effectivelyClosed,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          key: const Key('qr_landing_respond_btn'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC30121),
                            disabledBackgroundColor: Colors.grey.shade300,
                            disabledForegroundColor: Colors.grey.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                          onPressed: effectivelyClosed
                              ? null
                              : () => context.push('/blood-hub'),
                          icon: Icon(
                            effectivelyClosed
                                ? Icons.lock_outline_rounded
                                : Icons.volunteer_activism_rounded,
                          ),
                          label: Text(
                            effectivelyClosed
                                ? 'Request Closed — No New Responses'
                                : 'Respond to Donate Blood',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
