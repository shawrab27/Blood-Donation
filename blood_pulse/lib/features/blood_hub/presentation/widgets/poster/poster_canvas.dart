// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:blood_pulse/features/blood_hub/domain/entities/poster_template.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_generator_widget.dart';
import 'package:blood_pulse/features/blood_hub/presentation/widgets/poster/poster_style_selectors.dart';

/// Animated aspect-ratio-aware poster canvas that wraps [PosterGeneratorWidget].
/// Handles animated transitions between 1:1, 4:5, and 9:16 aspect ratios.
class PosterCanvas extends StatelessWidget {
  const PosterCanvas({
    super.key,
    required this.generatorKey,
    required this.data,
    required this.templateType,
    required this.aspectRatio,
    this.colorTheme = PosterColorTheme.crimson,
    this.isBangla = false,
  });

  final GlobalKey<PosterGeneratorWidgetState> generatorKey;
  final PosterData data;
  final PosterTemplateType templateType;
  final PosterAspectRatio aspectRatio;
  final PosterColorTheme colorTheme;
  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: AspectRatio(
        aspectRatio: aspectRatio.ratio,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: PosterGeneratorWidget(
              key: generatorKey,
              data: data,
              templateType: templateType,
              aspectRatio: aspectRatio,
              colorTheme: colorTheme,
              isBangla: isBangla,
            ),
          ),
        ),
      ),
    );
  }
}

/// Template-type pill tab strip (1. Photo / 2. Text / 3. Custom).
class PosterTemplateTabBar extends StatelessWidget {
  const PosterTemplateTabBar({
    super.key,
    required this.selected,
    required this.onChanged,
    this.isBangla = false,
  });

  final PosterTemplateType selected;
  final ValueChanged<PosterTemplateType> onChanged;
  final bool isBangla;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3DDE0),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: PosterTemplateType.values.map((type) {
          final labels = isBangla
              ? ['১. ছবিসহ', '২. টেক্সট', '৩. কাস্টম']
              : ['1. Photo', '2. Text', '3. Custom'];
          final label = labels[type.index];
          final isSelected = selected == type;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFC30121)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Colors.white
                        : const Color(0xFF2B2B2B),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
