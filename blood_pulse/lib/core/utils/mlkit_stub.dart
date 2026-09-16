/// Stub for google_mlkit_text_recognition on web/desktop platforms.
/// ML Kit OCR is only supported on Android and iOS.
/// This file satisfies the conditional import so the project compiles
/// on web without needing the native ML Kit plugin.
library;

/// Placeholder script enum — never instantiated on web.
enum TextRecognitionScript { latin }

/// Stub recognizer — never called on web (guarded by kIsWeb + Platform check).
class TextRecognizer {
  TextRecognizer({required TextRecognitionScript script});
  Future<RecognizedText> processImage(InputImage image) async => RecognizedText('');
  Future<void> close() async {}
}

class RecognizedText {
  RecognizedText(this.text);
  final String text;
}

class InputImage {
  InputImage._();
  static InputImage fromFilePath(String path) => InputImage._();
}
