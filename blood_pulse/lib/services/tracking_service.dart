// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Service managing real-time GPS tracking via Geolocator and Firestore `tracking/{matchId}`.
/// Strictly updates ONLY while donor status is IN_TRANSIT.
class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _periodicTimer;
  String? _activeMatchId;

  /// Currently tracked match identifier, or null if idle.
  String? get activeMatchId => _activeMatchId;

  FirebaseFirestore? get _db {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Checks and requests location permission.
  Future<LocationPermission> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermission.denied;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  bool isPermissionGranted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Starts donor GPS live tracking.
  /// Writes to Firestore tracking/{matchId} every 10 seconds or 50 meters moved.
  Future<void> startDonorTracking({
    required String matchId,
    required String donorUid,
    required String requesterUid,
    required double hospitalLat,
    required double hospitalLng,
  }) async {
    await stopTracking();

    final permission = await checkAndRequestPermission();
    if (!isPermissionGranted(permission)) {
      debugPrint('[TrackingService] Location permission denied: $permission');
      return;
    }

    _activeMatchId = matchId;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50, // update every 50 meters
    );

    // Initial position write
    try {
      final initialPos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _writePosition(
        matchId: matchId,
        donorUid: donorUid,
        requesterUid: requesterUid,
        position: initialPos,
        hospitalLat: hospitalLat,
        hospitalLng: hospitalLng,
      );
    } catch (e) {
      debugPrint('[TrackingService] Initial position read failed: $e');
    }

    // Stream on 50m movement
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (pos) {
        _writePosition(
          matchId: matchId,
          donorUid: donorUid,
          requesterUid: requesterUid,
          position: pos,
          hospitalLat: hospitalLat,
          hospitalLng: hospitalLng,
        );
      },
      onError: (e) {
        debugPrint('[TrackingService] Position stream error: $e');
      },
    );

    // Periodic 10-second sync
    _periodicTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        await _writePosition(
          matchId: matchId,
          donorUid: donorUid,
          requesterUid: requesterUid,
          position: pos,
          hospitalLat: hospitalLat,
          hospitalLng: hospitalLng,
        );
      } catch (e) {
        debugPrint('[TrackingService] Periodic GPS sync error: $e');
      }
    });
  }

  Future<void> _writePosition({
    required String matchId,
    required String donorUid,
    required String requesterUid,
    required Position position,
    required double hospitalLat,
    required double hospitalLng,
  }) async {
    final db = _db;
    if (db == null) return;

    final distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      hospitalLat,
      hospitalLng,
    );
    final distanceKm = distanceMeters / 1000.0;
    // Estimate transit duration assuming 40 km/h with 1.2 detour factor
    final transitHours = (distanceKm * 1.2) / 40.0;
    final etaMinutes = math.max(2, (transitHours * 60).ceil());

    final data = <String, dynamic>{
      'matchId': matchId,
      'donorUid': donorUid,
      'requesterUid': requesterUid,
      'donorLocation': {
        'lat': position.latitude,
        'lng': position.longitude,
      },
      'status': 'IN_TRANSIT',
      'distanceKm': double.parse(distanceKm.toStringAsFixed(2)),
      'etaMinutes': etaMinutes,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await db.collection('tracking').doc(matchId).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[TrackingService] Error writing tracking doc: $e');
    }
  }

  /// Stops streaming GPS position.
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _activeMatchId = null;
  }

  /// Stops tracking and deletes tracking document on closed requisition.
  Future<void> closeAndCleanup(String matchId) async {
    await stopTracking();
    final db = _db;
    if (db != null) {
      try {
        await db.collection('tracking').doc(matchId).delete();
      } catch (e) {
        debugPrint('[TrackingService] Error deleting tracking doc: $e');
      }
    }
  }

  /// Live Firestore snapshot stream for tracking document.
  Stream<DocumentSnapshot<Map<String, dynamic>>>? streamTracking(String matchId) {
    return _db?.collection('tracking').doc(matchId).snapshots();
  }

  void dispose() {
    stopTracking();
  }
}
