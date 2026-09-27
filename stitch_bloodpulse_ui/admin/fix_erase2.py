with open('donor-management.html', 'r', encoding='utf-8') as f:
    text = f.read()

bad_onclick = """onclick="alert('Executing irreversible anonymization protocol for UID #D-<span id="modal-donor-uid"></span>. Event logged.'); document.getElementById('eraseModalOverlay').style.display='none';" """

text = text.replace(bad_onclick, 'id="confirm-erase-btn" ')

with open('donor-management.html', 'w', encoding='utf-8') as f:
    f.write(text)
