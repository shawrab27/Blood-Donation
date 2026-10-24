// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/health_hub/domain/providers/health_hub_provider.dart';
import 'package:blood_pulse/features/health_hub/presentation/screens/recovery_aftercare_screen.dart';
import 'package:blood_pulse/core/widgets/ring_ecg_progress.dart';

void main() {
  testWidgets('Recovery tracker displays empty state with no percentage for never-donated user', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recoveryStatusProvider.overrideWith((ref) async => const RecoveryStatus(
            hasDonated: false,
            statusTitle: 'No Active Recovery Cycle',
            statusMessage: 'Your recovery tracker starts after your first donation.',
          )),
        ],
        child: const MaterialApp(
          home: RecoveryAftercareScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Your recovery tracker starts after your first donation.'), findsOneWidget);
    // Never show hardcoded 85% or percentage dial
    expect(find.text('85%'), findsNothing);
    expect(find.byType(RingEcgProgress), findsNothing);
  });

  testWidgets('Recovery tracker displays RingEcgProgress dial and dynamic percentage for active donor', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recoveryStatusProvider.overrideWith((ref) async => const RecoveryStatus(
            hasDonated: true,
            lastDonationDate: '2026-10-23',
            recoveryPercentage: 25,
            elapsedDays: 1,
            elapsedHours: 24,
            stage: 'Plasma Volume Replenishment',
            statusTitle: 'Plasma Volume Replenishment (24 Hours)',
            statusMessage: 'It has been 24 hours since your donation. Plasma volume is 95% restored.',
          )),
        ],
        child: const MaterialApp(
          home: RecoveryAftercareScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(RingEcgProgress), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Plasma Volume Replenishment (24 Hours)'), findsOneWidget);
    expect(find.text('85%'), findsNothing);
  });
}
