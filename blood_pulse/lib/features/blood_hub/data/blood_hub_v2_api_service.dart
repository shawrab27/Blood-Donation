// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/api_client.dart';

/// Permanent service for BloodPulse Blood Hub v2 lifecycle endpoints.
/// Enforces clean HTTP calls, JSON serialization, and Riverpod integration.
class BloodHubV2ApiService {
  BloodHubV2ApiService(this._api);

  final ApiClient _api;

  /// POST /api/requests/
  /// Creates a draft requisition.
  Future<Map<String, dynamic>> createDraftRequest(Map<String, dynamic> data) async {
    final response = await _api.post('requests/', body: data);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? err.toString());
  }

  /// POST `/api/requests/<id>/send-otp/`
  Future<Map<String, dynamic>> sendOtp(int requestId, {String? email}) async {
    final body = <String, dynamic>{
      if (email != null && email.isNotEmpty) 'email': email,
    };
    final response = await _api.post('requests/$requestId/send-otp/', body: body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? err['error'] ?? 'Failed to send OTP');
  }

  /// POST `/api/requests/<id>/verify-otp/`
  Future<Map<String, dynamic>> verifyOtp(int requestId, String otp) async {
    final response = await _api.post(
      'requests/$requestId/verify-otp/',
      body: {'otp': otp.trim()},
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? err['error'] ?? 'OTP verification failed');
  }

  /// POST `/api/requests/<id>/accept/`
  Future<Map<String, dynamic>> acceptRequest(int requestId) async {
    final response = await _api.post('requests/$requestId/accept/');
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? err.toString());
  }

  /// POST `/api/matches/<id>/status/`
  /// Allowed statuses: ON_THE_WAY, ARRIVED, DONATED
  Future<Map<String, dynamic>> updateMatchStatus(
    int matchId,
    String status, {
    String? note,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final response = await _api.post('matches/$matchId/status/', body: body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? err['error'] ?? 'Status update failed');
  }

  /// POST `/api/matches/<id>/report/`
  /// Reason: MEDICAL | NO_SHOW | LOGISTICS
  Future<Map<String, dynamic>> reportMatchFailure(
    int matchId,
    String reason,
    String note,
  ) async {
    final body = <String, dynamic>{
      'reason': reason.toUpperCase(),
      'note': note,
    };
    final response = await _api.post('matches/$matchId/report/', body: body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? err['reason'] ?? 'Reporting failure failed');
  }

  /// POST `/api/matches/<id>/thanks/`
  Future<Map<String, dynamic>> sendThankYouLetter(
    int matchId,
    String templateKey,
    String body,
  ) async {
    final payload = <String, dynamic>{
      'template_key': templateKey,
      'body': body.trim(),
    };
    final response = await _api.post('matches/$matchId/thanks/', body: payload);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? err['body'] ?? 'Failed to send thank you letter');
  }

  /// POST `/api/followups/<id>/answer/`
  Future<Map<String, dynamic>> answerFollowUp(
    int followupId,
    String responseVal, {
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'response': responseVal,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final response = await _api.post('followups/$followupId/answer/', body: payload);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? err['response'] ?? 'Failed to answer follow-up');
  }

  /// GET `/api/requests/<id>/poster-data/`
  Future<Map<String, dynamic>> fetchPosterData(int requestId) async {
    final response = await _api.get('requests/$requestId/poster-data/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Failed to fetch poster data');
  }

  /// GET `/api/requests/<id>/`
  Future<Map<String, dynamic>> fetchRequestDetail(int requestId) async {
    final response = await _api.get('requests/$requestId/');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Requisition not found');
  }
}

final bloodHubV2ApiServiceProvider = Provider<BloodHubV2ApiService>((ref) {
  return BloodHubV2ApiService(ApiClient());
});
