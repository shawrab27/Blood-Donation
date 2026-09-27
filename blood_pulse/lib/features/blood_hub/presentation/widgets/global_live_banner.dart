// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/blood_hub_api_service.dart';

class GlobalLiveBanner extends ConsumerStatefulWidget {
  const GlobalLiveBanner({super.key});

  @override
  ConsumerState<GlobalLiveBanner> createState() => _GlobalLiveBannerState();
}

class _GlobalLiveBannerState extends ConsumerState<GlobalLiveBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncEvent = ref.watch(activeNationalEmergencyProvider);

    return asyncEvent.when(
      data: (event) {
        if (event == null || !event.isActive) return const SizedBox.shrink();
        
        return GestureDetector(
          onTap: () {
            context.push('/emergency/national');
          },
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF2B2B2B), // Secondary
              border: Border(
                top: BorderSide(color: Color(0xFFC30121), width: 3),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // "LIVE" Chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC30121).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: const Color(0xFFC30121).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FadeTransition(
                        opacity: _animCtrl,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFC30121),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC30121),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.titleEn,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white54,
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
