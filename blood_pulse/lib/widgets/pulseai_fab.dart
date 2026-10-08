// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Floating Action Button for PulseAI Assistant.
/// Features:
/// - Deep red (#C30121) circular core
/// - Soft red (#FF6B7A) blood drop + animated ECG pulse line
/// - 1600ms heartbeat pulse cycle (8px up-down bounce + outer ripple fade 1 -> 0)
/// - Modal bottom sheet with 4 quick action options
class PulseAIFAB extends StatefulWidget {
  const PulseAIFAB({super.key});

  @override
  State<PulseAIFAB> createState() => _PulseAIFABState();
}

class _PulseAIFABState extends State<PulseAIFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rippleScaleAnimation;
  late Animation<double> _rippleOpacityAnimation;
  late Animation<double> _ecgPhaseAnimation;

  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    // Heartbeat up/down bounce: peaks around mid-cycle
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -8.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -8.0, end: 2.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 2.0, end: -4.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -4.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 30,
      ),
    ]).animate(_controller);

    // Outer ripple expands and fades
    _rippleScaleAnimation = Tween<double>(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );

    _rippleOpacityAnimation = Tween<double>(begin: 0.65, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuad),
    );

    // ECG line animation phase
    _ecgPhaseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showQuickMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _PulseAIQuickMenuSheet(
        onHideRequested: () {
          Navigator.pop(ctx);
          setState(() => _isVisible = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PulseAI minimized. You can access it anytime from the top bar.',
                  style: TextStyle(fontFamily: 'Inter')),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounceAnimation.value),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer Expanding Ripple
              Transform.scale(
                scale: _rippleScaleAnimation.value,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC30121)
                          .withValues(alpha: _rippleOpacityAnimation.value),
                      width: 2.2,
                    ),
                  ),
                ),
              ),

              // Main Deep Red Action Button
              GestureDetector(
                onTap: _showQuickMenu,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFDC143C),
                        Color(0xFFC30121),
                        Color(0xFF900018),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFC30121).withValues(alpha: 0.45),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _PulseAIIconPainter(
                      phase: _ecgPhaseAnimation.value,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter for the soft red blood drop + ECG pulse line inside the FAB.
class _PulseAIIconPainter extends CustomPainter {
  final double phase;

  _PulseAIIconPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Draw blood drop silhouette
    final dropPath = Path();
    final dropWidth = size.width * 0.44;
    final dropHeight = size.height * 0.58;
    final topY = center.dy - dropHeight * 0.46;
    final bottomY = center.dy + dropHeight * 0.46;

    dropPath.moveTo(center.dx, topY);
    dropPath.cubicTo(
      center.dx + dropWidth * 0.65,
      topY + dropHeight * 0.55,
      center.dx + dropWidth * 0.55,
      bottomY,
      center.dx,
      bottomY,
    );
    dropPath.cubicTo(
      center.dx - dropWidth * 0.55,
      bottomY,
      center.dx - dropWidth * 0.65,
      topY + dropHeight * 0.55,
      center.dx,
      topY,
    );
    dropPath.close();

    final dropPaint = Paint()
      ..color = const Color(0xFFFF6B7A).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawPath(dropPath, dropPaint);

    // 2. Draw animated ECG Pulse line
    final ecgPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final ecgPath = Path();
    final startX = center.dx - dropWidth * 0.65;
    final endX = center.dx + dropWidth * 0.65;
    final baselineY = center.dy + 4;

    ecgPath.moveTo(startX, baselineY);
    ecgPath.lineTo(center.dx - 11, baselineY);
    // P wave
    ecgPath.lineTo(center.dx - 8, baselineY - 3);
    ecgPath.lineTo(center.dx - 5, baselineY);
    // Q wave
    ecgPath.lineTo(center.dx - 3, baselineY + 2);
    // R wave peak
    ecgPath.lineTo(center.dx, baselineY - 14);
    // S wave dip
    ecgPath.lineTo(center.dx + 4, baselineY + 7);
    // T wave
    ecgPath.lineTo(center.dx + 7, baselineY - 4);
    ecgPath.lineTo(center.dx + 10, baselineY);
    ecgPath.lineTo(endX, baselineY);

    canvas.drawPath(ecgPath, ecgPaint);

    // Sparkle dot moving along ECG line
    final dotPaint = Paint()
      ..color = const Color(0xFFFFE4E6)
      ..style = PaintingStyle.fill;
    final dotX = startX + (endX - startX) * phase;
    canvas.drawCircle(Offset(dotX, baselineY), 2.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _PulseAIIconPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}

/// Modal Bottom Sheet with the 4 PulseAI quick menu options.
class _PulseAIQuickMenuSheet extends StatelessWidget {
  final VoidCallback onHideRequested;

  const _PulseAIQuickMenuSheet({required this.onHideRequested});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFFEE9EB),
                  ),
                  child: const Center(
                    child: Icon(Icons.auto_awesome, color: Color(0xFFC30121), size: 22),
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PulseAI Assistant',
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B2B2B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Clinical intelligence & blood logistics',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF0E5E5)),
            const SizedBox(height: 12),

            // Option 1: Chat with PulseAI
            _buildOptionTile(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chat with PulseAI',
              subtitle: 'Ask about eligibility, symptoms, compatibility, or cooldown',
              color: const Color(0xFFC30121),
              onTap: () {
                Navigator.pop(context);
                context.push('/assistant');
              },
            ),

            // Option 2: Analyse blood report
            _buildOptionTile(
              context,
              icon: Icons.document_scanner_outlined,
              title: 'Analyse blood report',
              subtitle: 'Scan lab reports or CBC values for donation safety check',
              color: const Color(0xFF0D68AA),
              onTap: () {
                Navigator.pop(context);
                context.push('/health-hub/analyzer');
              },
            ),

            // Option 3: Find donors nearby
            _buildOptionTile(
              context,
              icon: Icons.radar_rounded,
              title: 'Find donors nearby',
              subtitle: 'Search compatible donors within your radius and district',
              color: const Color(0xFF1B8A4E),
              onTap: () {
                Navigator.pop(context);
                context.push('/blood-hub/search');
              },
            ),

            // Option 4: Hide PulseAI
            _buildOptionTile(
              context,
              icon: Icons.visibility_off_outlined,
              title: 'Hide PulseAI',
              subtitle: 'Minimize the floating button for this session',
              color: const Color(0xFF8E7D7F),
              onTap: onHideRequested,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF2B2B2B),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF666666),
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFBBB8B8)),
        onTap: onTap,
      ),
    );
  }
}
