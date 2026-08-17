import 'dart:async';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OtpState {
  const OtpState({
    this.primaryPhone = '',
    this.secondaryPhone,
    this.sentToPhone = '',
    this.correctCode = '',
    this.isSending = false,
    this.primaryFailed = false,
    this.isVerified = false,
    this.countdownSeconds = 30,
    this.error,
    this.bypassAvailable = false,
  });

  final String primaryPhone;
  final String? secondaryPhone;
  final String sentToPhone;
  final String correctCode;
  final bool isSending;
  final bool primaryFailed;
  final bool isVerified;
  final int countdownSeconds;
  final String? error;
  final bool bypassAvailable;

  OtpState copyWith({
    String? primaryPhone,
    String? secondaryPhone,
    String? sentToPhone,
    String? correctCode,
    bool? isSending,
    bool? primaryFailed,
    bool? isVerified,
    int? countdownSeconds,
    String? error,
    bool? bypassAvailable,
  }) {
    return OtpState(
      primaryPhone:     primaryPhone     ?? this.primaryPhone,
      secondaryPhone:   secondaryPhone   ?? this.secondaryPhone,
      sentToPhone:      sentToPhone      ?? this.sentToPhone,
      correctCode:      correctCode      ?? this.correctCode,
      isSending:        isSending        ?? this.isSending,
      primaryFailed:    primaryFailed    ?? this.primaryFailed,
      isVerified:       isVerified       ?? this.isVerified,
      countdownSeconds: countdownSeconds ?? this.countdownSeconds,
      error:            error            ?? this.error,
      bypassAvailable:  bypassAvailable  ?? this.bypassAvailable,
    );
  }
}

class OtpNotifier extends StateNotifier<OtpState> {
  OtpNotifier() : super(const OtpState());

  Timer? _timer;

  void startCountdown() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.countdownSeconds > 0) {
        state = state.copyWith(countdownSeconds: state.countdownSeconds - 1);
        // Turn on bypass option after 5 seconds to simulate server exception option
        if (state.countdownSeconds <= 25 && !state.bypassAvailable) {
          state = state.copyWith(bypassAvailable: true);
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  /// Sends OTP to primary number, with simulated timeout & automatic secondary rerouting.
  Future<void> sendOtp({
    required String primaryPhone,
    String? secondaryPhone,
    bool forcePrimaryFailure = false,
  }) async {
    _timer?.cancel();
    state = OtpState(
      primaryPhone: primaryPhone,
      secondaryPhone: secondaryPhone,
      isSending: true,
      countdownSeconds: 30,
    );

    // Simulated short delay for network request
    await Future.delayed(const Duration(milliseconds: 1000));

    final code = _generateCode();
    // Simulate primary number failure if selected or if forcePrimaryFailure is true
    if (forcePrimaryFailure || primaryPhone.endsWith('999')) {
      // Primary fails! Reroute to secondary if available
      if (secondaryPhone != null && secondaryPhone.trim().isNotEmpty) {
        state = state.copyWith(
          sentToPhone: secondaryPhone,
          correctCode: code,
          isSending: false,
          primaryFailed: true,
          error: 'Primary number unreachable. Rerouting OTP to secondary number...',
        );
      } else {
        state = state.copyWith(
          sentToPhone: primaryPhone,
          correctCode: code,
          isSending: false,
          primaryFailed: true,
          error: 'Primary number unreachable. No secondary number provided.',
        );
      }
    } else {
      // Primary succeeds
      state = state.copyWith(
        sentToPhone: primaryPhone,
        correctCode: code,
        isSending: false,
        primaryFailed: false,
      );
    }
    startCountdown();
  }

  /// Validates entered OTP code.
  bool verifyCode(String code) {
    if (code == state.correctCode || code == '1234' /* test bypass code */) {
      state = state.copyWith(isVerified: true, error: null);
      _timer?.cancel();
      return true;
    } else {
      state = state.copyWith(error: 'Invalid OTP code. Please try again.');
      return false;
    }
  }

  void reset() {
    _timer?.cancel();
    state = const OtpState();
  }

  String _generateCode() {
    final rand = Random();
    return (1000 + rand.nextInt(9000)).toString(); // 4 digit code
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final otpStateProvider =
    StateNotifierProvider<OtpNotifier, OtpState>((ref) => OtpNotifier());
