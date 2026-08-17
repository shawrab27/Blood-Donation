import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Medical Infographic Graphic Widget representing blood circulation loop
/// (a_medical_infographic_diagram_showing_the_process_of_blood_circulation_the).
class BloodCirculationDiagramWidget extends StatelessWidget {
  const BloodCirculationDiagramWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.loop_rounded, color: AppColors.primary, size: 24),
              SizedBox(width: 10),
              Text(
                'Human Blood Circulation Loop',
                style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Infographic Vector Graphic
          Center(
            child: SizedBox(
              width: 280,
              height: 180,
              child: CustomPaint(
                painter: _BloodCirculationDiagramPainter(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Legend
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _LegendItem(color: AppColors.primary, label: 'Oxygenated (Arteries)'),
              _LegendItem(color: AppColors.tertiary, label: 'Deoxygenated (Veins)'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondary)),
      ],
    );
  }
}

class _BloodCirculationDiagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Heart Center Node
    final heartPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.5, h * 0.5), 28, heartPaint);

    // Heart Icon Text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'HEART',
        style: TextStyle(fontFamily: 'Georgia', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(w * 0.5 - textPainter.width / 2, h * 0.5 - textPainter.height / 2));

    // Lungs Loop (Top - Blue to Red)
    final lungsPaint = Paint()
      ..color = AppColors.tertiary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final topPath = Path()
      ..moveTo(w * 0.35, h * 0.4)
      ..cubicTo(w * 0.2, 0, w * 0.8, 0, w * 0.65, h * 0.4);
    canvas.drawPath(topPath, lungsPaint);

    // Systemic Body Loop (Bottom - Red to Blue)
    final bodyPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final bottomPath = Path()
      ..moveTo(w * 0.35, h * 0.6)
      ..cubicTo(w * 0.2, h, w * 0.8, h, w * 0.65, h * 0.6);
    canvas.drawPath(bottomPath, bodyPaint);

    // Lungs Node (Top)
    canvas.drawCircle(Offset(w * 0.5, h * 0.12), 14, Paint()..color = const Color(0xFFEDF4FF));
    final lungsText = TextPainter(
      text: const TextSpan(text: 'LUNGS', style: TextStyle(fontFamily: 'Inter', fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.tertiary)),
      textDirection: TextDirection.ltr,
    )..layout();
    lungsText.paint(canvas, Offset(w * 0.5 - lungsText.width / 2, h * 0.12 - lungsText.height / 2));

    // Body Organs Node (Bottom)
    canvas.drawCircle(Offset(w * 0.5, h * 0.88), 14, Paint()..color = const Color(0xFFFFF0F1));
    final bodyText = TextPainter(
      text: const TextSpan(text: 'BODY', style: TextStyle(fontFamily: 'Inter', fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.primary)),
      textDirection: TextDirection.ltr,
    )..layout();
    bodyText.paint(canvas, Offset(w * 0.5 - bodyText.width / 2, h * 0.88 - bodyText.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
