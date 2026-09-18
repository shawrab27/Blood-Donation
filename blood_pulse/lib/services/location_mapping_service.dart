/// BloodPulse — Spatial Mapping Service
///
/// Handles geographic operations for the BloodPulse donor network including:
///  1. Geohash encoding/decoding for fast Firestore spatial queries.
///  2. Bounding-box and radius proximity calculations.
///  3. Donor Privacy Fuzzing: applies a cryptographically secure random offset
///     (up to 500m) to donor coordinates to protect exact residential addresses.
library;

import 'dart:math';

import 'package:latlong2/latlong.dart';

// ─── Custom Lightweight Geohasher ───────────────────────────────────────────
// Base32 character map for Geohash
const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

class LocationMappingService {
  LocationMappingService._();
  static final LocationMappingService instance = LocationMappingService._();

  // ── Privacy Fuzzing ───────────────────────────────────────────────────

  /// Applies a random spatial offset up to [maxOffsetMeters] to protect donor privacy.
  /// Uses a uniform random distribution within a circle.
  LatLng fuzzLocation(LatLng original, {double maxOffsetMeters = 500.0}) {
    final rand = Random.secure();
    
    // Random angle between 0 and 2*PI
    final angle = rand.nextDouble() * 2 * pi;
    
    // To ensure uniform distribution in a circle, take the square root of the random uniform
    // distance fraction.
    final fraction = sqrt(rand.nextDouble());
    final distanceMeters = fraction * maxOffsetMeters;

    final distance = Distance();
    return distance.offset(original, distanceMeters, angle);
  }

  // ── Geohash Operations ────────────────────────────────────────────────

  /// Encodes latitude and longitude into a geohash string of [precision].
  /// Precision of 5 ≈ 4.9km x 4.9km block.
  /// Precision of 6 ≈ 1.2km x 0.6km block.
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

  // ── Mock Radius Query ─────────────────────────────────────────────────

  /// Generates mock donors around a target [center] for UI demonstration.
  /// In production, this would query Firestore `where('geohash', isGreaterThanOrEqualTo: prefix)`
  List<DonorPin> fetchNearbyDonors(LatLng center, {double radiusKm = 5.0}) {
    final rand = Random();
    final donors = <DonorPin>[];
    
    // Generate 15-30 mock donors nearby
    final count = 15 + rand.nextInt(16);
    final distance = Distance();

    final bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

    for (var i = 0; i < count; i++) {
      // Random distance up to radiusKm
      final distMeters = sqrt(rand.nextDouble()) * (radiusKm * 1000);
      final angle = rand.nextDouble() * 2 * pi;
      
      final exactLoc = distance.offset(center, distMeters, angle);
      
      // Apply privacy fuzzing before returning to client layer
      final fuzzedLoc = fuzzLocation(exactLoc);
      
      donors.add(DonorPin(
        id: 'mock_donor_$i',
        location: fuzzedLoc,
        bloodGroup: bloodGroups[rand.nextInt(bloodGroups.length)],
        isVerified: rand.nextDouble() > 0.3, // 70% verified
      ));
    }

    return donors;
  }
}

/// Represents a public donor point on the map.
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
