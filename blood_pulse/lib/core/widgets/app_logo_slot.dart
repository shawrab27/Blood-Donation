import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Standard logo size definitions for strict uniform scaling across categories.
abstract final class AppLogoSize {
  /// Standard fixed size for Splash screen hero logo.
  static const double splash = 100.0;

  /// Standard fixed size for Auth form cards (Login, OTP).
  static const double card = 64.0;

  /// Standard fixed size for top App Bars across all sub-pages and main tabs.
  static const double header = 36.0;
}

/// The official Blood Pulse Logo Slot component.
///
/// Features:
///   • Loads the official logo image `assets/images/app_logo.png`
///   • Graceful CustomPainter fallback rendering the official 'BP' Heart + ECG Pulse mark
///   • Enforces strict uniform category sizes via [AppLogoSize]
class AppLogoSlot extends StatelessWidget {
  const AppLogoSlot({
    super.key,
    this.size = AppLogoSize.header,
    this.backgroundColor,
    this.showShadow = false,
  });

  final double size;
  final Color? backgroundColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.asset(
      'assets/images/blood_pulse_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/app_logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return _BpHeartPulseFallback(size: size);
          },
        );
      },
    );

    if (backgroundColor == null && !showShadow) {
      return SizedBox(
        width: size,
        height: size,
        child: imageWidget,
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        shape: BoxShape.circle,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: AppColors.primary.withAlpha(40),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: imageWidget,
    );
  }
}

/// Fallback painter drawing the official 'BP' Heart (B light-blue, P deep-red) + ECG pulse line logo mark.
class _BpHeartPulseFallback extends StatelessWidget {
  const _BpHeartPulseFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _BpHeartPulsePainter(),
    );
  }
}

class _BpHeartPulsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Right half 'P' in deep red (#C30121)
    final Paint redPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    // Left half 'B' in light blue / silver (#D0E4FF / #B0C4DE)
    final Paint lightBluePaint = Paint()
      ..color = const Color(0xFFD0E4FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08;

    // ECG pulse line crossing through center in deep red (#C30121)
    final Paint pulseLinePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // ── Left 'B' (Light Blue/Silver outline) ──
    final Path bPath = Path();
    bPath.moveTo(w * 0.48, h * 0.22);
    bPath.cubicTo(w * 0.25, h * 0.15, w * 0.15, h * 0.35, w * 0.28, h * 0.50);
    bPath.cubicTo(w * 0.15, h * 0.65, w * 0.25, h * 0.85, w * 0.48, h * 0.92);
    canvas.drawPath(bPath, lightBluePaint);

    // ── Right 'P' (Solid Deep Red #C30121) ──
    final Path pPath = Path();
    pPath.moveTo(w * 0.52, h * 0.22);
    pPath.cubicTo(w * 0.75, h * 0.20, w * 0.85, h * 0.45, w * 0.52, h * 0.60);
    pPath.lineTo(w * 0.52, h * 0.92);
    pPath.close();
    canvas.drawPath(pPath, redPaint);

    // ── Center ECG Pulse Line ──
    final Path pulse = Path();
    pulse.moveTo(w * 0.15, h * 0.52);
    pulse.lineTo(w * 0.45, h * 0.52);
    pulse.lineTo(w * 0.52, h * 0.38);
    pulse.lineTo(w * 0.60, h * 0.68);
    pulse.lineTo(w * 0.68, h * 0.45);
    pulse.lineTo(w * 0.74, h * 0.52);
    pulse.lineTo(w * 0.85, h * 0.52);
    canvas.drawPath(pulse, pulseLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
