import re

with open('trust-fraud-engine.html', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('cases//approve', 'cases/${id}/approve')
text = text.replace('cases//reject', 'cases/${id}/reject')
text = text.replace('req-row-"', 'req-row-${item.id}"')
text = text.replace('>Score: </span>', '>Score: ${item.trust_score}</span>')
text = text.replace('>Req # &bull;', '>Req #${item.id} &bull;')
text = text.replace('text-xs shrink-0\"></div>', 'text-xs shrink-0\">${item.blood_group}</div>')
text = text.replace('text-[#2B2B2B]\"></span>', 'text-[#2B2B2B]\">${item.patient_name}</span>')
text = text.replace('approveRequest()', 'approveRequest(${item.id})')
text = text.replace('rejectRequest()', 'rejectRequest(${item.id})')
text = text.replace('openBanModal()', 'openBanModal(${item.requester_id})')

text = text.replace('>Approve (Restore)</button>', '><span class=\"material-symbols-outlined text-[14px]\">check</span> Approve</button>')
text = text.replace('>Reject Request</button>', '><span class=\"material-symbols-outlined text-[14px]\">close</span> Reject</button>')
text = text.replace('>Permanent Ban</button>', '><span class=\"material-symbols-outlined text-[14px]\">gavel</span> Ban</button>')

with open('trust-fraud-engine.html', 'w', encoding='utf-8') as f:
    f.write(text)

print("Finished fixing variables.")
