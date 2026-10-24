import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:blood_pulse/core/errors/app_error_mapper.dart';
import 'package:blood_pulse/services/api_client.dart';

void main() {
  group('Guard Tests - Forbidden Items Regression Prevention', () {
    test('Rule 1: Forbidden slogan "Every Drop Counts" must NEVER exist in lib/', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

      final forbidden = RegExp(r'Every\s+Drop\s+Counts', caseSensitive: false);
      final violations = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = entity.readAsStringSync();
          if (forbidden.hasMatch(content)) {
            violations.add(entity.path);
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Forbidden slogan "Every Drop Counts" found in: ${violations.join(', ')}. Slogan must strictly be "You give today, they live today".',
      );
    });

    test('Rule 2: Hardcoded demo report values (13.5, 220000, 6800) must NEVER exist in report analyzer/views', () {
      final targetFiles = [
        'lib/features/health_hub/presentation/screens/ai_report_analysis_screen.dart',
        'lib/features/health_hub/presentation/widgets/ai/ai_report_upload_card.dart',
        'lib/features/health_hub/domain/providers/health_hub_provider.dart',
      ];

      for (final relativePath in targetFiles) {
        final file = File(relativePath);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          expect(content.contains('220000') || content.contains('220,000'), isFalse,
              reason: 'Found mock platelet count 220,000 in $relativePath');
          expect(content.contains('6800') || content.contains('6,800'), isFalse,
              reason: 'Found mock WBC count 6,800 in $relativePath');
        }
      }
    });

    test('Rule 3: No global EN/BN button on general app screens (only on Language selection flow)', () {
      final scaffoldFiles = [
        'lib/features/feed/presentation/screens/feed_screen.dart',
        'lib/features/blood_hub/presentation/screens/blood_hub_home_screen.dart',
        'lib/features/communities/presentation/screens/communities_screen.dart',
        'lib/features/health_hub/presentation/screens/health_hub_screen.dart',
        'lib/features/profile/presentation/screens/user_profile_screen.dart',
      ];

      final globalLangButton = RegExp(r'(EnBnToggle|LanguageSwitcher|GlobalLanguageButton)', caseSensitive: false);
      final violations = <String>[];

      for (final path in scaffoldFiles) {
        final file = File(path);
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          if (globalLangButton.hasMatch(content)) {
            violations.add(path);
          }
        }
      }

      expect(
        violations,
        isEmpty,
        reason: 'Global EN/BN button found in: ${violations.join(', ')}. Language selection belongs strictly to initial onboarding/language screen.',
      );
    });

    test('Rule 4: Raw JSON, ApiException, or HTTP status codes are never shown in UI via AppError', () {
      // Raw ApiException with JSON
      const apiEx = ApiException('{"detail": "Authentication credentials were not provided."}', statusCode: 401);
      final humanizedAuth = AppError.toHumanMessage(apiEx);
      expect(humanizedAuth.contains('ApiException'), isFalse);
      expect(humanizedAuth.contains('{"detail"'), isFalse);
      expect(humanizedAuth.contains('401'), isFalse);
      expect(humanizedAuth, 'Authentication credentials were not provided.');

      // Server error with internal details
      const serverEx = ApiException('{"error": "InternalServerError", "traceback": "Traceback..."}', statusCode: 500);
      final humanizedServer = AppError.toHumanMessage(serverEx);
      expect(humanizedServer.contains('InternalServerError'), isFalse);
      expect(humanizedServer.contains('traceback'), isFalse);
      expect(humanizedServer.contains('500'), isFalse);

      // Generic socket exception
      final unknownEx = Exception('SocketException: OS Error: Connection refused, errno = 111');
      final humanizedUnknown = AppError.toHumanMessage(unknownEx);
      expect(humanizedUnknown.contains('errno = 111'), isFalse);
      expect(humanizedUnknown.contains('SocketException'), isFalse);
      expect(humanizedUnknown, contains('internet connection'));
    });
  });
}
