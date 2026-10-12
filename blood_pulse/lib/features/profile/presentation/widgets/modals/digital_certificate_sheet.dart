// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'dart:ui' as ui;
import 'package:blood_pulse/core/widgets/app_loader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/config/api_config.dart';
import '../../../../../services/api_client.dart';

/// Modal bottom sheet displaying the Verified Official Donor Certificate.
/// Matches the ornate baroque crimson-gold design with QR verification,
/// high-res PNG gallery export, and PDF generation.
class DigitalCertificateSheet extends StatefulWidget {
  final String donorName;
  final String bloodGroup;
  final int totalDonations;

  const DigitalCertificateSheet({
    super.key,
    required this.donorName,
    required this.bloodGroup,
    required this.totalDonations,
  });

  static Future<void> show({
    required BuildContext context,
    required String donorName,
    required String bloodGroup,
    required int totalDonations,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DigitalCertificateSheet(
        donorName: donorName,
        bloodGroup: bloodGroup,
        totalDonations: totalDonations,
      ),
    );
  }

  @override
  State<DigitalCertificateSheet> createState() => _DigitalCertificateSheetState();
}

class _DigitalCertificateSheetState extends State<DigitalCertificateSheet> {
  final GlobalKey _certificateKey = GlobalKey();
  bool _isLoading = false;
  bool _isExporting = false;
  String? _certificateId;
  DateTime _issuedDate = DateTime.now();
  int _donationsCount = 0;

  @override
  void initState() {
    super.initState();
    _donationsCount = widget.totalDonations;
    _certificateId = 'bp-cert-${widget.donorName.hashCode.abs().toRadixString(16)}';
    if (_donationsCount >= 1) {
      _fetchOrIssueCertificate();
    }
  }

