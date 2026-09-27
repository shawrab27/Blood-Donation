import os, re
out = ""
for file in sorted(os.listdir('api/migrations')):
    if file.endswith('.py') and file.startswith('002'):
        num = int(file[:4])
        if num >= 20:
            with open('api/migrations/'+file, 'r', encoding='utf-8') as f:
                out += f"# {file}\n"
                out += f.read() + "\n\n"
with open('migrations_raw.txt', 'w') as f:
    f.write(out)
