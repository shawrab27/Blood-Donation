import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blood_pulse/main.dart';
import 'package:blood_pulse/services/api_client.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('BloodPulse Complete E2E Integration Flow', () {
    testWidgets('Register -> Login -> Submit Request -> Verify Feed', (WidgetTester tester) async {
      final apiClient = ApiClient();
      final random = Random().nextInt(100000);
      final phone = '01711$random';
      
      // Step 1: Register a test user
      final regResponse = await apiClient.post('donors/', body: {
        'blood_group': 'B+',
        'district': 'Dhaka',
        'phone_number': phone,
        'full_name': 'Integration Test User',
        'age': 25,
        'gender': 'Male',
        'category': 'civilian',
        'is_verified': false,
      });
      
      expect(regResponse.statusCode, anyOf(200, 201), reason: 'Registration failed: ${regResponse.body}');

      // Step 2: Login
      // We expect this might break if the backend didn't set a password properly during registration.
      Map<String, dynamic> loginData;
      try {
        loginData = await apiClient.login(phone, 'password123');
        expect(loginData['access'], isNotNull, reason: 'Login failed, no access token');
      } catch (e) {
        fail('Login broke: $e');
      }

      // Step 3: Submit Blood Request
      final reqResponse = await apiClient.post('requests/', body: {
        'patient_name': 'Emergency Patient $random',
        'blood_group': 'B+',
        'urgency_level': 'Emergency',
        'hospital_location': 'Test Hospital',
        'contact_number': phone,
      });
      expect(reqResponse.statusCode, anyOf(200, 201), reason: 'Failed to create request: ${reqResponse.body}');

      // Step 4: Assert it appears in UI
      await tester.pumpWidget(const ProviderScope(child: BloodPulseApp()));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.textContaining('Emergency Patient $random'), findsWidgets);
    });
  });
}
