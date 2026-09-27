import re

with open("blood_pulse/lib/main.dart", "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace("dummy_token_123", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ0b2tlbl90eXBlIjoiYWNjZXNzIiwiZXhwIjoxNzkwMzkxNDY2LCJpYXQiOjE3OTAzOTA1NjYsImp0aSI6IjEwY2JkNTYwYjFkNDRmMzU4ODM5OTM3ZjBhNjk5MDU5IiwidXNlcl9pZCI6IjEifQ.Fl43zkoWUfJb3qcpkKL0LpKw0JHN7jFGwjkup-VdWYM")

with open("blood_pulse/lib/main.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Injected valid JWT")
