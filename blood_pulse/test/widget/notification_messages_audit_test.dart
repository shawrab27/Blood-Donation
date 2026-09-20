import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/notifications/presentation/screens/notification_center_screen.dart';

void main() {
  group('Notification Center Messages Tab - Real Account Audit', () {
    testWidgets('Fresh Account 1 (Alice) with 0 conversations shows "No Conversations Yet" and 0 mock names', (WidgetTester tester) async {
      const aliceProfile = UserProfile(
        fullName: 'Alice Rahman',
        email: 'alice@bloodpulse.test',
        primaryPhone: '+8801711000001',
        age: 24,
        gender: 'Female',
        bloodGroup: 'A+',
        category: 'civilian',
        categoryDetails: {},
        neverDonated: true,
        totalBagsDonated: 0,
        isOtpVerified: true,
        isProfileComplete: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier();
              notifier.setUserForTesting(aliceProfile);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: NotificationCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the "Messages" filter chip
      final messagesChip = find.widgetWithText(ChoiceChip, 'Messages');
      expect(messagesChip, findsOneWidget);
      await tester.tap(messagesChip);
      await tester.pumpAndSettle();

      // Explicit verification: Tab MUST show "No Conversations Yet"
      expect(find.text('No Conversations Yet'), findsOneWidget);
      expect(find.text('When you connect with donors or recipients, your real conversations will appear here.'), findsOneWidget);

      // Explicit verification: Mock names MUST NEVER appear
      expect(find.textContaining('Sarah Jenkins'), findsNothing);
      expect(find.textContaining('Dr. Alim'), findsNothing);
      expect(find.textContaining('Tanvir Ahmed'), findsNothing);
    });

    testWidgets('Fresh Account 2 (Bob) with 0 conversations shows "No Conversations Yet" and 0 mock names', (WidgetTester tester) async {
      const bobProfile = UserProfile(
        fullName: 'Bob Chowdhury',
        email: 'bob@bloodpulse.test',
        primaryPhone: '+8801822000002',
        age: 29,
        gender: 'Male',
        bloodGroup: 'B+',
        category: 'civilian',
        categoryDetails: {},
        neverDonated: false,
        totalBagsDonated: 3,
        isOtpVerified: true,
        isProfileComplete: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) {
              final notifier = AuthNotifier();
              notifier.setUserForTesting(bobProfile);
              return notifier;
            }),
          ],
          child: const MaterialApp(
            home: NotificationCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the "Messages" filter chip
      final messagesChip = find.widgetWithText(ChoiceChip, 'Messages');
      expect(messagesChip, findsOneWidget);
      await tester.tap(messagesChip);
      await tester.pumpAndSettle();

      // Explicit verification: Tab MUST show "No Conversations Yet"
      expect(find.text('No Conversations Yet'), findsOneWidget);
      expect(find.text('When you connect with donors or recipients, your real conversations will appear here.'), findsOneWidget);

      // Explicit verification: Mock names MUST NEVER appear
      expect(find.textContaining('Sarah Jenkins'), findsNothing);
      expect(find.textContaining('Dr. Alim'), findsNothing);
      expect(find.textContaining('Tanvir Ahmed'), findsNothing);
    });
  });
}
