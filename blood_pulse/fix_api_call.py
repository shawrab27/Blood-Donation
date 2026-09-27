import re

with open("lib/services/fcm_service.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = """        debugPrint('â•‘ Token: $token');
        debugPrint('â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•\\n');
      } catch (e) {
        debugPrint('[FCM] token fetch error: $e');
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] token refreshed: $newToken');
      });"""

# Because of character encoding issues in PowerShell printing, it's safer to use regex targeting `debugPrint('🔑 Token: $token');`
content_re = re.sub(
    r"debugPrint\('🔑 Token: \$token'\);.*?catch \(e\)",
    r"debugPrint('🔑 Token: $token');\n        if (token != null) {\n          try {\n            await ApiClient().post('/api/donors/me/fcm-token/', body: {'token': token});\n            debugPrint('[FCM] Token registered with Django backend.');\n          } catch (apiErr) {\n            debugPrint('[FCM] Failed to register token with backend: $apiErr');\n          }\n        }\n      } catch (e)",
    content,
    flags=re.DOTALL
)

content_re = re.sub(
    r"FirebaseMessaging\.instance\.onTokenRefresh\.listen\(\(newToken\) \{.*?\}\);",
    r"FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {\n        debugPrint('[FCM] token refreshed: $newToken');\n        try {\n          await ApiClient().post('/api/donors/me/fcm-token/', body: {'token': newToken});\n        } catch (apiErr) {}\n      });",
    content_re,
    flags=re.DOTALL
)

with open("lib/services/fcm_service.dart", "w", encoding="utf-8") as f:
    f.write(content_re)
print("Updated successfully")
