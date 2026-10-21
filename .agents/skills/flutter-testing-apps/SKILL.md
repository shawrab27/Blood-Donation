---
name: flutter-testing-apps
description: Unit, widget, and integration testing for Flutter to prevent regressions, ensure app launch stability, test authentication flows, and verify UI rendering. Use when writing tests, fixing regressions, verifying launch flows, or validating UI components in Flutter.
metadata:
  version: "1.0.0"
---

# Flutter Testing & Regression Prevention

Structured testing workflows for BloodPulse to prevent launch-flow breakages, splash screen freezes, authentication failures, and layout regressions.

## When to Activate

- Adding new features or refactoring existing Flutter code.
- Verifying the app launch sequence (Splash -> Auth / Main Shell).
- Testing critical flows: donor registration, blood request submission, and profile updates.
- Writing widget tests to verify UI rendering and interaction.
- Creating integration tests for end-to-end regression validation.

---

## 1. The Three Testing Layers in BloodPulse

| Test Layer | Target | Tool / Package | Execution Speed |
| :--- | :--- | :--- | :--- |
| **Unit Tests** | Business logic, validators, date parsers, state reducers | `flutter_test`, `test` | Fast (<100ms) |
| **Widget Tests** | Screen rendering, button clicks, dialogs, form input | `WidgetTester`, `flutter_test` | Medium (~1s) |
| **Integration Tests** | Complete end-to-end flows, API connectivity, navigation | `integration_test` | Slow (device/emulator) |

---

## 2. Preventing Launch Flow Regressions

### Problem:
A change in an auth provider, local storage initialization, or splash timer can cause the app to hang on a white screen or splash screen forever.

### Launch Flow Widget Test Pattern:

```dart
// test/features/launch/app_launch_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/main.dart';

void main() {
  group('App Launch Flow Tests', () {
    testWidgets('App initializes splash and navigates to main shell or login', (WidgetTester tester) async {
      // 1. Pump the app root
      await tester.pumpWidget(const BloodPulseApp());

      // 2. Initial state: Splash screen or logo visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // 3. Let async initialization and timers complete
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 4. Assert splash is dismissed and either login or feed is rendered
      expect(find.text('BloodPulse'), findsWidgets);
      
      // Ensure no unbounded render exceptions occurred
      expect(tester.takeException(), isNull);
    });
  });
}
```

---

## 3. Widget Testing Pattern: Forms & Action Buttons

### Example: Verifying "Create Poster" and Request Submission

```dart
// test/features/blood_hub/widgets/create_poster_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/features/blood_hub/screens/create_poster_screen.dart';

void main() {
  testWidgets('Create Poster renders button and validates empty fields', (WidgetTester tester) async {
    // Wrap in MaterialApp & Scaffold with appropriate theme
    await tester.pumpWidget(
      const MaterialApp(
        home: CreatePosterScreen(),
      ),
    );

    // Verify Create Poster button exists and has capsule shape
    final buttonFinder = find.widgetWithText(ElevatedButton, 'Create Poster');
    expect(buttonFinder, findsOneWidget);

    // Tap button without filling fields
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    // Verify validation errors appear and app does not crash
    expect(find.textContaining('required'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
```

---

## 4. Key Rules for Reliable Flutter Tests

1. **Always Use Keys for Critical Interactive Widgets**:
   - Assign `key: const Key('create_poster_submit_button')` to action buttons so widget and integration tests find them without fragile text matching.
2. **Handle Timers and Animations**:
   - Always call `await tester.pumpAndSettle()` after tapping a button or transitioning screens to allow all microtasks and animations to resolve.
   - If using infinite animations (like pulse animations), use `await tester.pump(const Duration(milliseconds: 300))` instead of `pumpAndSettle()` to avoid timeout errors.
3. **Mock Backend Services**:
   - Never let widget tests hit the live Django backend or Firebase. Provide mock repositories or dependency injection overrides.

---

## 5. Pre-Commit Test Execution

Run before pushing or merging any PR:

```bash
# 1. Analyze for static errors and warnings
flutter analyze

# 2. Run all unit and widget tests
flutter test

# 3. Run specific test file
flutter test test/features/launch/app_launch_test.dart
```

---

## 6. Regression Checklist

- [ ] Does the app launch cleanly without unhandled exceptions?
- [ ] Are all mock dependencies properly closed/disposed?
- [ ] Did `tester.takeException()` return `null` across all test cases?
- [ ] Are responsive breakpoints tested for mobile viewports (`tester.binding.setSurfaceSize(const Size(390, 844))`)?
