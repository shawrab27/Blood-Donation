import 'dart:typed_data';
import 'package:flutter/material.dart';

class AvatarHelper extends StatelessWidget {
  final Uint8List? uploadedPhoto;
  final String? googlePhotoUrl;
  final String? serverPhotoUrl;
  final String fallbackName;
  final double radius;

  const AvatarHelper({
    super.key,
    this.uploadedPhoto,
    this.googlePhotoUrl,
    this.serverPhotoUrl,
    required this.fallbackName,
    this.radius = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? finalImage;
    if (uploadedPhoto != null) {
      finalImage = MemoryImage(uploadedPhoto!);
    } else if (serverPhotoUrl != null && serverPhotoUrl!.isNotEmpty) {
      finalImage = NetworkImage(serverPhotoUrl!);
    } else if (googlePhotoUrl != null && googlePhotoUrl!.isNotEmpty) {
      finalImage = NetworkImage(googlePhotoUrl!);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFC30121).withOpacity(0.1),
      backgroundImage: finalImage,
      child: (finalImage == null)
          ? Text(
              fallbackName.isNotEmpty ? fallbackName.trim()[0].toUpperCase() : '?',
              style: TextStyle(
                color: const Color(0xFFC30121),
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }
}
