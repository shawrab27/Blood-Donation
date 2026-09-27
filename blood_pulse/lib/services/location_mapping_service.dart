import 'dart:math';
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:blood_pulse/services/api_client.dart';

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

class LocationMappingService {
  LocationMappingService._();
  static final LocationMappingService instance = LocationMappingService._();

  LatLng fuzzLocation(LatLng original, {double maxOffsetMeters = 500.0}) {
    final rand = Random.secure();
    final angle = rand.nextDouble() * 2 * pi;
    final fraction = sqrt(rand.nextDouble());
    final distanceMeters = fraction * maxOffsetMeters;
    final distance = const Distance();
    return distance.offset(original, distanceMeters, angle);
  }

  String encodeGeohash(double lat, double lon, {int precision = 6}) {
    bool isEven = true;
    double minLat = -90.0, maxLat = 90.0;
    double minLon = -180.0, maxLon = 180.0;
    int bit = 0;
    int ch = 0;
    String hash = '';

    while (hash.length < precision) {
      if (isEven) {
        double mid = (minLon + maxLon) / 2;
        if (lon > mid) {
          ch |= (1 << (4 - bit));
          minLon = mid;
        } else {
          maxLon = mid;
        }
      } else {
        double mid = (minLat + maxLat) / 2;
        if (lat > mid) {
          ch |= (1 << (4 - bit));
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        hash += _base32[ch];
        bit = 0;
        ch = 0;
      }
    }
    return hash;
  }

  Future<List<DonorPin>> fetchNearbyDonors({
    LatLng? center,
    double radiusKm = 5.0,
    ApiClient? apiClient,
  }) async {
    final client = apiClient ?? ApiClient();
    LatLng queryCenter;

    if (center != null) {
      queryCenter = center;
    } else {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const ApiException('Location services are disabled.');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw const ApiException('Location permissions are denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw const ApiException('Location permissions are permanently denied.');
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
        queryCenter = LatLng(pos.latitude, pos.longitude);
      } catch (e) {
        throw ApiException('Failed to get current position: $e');
      }
    }

    final response = await client.get('donors-nearby/?lat=${queryCenter.latitude}&lng=${queryCenter.longitude}&radius_km=$radiusKm');
    
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      final donors = <DonorPin>[];
      for (final item in data) {
        if (item is Map<String, dynamic>) {
            final lat = (item['fuzzed_lat'] as num?)?.toDouble();
            final lng = (item['fuzzed_lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              final fuzzedLocation = LatLng(lat, lng);
              final fullName = item['display_name']?.toString() ?? 'Community Donor';
              donors.add(DonorPin(
                id: item['donor_id']?.toString() ?? 'donor_${donors.length}',
                location: fuzzedLocation,
                bloodGroup: item['blood_group'] ?? 'O+',
                isVerified: true,
                isAvailable: true,
                name: fullName,
              ));
            }
        }
      }
      return donors;
    } else {
      throw ApiException('Failed to fetch nearby donors', statusCode: response.statusCode);
    }
  }
}

class DonorPin {
  const DonorPin({
    required this.id,
    required this.location,
    required this.bloodGroup,
    required this.isVerified,
    this.isAvailable = true,
    this.name,
    this.phone,
  });

  final String id;
  final LatLng location;
  final String bloodGroup;
  final bool isVerified;
  final bool isAvailable;
  final String? name;
  final String? phone;
}