  Future<void> _fetchOrIssueCertificate() async {
    try {
      final getRes = await ApiClient().get('certificates/me/');
      if (getRes.statusCode == 200) {
        final data = jsonDecode(getRes.body) as Map<String, dynamic>;
        final cert = data['certificate'] as Map<String, dynamic>?;
        if (cert != null) {
          if (mounted) {
            setState(() {
              _certificateId = cert['id']?.toString();
              if (cert['issued_at'] != null) {
                _issuedDate = DateTime.tryParse(cert['issued_at'].toString()) ?? DateTime.now();
              }
              _donationsCount = (cert['donation_count_snapshot'] as num?)?.toInt() ?? widget.totalDonations;
              _isLoading = false;
            });
          }
          return;
        }
      }

      // If no certificate exists yet, issue one
      final postRes = await ApiClient().post('certificates/');
      if (postRes.statusCode == 201 || postRes.statusCode == 200) {
        final data = jsonDecode(postRes.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _certificateId = data['id']?.toString();
            if (data['issued_at'] != null) {
              _issuedDate = DateTime.tryParse(data['issued_at'].toString()) ?? DateTime.now();
            }
            _donationsCount = (data['donation_count_snapshot'] as num?)?.toInt() ?? widget.totalDonations;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback ID for offline/preview
    if (mounted) {
      setState(() {
        _certificateId ??= 'bp-cert-${widget.donorName.hashCode.abs().toRadixString(16)}';
        _isLoading = false;
      });
    }
  }

  Future<Uint8List?> _captureCertificatePng() async {
    try {
      final boundary = _certificateKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[Certificate] Capture error: $e');
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _captureCertificatePng();
      if (bytes == null) throw Exception('Could not render certificate image');

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      await Gal.putImageBytes(
        bytes,
        name: 'BloodPulse_Certificate_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('✓ Certificate saved to Gallery!'),
            backgroundColor: Color(0xFF1B8A4E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gallery save failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _downloadPdf() async {
    setState(() => _isExporting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await _captureCertificatePng();
      if (bytes == null) throw Exception('Could not render certificate image');

      final pdf = pw.Document();
      final pdfImage = pw.MemoryImage(bytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) {
            return pw.FullPage(
              ignoreMargins: true,
              child: pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain)),
            );
          },
        ),
      );

      final pdfBytes = await pdf.save();
      final xFile = XFile.fromData(
        pdfBytes,
        mimeType: 'application/pdf',
        name: 'BloodPulse_Certificate_${widget.donorName.replaceAll(" ", "_")}.pdf',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          text: 'Official BloodPulse Donor Certificate for ${widget.donorName}',
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('PDF generation failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _shareCertificate() {
    final verifyUrl = _certificateId != null
        ? '${ApiConfig.baseUrl}/verify/$_certificateId'
        : 'https://bloodpulse.org';
    SharePlus.instance.share(
      ShareParams(
        text: '🩸 Verified Blood Donor Certificate - BloodPulse\n\n'
            'Donor: ${widget.donorName}\n'
            'Blood Group: ${widget.bloodGroup}\n'
            'Total Contribution: $_donationsCount ${_donationsCount == 1 ? "Bag" : "Bags"}\n'
            'Verify Authenticity: $verifyUrl',
        subject: '${widget.donorName} - BloodPulse Donor Certificate',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLocked = _donationsCount < 1;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Verified Donor Certificate',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF24191A),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 22),
                onPressed: () => Navigator.of(context).pop(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: isLocked
                  ? _buildLockedView()
                  : _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40.0),
                            child: SizedBox(width: 32, height: 32, child: AppLoader()),
                          ),
                        )
                      : Column(
                          children: [
                            // ── Certificate Canvas wrapped in RepaintBoundary ──
                            RepaintBoundary(
                              key: _certificateKey,
                              child: _buildCertificateCard(),
                            ),
                            const SizedBox(height: 20),

                            // ── Action Buttons Row ──
                            if (_isExporting)
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(width: 24, height: 24, child: AppLoader()),
                              )
                            else
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.download_rounded, size: 18),
                                          label: const Text('Save Image'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(50),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            textStyle: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          onPressed: _saveToGallery,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                          label: const Text('Export PDF'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF24191A),
                                            side: BorderSide(color: Colors.grey.shade300),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(50),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            textStyle: const TextStyle(
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          onPressed: _downloadPdf,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.share_rounded, size: 18, color: AppColors.primary),
                                      label: const Text(
                                        'Share Certificate & Verification Link',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      onPressed: _shareCertificate,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0F1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_clock_rounded, color: AppColors.primary, size: 38),
          ),
          const SizedBox(height: 18),
          const Text(
            'Certificate Locked',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF24191A),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'You must complete at least 1 verified blood donation on BloodPulse to generate and download your official Certificate of Appreciation.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              color: Color(0xFF5C3F3D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to Profile', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificateCard() {
    final verifyUrl = _certificateId != null
        ? '${ApiConfig.baseUrl}/verify/$_certificateId'
        : 'https://bloodpulse.org';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: CertificateOrnateBorderPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          child: Stack(
            children: [
              // Subtle Central Heart Watermark
              Positioned.fill(
                child: Opacity(
                  opacity: 0.06,
                  child: Center(
                    child: Image.asset(
                      'assets/images/blood_pulse_logo.png',
                      width: 180,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.favorite_rounded,
                        size: 160,
                        color: Color(0xFF9E1B22),
                      ),
                    ),
                  ),
                ),
              ),

              // Foreground Certificate Content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  // Title
                  const Text(
                    'Certificate of Appreciation',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF221A1A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Organization
                  const Text(
                    'BLOODPULSE',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
                      color: Color(0xFF9E1B22),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  const Text(
                    'This is to certify that',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF4A3E3D),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Donor Name
                  Text(
                    widget.donorName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1718),
                      decoration: TextDecoration.underline,
                      decorationColor: Color(0xFF9E1B22),
                      decorationThickness: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Blood Group & Contribution
                  Text(
                    'Blood Group: ${widget.bloodGroup}\nTotal Contribution: $_donationsCount ${_donationsCount == 1 ? "Bag" : "Bags"}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF332929),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Citation
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'For your invaluable contribution to saving lives through voluntary blood donation across Bangladesh.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: Color(0xFF5A4948),
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bottom Verification & Signatures Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Left: QR Code & Verification Info
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFD3B79C), width: 1),
                              ),
                              child: QrImageView(
                                data: verifyUrl,
                                version: QrVersions.auto,
                                size: 58,
                                gapless: true,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _certificateId != null
                                  ? 'ID: ${_certificateId!.substring(0, _certificateId!.length > 8 ? 8 : _certificateId!.length).toUpperCase()}'
                                  : 'Verified',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF886A50),
                              ),
                            ),
                            const Text(
                              'Scan to verify validity',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 8.5,
                                color: Color(0xFF7A6867),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Right: Signature Block
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Nasim Shawrab',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF221A1A),
                              ),
                            ),
                            Container(
                              width: 120,
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              color: const Color(0xFF332929),
                            ),
                            const Text(
                              'Nasim Shawrab\nLead Software Engineer',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A3E3D),
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              DateFormat('d MMM yyyy').format(_issuedDate),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 8.5,
                                color: Color(0xFF7A6867),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ornate Baroque Border Painter drawing regal deep crimson and gold borders
/// with decorative corner flourishes.
class CertificateOrnateBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const crimson = Color(0xFF9E1B22);
    const gold = Color(0xFFC5A059);

    // 1. Outer Frame (Crimson)
    final outerPaint = Paint()
      ..color = crimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
        const Radius.circular(12),
      ),
      outerPaint,
    );

    // 2. Middle Fine Frame (Gold)
    final goldPaint = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, 10, size.width - 20, size.height - 20),
        const Radius.circular(9),
      ),
      goldPaint,
    );

    // 3. Inner Frame (Crimson Fine)
    final innerPaint = Paint()
      ..color = crimson.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(15, 15, size.width - 30, size.height - 30),
        const Radius.circular(6),
      ),
      innerPaint,
    );

    // 4. Four Corner Baroque Accents
    _drawCornerFlourish(canvas, 15, 15, 1, 1, gold, crimson);
    _drawCornerFlourish(canvas, size.width - 15, 15, -1, 1, gold, crimson);
    _drawCornerFlourish(canvas, 15, size.height - 15, 1, -1, gold, crimson);
    _drawCornerFlourish(canvas, size.width - 15, size.height - 15, -1, -1, gold, crimson);
  }

  void _drawCornerFlourish(
    Canvas canvas,
    double x,
    double y,
    double dirX,
    double dirY,
    Color gold,
    Color crimson,
  ) {
    final flourishPaint = Paint()
      ..color = crimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path()
      ..moveTo(x, y + 14 * dirY)
      ..lineTo(x, y)
      ..lineTo(x + 14 * dirX, y);

    canvas.drawPath(path, flourishPaint);

    final dotPaint = Paint()..color = gold..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(x + 6 * dirX, y + 6 * dirY), 2.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
