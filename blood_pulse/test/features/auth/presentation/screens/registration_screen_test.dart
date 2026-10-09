// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blood_pulse/features/auth/presentation/screens/registration_screen.dart';
import 'package:blood_pulse/l10n/app_localizations.dart';

final class FakePlatformFile extends PlatformFile {
  FakePlatformFile({
    required this.name,
    required this.bytes,
    Uri? uri,
  }) : uri = uri ?? Uri.parse('file:///$name');

  @override
  final String name;

  final Uint8List bytes;

  @override
  final Uri uri;

  @override
  Future<int?> length() async => bytes.lengthInBytes;

  @override
  int? lengthSync() => bytes.lengthInBytes;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(bytes);

  @override
  XFile get xFile => XFile.fromData(bytes, name: name);
}

void main() {
  Widget buildScreen({
    Future<XFile?> Function(ImageSource source)? pickImageFunction,
    Future<PlatformFile?> Function()? pickFileFunction,
    Future<bool> Function()? openAppSettingsFunction,
    Locale locale = const Locale('en'),
  }) {
    return ProviderScope(
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RegistrationScreen(
          pickImageFunction: pickImageFunction,
          pickFileFunction: pickFileFunction,
          openAppSettingsFunction: openAppSettingsFunction,
        ),
      ),
    );
  }

  // 1x1 transparent PNG bytes
  final sampleValidPngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82
  ]);

  group('RegistrationScreen Avatar Photo Picker', () {
    testWidgets('Tapping circular avatar opens modal bottom sheet with 3 options in order', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Old separate buttons must be gone
      expect(find.text('Attach Library'), findsNothing);

      // Helper text under circle remains
      expect(find.text('Upload a clear photo to help identification.'), findsOneWidget);

      // Optional badge is present initially
      expect(find.byKey(const ValueKey('avatar_optional_badge')), findsOneWidget);
      expect(find.text('Optional'), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar_edit_badge')), findsNothing);

      // Tap circular avatar
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();

      // Options in modal sheet
      final galleryOption = find.text('Choose from Gallery');
      final fileOption = find.text('Choose from File');
      final cameraOption = find.text('Open Camera');
      final removeOption = find.text('Remove photo');

      expect(galleryOption, findsOneWidget);
      expect(fileOption, findsOneWidget);
      expect(cameraOption, findsOneWidget);
      expect(removeOption, findsNothing);

      // Verify order: Gallery is above File, File is above Camera
      final galleryY = tester.getTopLeft(galleryOption).dy;
      final fileY = tester.getTopLeft(fileOption).dy;
      final cameraY = tester.getTopLeft(cameraOption).dy;

      expect(galleryY < fileY, isTrue, reason: 'Choose from Gallery must appear before Choose from File');
      expect(fileY < cameraY, isTrue, reason: 'Choose from File must appear before Open Camera');
    });

    testWidgets('Choose from Gallery calls image picker and displays photo and edit badge', (tester) async {
      ImageSource? capturedSource;
      final screen = buildScreen(
        pickImageFunction: (source) async {
          capturedSource = source;
          return XFile.fromData(sampleValidPngBytes, name: 'profile.jpg');
        },
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();

      // Tap Gallery
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(capturedSource, equals(ImageSource.gallery));
      expect(find.byKey(const ValueKey('avatar_edit_badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar_optional_badge')), findsNothing);
      expect(find.byKey(const ValueKey('avatar_user_image')), findsOneWidget);
    });

    testWidgets('Choose from File calls file picker and updates avatar', (tester) async {
      bool filePickerCalled = false;
      final screen = buildScreen(
        pickFileFunction: () async {
          filePickerCalled = true;
          return FakePlatformFile(name: 'avatar.png', bytes: sampleValidPngBytes);
        },
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();

      // Tap File
      await tester.tap(find.text('Choose from File'));
      await tester.pumpAndSettle();

      expect(filePickerCalled, isTrue);
      expect(find.byKey(const ValueKey('avatar_edit_badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar_optional_badge')), findsNothing);
    });

    testWidgets('Open Camera calls camera picker and updates avatar', (tester) async {
      ImageSource? capturedSource;
      final screen = buildScreen(
        pickImageFunction: (source) async {
          capturedSource = source;
          return XFile.fromData(sampleValidPngBytes, name: 'selfie.jpeg');
        },
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();

      // Tap Camera
      await tester.tap(find.text('Open Camera'));
      await tester.pumpAndSettle();

      expect(capturedSource, equals(ImageSource.camera));
      expect(find.byKey(const ValueKey('avatar_edit_badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar_optional_badge')), findsNothing);
    });

    testWidgets('"Remove photo" appears only when a photo exists and removes it on tap', (tester) async {
      final screen = buildScreen(
        pickImageFunction: (source) async {
          return XFile.fromData(sampleValidPngBytes, name: 'photo.webp');
        },
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      // 1. Initially no photo -> "Remove photo" doesn't exist
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();
      expect(find.text('Remove photo'), findsNothing);

      // Select a photo from gallery
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('avatar_edit_badge')), findsOneWidget);

      // 2. Tap avatar again -> bottom sheet reopens with "Remove photo"
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();
      expect(find.text('Remove photo'), findsOneWidget);

      // Tap Remove photo
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();

      // 3. Reverts to no photo state with Optional badge
      expect(find.byKey(const ValueKey('avatar_optional_badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar_edit_badge')), findsNothing);
      expect(find.byKey(const ValueKey('avatar_user_image')), findsNothing);

      // 4. Tap avatar again -> "Remove photo" is gone again
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();
      expect(find.text('Remove photo'), findsNothing);
    });

    testWidgets('File larger than 5 MB is rejected with message', (tester) async {
      // 5 MB + 1 byte
      final oversizedBytes = Uint8List(5 * 1024 * 1024 + 1);

      final screen = buildScreen(
        pickImageFunction: (source) async {
          return XFile.fromData(oversizedBytes, name: 'huge.jpg');
        },
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(find.text('Image size must not exceed 5 MB.'), findsOneWidget);
      // Photo was not applied
      expect(find.byKey(const ValueKey('avatar_optional_badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar_edit_badge')), findsNothing);
    });

    testWidgets('File with wrong extension is rejected with message', (tester) async {
      final screen = buildScreen(
        pickFileFunction: () async {
          return FakePlatformFile(name: 'unsupported.pdf', bytes: sampleValidPngBytes);
        },
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose from File'));
      await tester.pumpAndSettle();

      expect(find.text('Only JPG, JPEG, PNG, and WEBP formats are supported.'), findsOneWidget);
      // Photo was not applied
      expect(find.byKey(const ValueKey('avatar_optional_badge')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar_edit_badge')), findsNothing);
    });

    testWidgets('Cancelling a picker leaves state unchanged and shows no error', (tester) async {
      final screen = buildScreen(
        pickImageFunction: (source) async => null,
        pickFileFunction: () async => null,
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      // Cancel Gallery
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const ValueKey('avatar_optional_badge')), findsOneWidget);

      // Cancel File
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from File'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const ValueKey('avatar_optional_badge')), findsOneWidget);

      // Cancel Camera
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Camera'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      expect(find.byKey(const ValueKey('avatar_optional_badge')), findsOneWidget);
    });

    testWidgets('Camera permission denied shows clear message; permanently denied shows settings action', (tester) async {
      bool openSettingsCalled = false;
      final screen = buildScreen(
        pickImageFunction: (source) async {
          throw PlatformException(code: 'camera_access_denied', message: 'Permission denied');
        },
        openAppSettingsFunction: () async {
          openSettingsCalled = true;
          return true;
        },
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      // First denial
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Camera'));
      await tester.pumpAndSettle();

      expect(find.text('Camera permission denied.'), findsOneWidget);

      // Dismiss snackbar
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(seconds: 4));

      // Second attempt -> permanent denial with settings action
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Camera'));
      await tester.pumpAndSettle();

      expect(find.text('Camera permission is permanently denied. Please enable it in Settings.'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      expect(openSettingsCalled, isTrue);
    });

    testWidgets('Bengali localization displays localized strings for avatar picker', (tester) async {
      final screen = buildScreen(
        locale: const Locale('bn'),
      );

      await tester.pumpWidget(screen);
      await tester.pumpAndSettle();

      // Optional badge in Bengali
      expect(find.text('ঐচ্ছিক'), findsOneWidget);

      // Tap avatar
      await tester.tap(find.byKey(const ValueKey('registration_avatar_tap_target')));
      await tester.pumpAndSettle();

      // Localized options
      expect(find.text('গ্যালারি থেকে বেছে নিন'), findsOneWidget);
      expect(find.text('ফাইল থেকে বেছে নিন'), findsOneWidget);
      expect(find.text('ক্যামেরা খুলুন'), findsOneWidget);
    });
  });
}
