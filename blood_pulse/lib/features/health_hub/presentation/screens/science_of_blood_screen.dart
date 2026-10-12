import 'package:blood_pulse/core/widgets/app_loader.dart';
// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/blood_pulse_app_bar.dart';
import '../../../../core/widgets/responsive_center_wrapper.dart';
import '../widgets/blood_circulation_diagram_widget.dart';

import '../widgets/common/health_hub_subnav_bar.dart';
import '../../domain/providers/health_hub_provider.dart';

class ScienceOfBloodScreen extends ConsumerWidget {
  const ScienceOfBloodScreen({super.key});

  static const List<({String title, String content})> _fallbackArticles = [
    (
      title: 'The Four Components of Blood',
      content:
          'Whole blood consists of red blood cells (oxygen transport), white blood cells (immune defense), platelets (clotting), and plasma (proteins, electrolytes, and nutrients).',
    ),
    (
      title: 'Why Regular Donation Matters',
      content:
          'Red blood cells have a shelf life of 35–42 days and platelets last only 5 days. Consistent voluntary donation ensures hospitals across Bangladesh can respond to emergencies.',
    ),
  ];

  Widget _buildArticlesColumn(List<({String title, String content})> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((article) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(article.title),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  article.content,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.secondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesAsyncValue = ref.watch(scienceArticlesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BloodPulseAppBar(
        subtitle: 'The Science of Blood',
        showBackButton: true,
        onBack: () => context.pop(),
      ),
      body: ResponsiveCenterWrapper(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            children: [
              // Top Subnav
              const HealthHubSubnavBar(activeRoute: '/health-hub/science-of-blood'),

              // ── 1. Hero Banner ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The Science of Blood',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Understanding the vital fluid that carries life, oxygen, and defense to every cell in the human body.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: Colors.white70, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),


              // ── 3. Dynamic Articles from Backend (with friendly fallback) ──
              articlesAsyncValue.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: AppLoader()),
                ),
                error: (_, __) => _buildArticlesColumn(_fallbackArticles),
                data: (articles) => _buildArticlesColumn(
                  articles.isNotEmpty
                      ? articles.map((a) => (title: a.title, content: a.content)).toList()
                      : _fallbackArticles,
                ),
              ),

              // ── 4. Blood Circulation & Clotting ─────────────────────────
              _sectionHeader('Blood Circulation & Clotting'),
              const SizedBox(height: 12),
              const BloodCirculationDiagramWidget(),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF4FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD0E4FF)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'The Circulatory Loop',
                      style: TextStyle(fontFamily: 'Georgia', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.secondary),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '1. Oxygenated blood leaves the left heart via the aorta.\n2. Arteries branch into micro-capillaries supplying tissues.\n3. Deoxygenated blood returns via veins to the right heart.\n4. The pulmonary cycle re-oxygenates blood in the lungs.',
                      style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.secondary, height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Georgia',
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: AppColors.secondary,
      ),
    );
  }
}
