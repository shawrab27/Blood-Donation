import os
import re

filepath = 'lib/features/health_hub/domain/providers/health_hub_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace emergencyContactsProvider with hospitalsDirectoryProvider
old_provider = '''final emergencyContactsProvider = FutureProvider<List<EmergencyContact>>((ref) async {
  final response = await http.get(Uri.parse('/emergency-contacts/'));
  if (response.statusCode == 200) {
    final List data = json.decode(response.body);
    return data.map((e) => EmergencyContact.fromJson(e)).toList();
  }
  throw Exception('Failed to load emergency contacts');
});'''

new_provider = '''import '../../blood_hub/data/blood_hub_api_service.dart';

final hospitalsDirectoryProvider = FutureProvider<List<HospitalModel>>((ref) async {
  final cleanBase = _apiBase.endsWith('/') ? _apiBase.substring(0, _apiBase.length - 1) : _apiBase;
  final response = await http.get(Uri.parse('/hospitals/'));
  if (response.statusCode == 200) {
    final Map<String, dynamic> decoded = json.decode(utf8.decode(response.bodyBytes));
    final List<dynamic> data = decoded.containsKey('results') ? decoded['results'] : decoded;
    return data.map((e) => HospitalModel.fromJson(e)).toList();
  }
  throw Exception('Failed to load hospitals');
});'''

content = content.replace(old_provider, new_provider)

# Fix the healthAccessoriesProvider _baseUrl bug I introduced earlier if present
if "Uri.parse('/health-accessories/')" in content:
    content = content.replace("Uri.parse('/health-accessories/')", "Uri.parse('/health-accessories/')")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated provider.")
