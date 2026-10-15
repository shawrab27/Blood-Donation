// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../widgets/dashboard/health_hub_tools_grid.dart';

/// Clean Health Hub Dashboard Screen matching Stitch Screen 8b78385103a7437189984b21b2fd2ce3.
/// Features a clean, uncluttered layout:
/// - Header: "Health Hub" & "Your wellness overview and clinical insights."
/// - Section: "Tools & Insights"
/// - 8-Card Interactive Tools Grid with smooth active:scale-95 press transition effect.
class HealthHubDashboardScreen extends StatelessWidget {
  const HealthHubDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F7),
      body: SafeArea(
        top: false,
        child: ResponsiveCenterWrapper(
          maxWidth: 900,
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: const [
              SizedBox(height: 8),

              // ── Header Section ───────────────────────────────────────────
              Text(
                'Health Hub',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24191A),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Your wellness overview and clinical insights.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  color: Color(0xFF5C3F3D),
                ),
              ),
              SizedBox(height: 28),

              // ── Tools & Insights Section ─────────────────────────────────
              Text(
                'Tools & Insights',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF24191A),
                ),
              ),
              SizedBox(height: 16),

              // ── Clean 8-Card Tools Grid ──────────────────────────────────
              HealthHubToolsGrid(),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
