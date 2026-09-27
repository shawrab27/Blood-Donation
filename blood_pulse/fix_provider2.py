import os

filepath = 'lib/features/health_hub/domain/providers/health_hub_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# We will just append hospitalsDirectoryProvider to the file since emergencyContactsProvider was probably not there or string didn't match.
if 'hospitalsDirectoryProvider' not in content:
    new_provider = '''
import '../../blood_hub/data/blood_hub_api_service.dart';

final hospitalsDirectoryProvider = FutureProvider<List<HospitalModel>>((ref) async {
  final cleanBase = _apiBase.endsWith('/') ? _apiBase.substring(0, _apiBase.length - 1) : _apiBase;
  final response = await http.get(Uri.parse('/hospitals/'));
  if (response.statusCode == 200) {
    final Map<String, dynamic> decoded = json.decode(utf8.decode(response.bodyBytes));
    final List<dynamic> data = decoded.containsKey('results') ? decoded['results'] : decoded;
    return data.map((e) => HospitalModel.fromJson(e)).toList();
  }
  throw Exception('Failed to load hospitals');
});
'''
    content += new_provider
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Provider appended.")
else:
    print("Provider already exists.")
