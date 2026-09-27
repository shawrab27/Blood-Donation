import re

with open("blood_pulse/lib/services/api_client.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Find everything from `  // â”€â”€ Helpers â”€â”€` to `  Future<Map<String, String>> _getAuthHeaders()`
replacement = """  // â”€â”€ Helpers â”€â”€
  
  String _normalizeUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    
    var base = baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    
    if (path.startsWith('/')) path = path.substring(1);
    if (path.startsWith('api/')) path = path.substring(4);
    if (path.startsWith('/')) path = path.substring(1);
    
    return '$base/api/$path';
  }

  Future<Map<String, String>> _getAuthHeaders()"""

content = re.sub(r'  // ─+ Helpers ─+.*?  Future<Map<String, String>> _getAuthHeaders\(\)', replacement, content, flags=re.DOTALL)

with open("blood_pulse/lib/services/api_client.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Replaced Helpers cleanly")
