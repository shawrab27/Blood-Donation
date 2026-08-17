class SecurityUtils {
  static bool validateBangladeshPhone(String phone) {
    final RegExp regex = RegExp(r'^(?:\+8801)[3-9]\d{8}$');
    return regex.hasMatch(phone);
  }

  static String generateDigitalSignature(String userId) {
    return 'SIG-${DateTime.now().millisecondsSinceEpoch}-$userId';
  }
}
