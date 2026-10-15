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
        'assets/images/launcher_icon_transparent.png',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          log('Warning: launcher_icon_transparent.png failed to load.', error: error, stackTrace: stackTrace);
          return const Icon(Icons.broken_image, color: Colors.red);
        },
      ),
    );
  }
}
