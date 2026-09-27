import re
with open("blood_pulse/lib/main.dart", "r", encoding="utf-8") as f:
    c = f.read()
# just wipe the test token injection
c = c.replace("""  // INJECTED TEST TOKEN
  const storage = FlutterSecureStorage();
  await storage.write(key: 'bp_jwt_access_token', value: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzkwMzkxNDY2LCJpYXQiOjE3OTAzOTA1NjYsImp0aSI6IjEwY2JkNTYwYjFkNDRmMzU4ODM5OTM3ZjBhNjk5MDU5IiwidXNlcl9pZCI6IjEifQ.Fl43zkoWUfJb3qcpkKL0LpKw0JHN7jFGwjkup-VdWYM');
""", "")
with open("blood_pulse/lib/main.dart", "w", encoding="utf-8") as f:
    f.write(c)
