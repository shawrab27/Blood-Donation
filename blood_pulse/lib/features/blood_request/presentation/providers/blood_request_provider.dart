import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/api_client.dart';

class BloodRequestItem {
  final int? id;
  final String patientName;
  final String bloodGroup;
  final String urgencyLevel;
  final String hospitalLocation;
  final String contactNumber;
  final String? createdAt;
  final bool isActive;

  const BloodRequestItem({
    this.id,
    required this.patientName,
    required this.bloodGroup,
    required this.urgencyLevel,
    required this.hospitalLocation,
    required this.contactNumber,
    this.createdAt,
    this.isActive = true,
  });

  factory BloodRequestItem.fromJson(Map<String, dynamic> json) {
    return BloodRequestItem(
      id: json['id'] as int?,
      patientName: json['patient_name'] ?? '',
      bloodGroup: json['blood_group'] ?? '',
      urgencyLevel: json['urgency_level'] ?? 'Emergency',
      hospitalLocation: json['hospital_location'] ?? '',
      contactNumber: json['contact_number'] ?? '',
      createdAt: json['created_at'] as String?,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'patient_name': patientName,
        'blood_group': bloodGroup,
        'urgency_level': urgencyLevel,
        'hospital_location': hospitalLocation,
        'contact_number': contactNumber,
        if (id != null) 'id': id,
        'is_active': isActive,
      };
}

class BloodRequestState {
  final List<BloodRequestItem> requests;
  final bool isLoading;
  final String? errorMessage;

  const BloodRequestState({
    this.requests = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  BloodRequestState copyWith({
    List<BloodRequestItem>? requests,
    bool? isLoading,
    String? errorMessage,
  }) {
    return BloodRequestState(
      requests: requests ?? this.requests,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class BloodRequestNotifier extends StateNotifier<BloodRequestState> {
  final ApiClient _apiClient;

  BloodRequestNotifier({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(),
        super(const BloodRequestState()) {
    fetchActiveRequests();
  }

  Future<void> fetchActiveRequests() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final response = await _apiClient.get('requests/');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final list = data
            .map((e) => BloodRequestItem.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(requests: list, isLoading: false);
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load requests (${response.statusCode})',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<bool> createRequest({
    required String patientName,
    required String bloodGroup,
    required String urgencyLevel,
    required String hospitalLocation,
    required String contactNumber,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final payload = {
      'patient_name': patientName,
      'blood_group': bloodGroup,
      'urgency_level': urgencyLevel,
      'hospital_location': hospitalLocation,
      'contact_number': contactNumber,
    };

    try {
      final response = await _apiClient.post('requests/', body: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchActiveRequests();
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to create request: ${response.body}',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

final bloodRequestProvider =
    StateNotifierProvider<BloodRequestNotifier, BloodRequestState>(
        (ref) => BloodRequestNotifier());
