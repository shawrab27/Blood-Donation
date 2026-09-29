import 'dart:developer';
import 'package:flutter/material.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 100});
  
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/bloodpulse_logo.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          log('Warning: bloodpulse_logo.png failed to load. Ensure it is added to assets.', error: error, stackTrace: stackTrace);
          return const Icon(Icons.broken_image, color: Colors.red);
        },
      ),
    );
  }
}
