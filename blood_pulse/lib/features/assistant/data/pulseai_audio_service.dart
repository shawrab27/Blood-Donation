// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Audio and Speech Service for PulseAI
/// Supports bn_BD voice recognition with fallback to device locale and English.
/// Provides robust error handling, permission status, and Flutter TTS speech output.
class PulseAIAudioService {
  PulseAIAudioService._();
  static final PulseAIAudioService instance = PulseAIAudioService._();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isSpeechInitialized = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';
  String? _ttsErrorMessage;

  bool get isListening => _isListening;
  String get lastWords => _lastRecognizedWords;
  String? get ttsErrorMessage => _ttsErrorMessage;

  /// Normalizes low-level speech engine error codes into human-readable messages.
  /// Returns null if user spoke words before timeout (normal speech completion).
  static String? normalizeSpeechError(String rawError, String lastWords) {
    final lower = rawError.toLowerCase();
    if (lower.contains('timeout')) {
      if (lastWords.trim().isNotEmpty) {
        return null;
      }
      return 'No speech detected. Please tap the mic and try again.';
    }
    if (lower.contains('no_match') || lower.contains('nomatch')) {
      return "Couldn't catch that. Please speak clearly into the microphone.";
    }
    if (lower.contains('network')) {
      return 'Network issue with voice recognition. You can type your question directly.';
    }
    if (lower.contains('busy')) {
      return 'Voice recognition is busy. Please try again.';
    }
    if (lower.contains('permission') || lower.contains('denied')) {
      return 'Microphone permission is required for voice input.';
    }
    return 'Voice recognition encountered an issue. You can type your question directly.';
  }

  /// Initializes speech-to-text safely without crashing if speech service is unavailable
  Future<bool> initSpeech({
    Function(String errorMsg)? onError,
    Function(String status)? onStatus,
  }) async {
    if (kIsWeb) return false;
    if (_isSpeechInitialized) return true;

    try {
      _isSpeechInitialized = await _speech.initialize(
        onError: (val) {
          _isListening = false;
          final friendly = normalizeSpeechError(val.errorMsg, _lastRecognizedWords);
          if (onError != null && friendly != null) {
            onError(friendly);
          }
        },
        onStatus: (val) {
          if (val == 'done' || val == 'notListening') {
            _isListening = false;
          }
          if (onStatus != null) onStatus(val);
        },
      );
      return _isSpeechInitialized;
    } catch (e) {
      _isSpeechInitialized = false;
      if (onError != null) onError("Speech service unavailable on this device.");
      return false;
    }
  }

  /// Starts listening with bn_BD primary locale and fallback
  Future<void> startListening({
    required Function(String words) onResult,
    required Function(String error) onError,
  }) async {
    if (kIsWeb) {
      onError("Voice input is not supported on web.");
      return;
    }

    final available = await initSpeech(onError: onError);
    if (!available) {
      onError("Microphone permission denied or speech service unavailable.");
      return;
    }

    try {
      // Find available locales for bn_BD fallback
      var targetLocale = 'bn_BD';
      try {
        final locales = await _speech.locales();
        final hasBn = locales.any((l) => l.localeId.startsWith('bn'));
        if (!hasBn) {
          final hasEn = locales.any((l) => l.localeId.startsWith('en'));
          targetLocale = hasEn ? 'en_US' : (locales.isNotEmpty ? locales.first.localeId : 'bn_BD');
        }
      } catch (_) {
        targetLocale = 'bn_BD';
      }

      _isListening = true;
      _lastRecognizedWords = '';

      await _speech.listen(
        localeId: targetLocale,
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          onResult(result.recognizedWords);
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      );
    } catch (e) {
      _isListening = false;
      final friendly = normalizeSpeechError(e.toString(), _lastRecognizedWords);
      if (friendly != null) onError(friendly);
    }
  }

  /// Stops listening
  Future<void> stopListening() async {
    if (!_isListening) return;
    try {
      await _speech.stop();
    } catch (_) {}
    _isListening = false;
  }

  /// Speaks text via TTS. Checks for Bangla voice presence; reports install hint if missing.
  Future<void> speakText(
    String text, {
    String lang = 'bn',
    required Function(String? warningHint) onVoiceCheck,
  }) async {
    if (kIsWeb) return;
    try {
      await _flutterTts.stop();

      // Check available voices/languages
      final languages = await _flutterTts.getLanguages;
      final langList = languages is List ? languages.map((e) => e.toString().toLowerCase()).toList() : <String>[];

      bool hasBnBd = langList.any((l) => l.contains('bn-bd') || l.contains('bn_bd'));
      bool hasBnIn = langList.any((l) => l.contains('bn-in') || l.contains('bn_in'));
      bool supportsBn = hasBnBd || hasBnIn || langList.any((l) => l.contains('bn') || l.contains('ben'));

      final bool containsBengaliScript = RegExp(r'[\u0980-\u09FF]').hasMatch(text);

      if (lang == 'bn' || containsBengaliScript) {
        if (supportsBn) {
          final targetLang = hasBnBd ? "bn-BD" : (hasBnIn ? "bn-IN" : "bn-BD");
          await _flutterTts.setLanguage(targetLang);
          onVoiceCheck(null);
          await _flutterTts.setPitch(1.0);
          await _flutterTts.setSpeechRate(0.5);
          await _flutterTts.speak(text);
        } else {
          // Bangla TTS voice missing: report clear actionable install guidance
          onVoiceCheck("Bangla voice not installed on device. Install 'Bangla (Bangladesh)' TTS in Settings > Accessibility > Text-to-Speech.");
        }
      } else {
        await _flutterTts.setLanguage("en-US");
        onVoiceCheck(null);
        await _flutterTts.setPitch(1.0);
        await _flutterTts.setSpeechRate(0.5);
        await _flutterTts.speak(text);
      }
    } catch (e) {
      onVoiceCheck("Text-to-speech service error.");
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }
}
