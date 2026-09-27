import os

filepath = 'lib/features/health_hub/domain/providers/health_hub_provider.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

new_provider = '''
final healthAccessoriesProvider = FutureProvider<List<HealthAccessory>>((ref) async {
  final response = await http.get(Uri.parse('/health-accessories/'));
  if (response.statusCode == 200) {
    final Map<String, dynamic> decoded = json.decode(response.body);
    final List<dynamic> data = decoded.containsKey('results') ? decoded['results'] : decoded;
    return data.map((e) => HealthAccessory.fromJson(e)).toList();
  }
  throw Exception('Failed to load health accessories');
});
'''
# Ensure we import HealthAccessory
if 'health_accessory_model.dart' not in content:
    content = "import '../models/health_accessory_model.dart';\n" + content

content += new_provider

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
