import 'dart:io';
void main() {
    var content = File('blood_pulse/lib/features/blood_request/presentation/screens/emergency_request_screen.dart').readAsStringSync();
    content = content.replaceAll(RegExp(r'if \(_aiResult == null\) \{.*?\}', dotAll: true), '');
    content = content.replaceAll(RegExp(r'if \(!_aiResult!.isApproved\) \{.*?\}', dotAll: true), '');
    content = content.replaceAll(RegExp(r'if \(_aiResult == null\) \.\.\.\[.*?\] else \.\.\.\[.*?\]', dotAll: true), 'const SizedBox(),');
    content = content.replaceAll(RegExp(r'\$\{(?:_aiResult!)?\.trustScorePercentage.*?\}'), '85');
    content = content.replaceAll('_aiResult', 'null');
    File('blood_pulse/lib/features/blood_request/presentation/screens/emergency_request_screen.dart').writeAsStringSync(content);
}
