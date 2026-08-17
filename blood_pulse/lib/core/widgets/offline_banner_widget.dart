import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Top banner displayed when network drops ("Offline Mode — Local Data Displayed").
class OfflineBannerWidget extends StatelessWidget {
  const OfflineBannerWidget({
    super.key,
    this.isOffline = false,
  });

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: AppColors.secondary,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
          SizedBox(width: 8),
          Text(
            'Offline Mode — Local Data & Cached Health Logs Displayed',
            style: TextStyle(fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
