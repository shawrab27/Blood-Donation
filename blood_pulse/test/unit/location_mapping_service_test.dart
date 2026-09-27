import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:blood_pulse/services/location_mapping_service.dart';
import 'package:blood_pulse/services/api_client.dart';

void main() {
  test('fetchNearbyDonors parses valid mock HTTP response into DonorPin list correctly', () async {
    final mockClient = MockClient((request) async {
      if (request.url.path.contains('donors-nearby')) {
        return http.Response(
          jsonEncode([
            {
              'donor_id': 101,
              'display_name': 'Test Donor',
              'blood_group': 'O+',
              'fuzzed_lat': 23.8,
              'fuzzed_lng': 90.4,
              'distance_km': 1.5,
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('Not Found', 404);
    });

    final apiClient = ApiClient(client: mockClient);
    final donors = await LocationMappingService.instance.fetchNearbyDonors(
      center: LatLng(23.8, 90.4),
      apiClient: apiClient,
    );

    expect(donors.length, 1);
    expect(donors.first.id, '101');
    expect(donors.first.name, 'Test Donor');
    expect(donors.first.bloodGroup, 'O+');
    expect(donors.first.location.latitude, 23.8);
    expect(donors.first.location.longitude, 90.4);
  });

  test('fetchNearbyDonors throws on 4xx/5xx', () async {
    final mockClient = MockClient((request) async {
      return http.Response('Internal Error', 500);
    });

    final apiClient = ApiClient(client: mockClient);

    expect(
      () => LocationMappingService.instance.fetchNearbyDonors(
        center: LatLng(23.8, 90.4),
        apiClient: apiClient,
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
