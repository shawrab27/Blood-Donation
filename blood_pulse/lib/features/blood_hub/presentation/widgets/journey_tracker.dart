// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../data/blood_hub_api_service.dart';

class JourneyLiveTracker extends ConsumerStatefulWidget {
  final int journeyId;
  final bool isTracking;
  final VoidCallback onStopTracking;

  const JourneyLiveTracker({
    super.key,
    required this.journeyId,
    required this.isTracking,
    required this.onStopTracking,
  });

  @override
  ConsumerState<JourneyLiveTracker> createState() => _JourneyLiveTrackerState();
}

class _JourneyLiveTrackerState extends ConsumerState<JourneyLiveTracker> {
  StreamSubscription<Position>? _positionStream;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    if (widget.isTracking) {
      _startTracking();
    }
  }

  @override
  void didUpdateWidget(covariant JourneyLiveTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isTracking != oldWidget.isTracking) {
      if (widget.isTracking) {
        _startTracking();
      } else {
        _stopTracking();
      }
    }
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _startTracking() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return;
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25, // only update if moved at least 25 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      final now = DateTime.now();
      // Also enforce at most every 10s
      if (_lastUpdate == null || now.difference(_lastUpdate!).inSeconds >= 10) {
        _lastUpdate = now;
        _sendLocationToBackend(position);
      }
    });
    
    // Timer to enforce max 60s without update (if stationary)
    Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (!widget.isTracking || !mounted) {
        timer.cancel();
        return;
      }
      if (_lastUpdate == null || DateTime.now().difference(_lastUpdate!).inSeconds >= 60) {
        try {
          final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          _lastUpdate = DateTime.now();
          _sendLocationToBackend(pos);
        } catch (_) {}
      }
    });
  }

  void _stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _sendLocationToBackend(Position position) async {
    try {
      await ref.read(bloodHubApiServiceProvider).updateJourneyLocation(
        widget.journeyId,
        position.latitude,
        position.longitude,
      );
    } catch (_) {
      // Silently fail if network is down
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isTracking) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.green.shade50,
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Sharing live location',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                color: Colors.green,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: widget.onStopTracking,
            child: const Text(
              'Stop',
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
