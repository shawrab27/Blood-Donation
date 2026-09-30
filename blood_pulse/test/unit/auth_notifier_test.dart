import 'package:shared_preferences/shared_preferences.dart';


import 'dart:async';


import 'dart:convert';


import 'package:http/http.dart' as http;


import 'package:flutter_test/flutter_test.dart';


import 'package:blood_pulse/features/auth/presentation/providers/auth_notifier.dart';
import 'package:blood_pulse/features/profile/domain/providers/profile_provider.dart';


import 'package:blood_pulse/services/api_client.dart';


import 'package:flutter_riverpod/flutter_riverpod.dart';






class DummyProfileNotifier extends ProfileNotifier {
  DummyProfileNotifier();
  @override
  Future<void> fetchProfile() async {} // Do nothing
}

class MockApiClient extends ApiClient {


  final Map<String, dynamic>? profileResponse;


  final bool shouldTimeoutLogin;


  final bool shouldTimeoutProfile;





  MockApiClient({


    this.profileResponse,


    this.shouldTimeoutLogin = false,


    this.shouldTimeoutProfile = false,


  });





  @override


  Future<Map<String, dynamic>> login(String identifier, String password) async {


    if (shouldTimeoutLogin) {


      await Future.delayed(const Duration(milliseconds: 100));


      throw TimeoutException('Server waking up');


    }


    return {'access': 'dummy_token', 'refresh': 'dummy_refresh'};


  }





  @override


  Future<http.Response> get(String path, {Map<String, String>? headers}) async {


    if (path == '/api/donors/me/') {


      if (shouldTimeoutProfile) {


        await Future.delayed(const Duration(milliseconds: 100));


        throw TimeoutException('Profile fetching timed out');


      }


      final data = profileResponse ?? {


        'first_name': 'Test',


        'last_name': 'User',


        'email': 'test@example.com',


        'phone_number': '01700000000',


        'gender': 'Male',


        'blood_group': 'B+',


        'category': 'civilian',


      };


      return http.Response(jsonEncode(data), 200);


    }


    return super.get(path, headers: headers);


  }


}








void main() {


  TestWidgetsFlutterBinding.ensureInitialized();


  SharedPreferences.setMockInitialValues({});





  group('AuthNotifier Tests', () {


    test('login success -> /me fetched', () async {


      final mockApi = MockApiClient(


        profileResponse: {


          'first_name': 'Unit',


          'last_name': 'Tester',


          'email': 'unit@test.com',


        },


      );





      final container = ProviderContainer(overrides: [authProvider.overrideWith(() => AuthNotifier(apiClient: mockApi)), profileProvider.overrideWith((ref) => DummyProfileNotifier())]);


      final notifier = container.read(authProvider.notifier);


      





      final result = await notifier.loginWithCredentials(identifier: '017', password: 'password');


      expect(result, isTrue);





      final state = container.read(authProvider);


      expect(state.status, AuthStatus.authenticatedIncomplete);
      expect(state.user, isNotNull);


      


      expect(state.user!.fullName, 'Unit Tester');


      expect(state.user!.email, 'unit@test.com');


      


      container.dispose();


    });





    test('/me timeout -> retry state, not infinite loading', () async {


      final mockApi = MockApiClient(shouldTimeoutProfile: true);





      final container = ProviderContainer(overrides: [authProvider.overrideWith(() => AuthNotifier(apiClient: mockApi)), profileProvider.overrideWith((ref) => DummyProfileNotifier())]);


      final notifier = container.read(authProvider.notifier);


      





      final result = await notifier.loginWithCredentials(identifier: '017', password: 'password');


      expect(result, isFalse);





      final state = container.read(authProvider);


      expect(state.status, AuthStatus.error);
      expect(state.errorMessage, isNotNull);


      


      expect(state.errorMessage, 'TimeoutProfile fetching timed out');


      


      container.dispose();


    });


  });


}


