import 'package:flutter/material.dart';
import 'package:blood_pulse/core/theme/app_colors.dart';

class PasswordStrengthMeter extends StatelessWidget {
  final TextEditingController controller;
  
  const PasswordStrengthMeter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pw = controller.text;
        double strength = 0;
        if (pw.length > 7) strength += 0.25;
        if (RegExp(r'[A-Z]').hasMatch(pw)) strength += 0.25;
        if (RegExp(r'[0-9]').hasMatch(pw)) strength += 0.25;
        if (RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) strength += 0.25;
        
        Color color = AppColors.error;
        String label = 'Weak';
        if (strength > 0.5) { color = Colors.orange; label = 'Fair'; }
        if (strength > 0.75) { color = Colors.green; label = 'Strong'; }
        if (strength == 0) { label = ''; }
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: strength,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              )
          ],
        );
      },
    );
  }
}
