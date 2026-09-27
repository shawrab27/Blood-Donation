import re

with open("blood_pulse/lib/services/api_client.dart", "r", encoding="utf-8") as f:
    content = f.read()

replacement = """  String _normalizeUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    var base = baseUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    
    // Remove both leading / and leading api/ if present to prevent duplication
    if (path.startsWith('/')) path = path.substring(1);
    if (path.startsWith('api/')) path = path.substring(4);
    if (path.startsWith('/')) path = path.substring(1);
    
    return '$base/api/$path';
  }"""

# Need to find the exact existing _normalizeUrl function block and replace it
# Since there might be trailing code from a bad previous replace, let's just do a string replace of the entire block.
content = re.sub(r'String _normalizeUrl\(String path\).*?return.*?\}', replacement, content, flags=re.DOTALL)

with open("blood_pulse/lib/services/api_client.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Fixed _normalizeUrl")
