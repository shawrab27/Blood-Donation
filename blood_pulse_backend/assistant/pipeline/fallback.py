# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from assistant.models import KBEntry

def get_fallback_response(user_message: str) -> dict:
    # A simple trigram or keyword overlap since pg_trgm is not applied yet.
    # We will just do a basic word overlap for now on approved entries.
    words = set(user_message.lower().split())
    
    entries = KBEntry.objects.filter(status='APPROVED')
    scored = []
    for entry in entries:
        title_words = set(entry.title_en.lower().split() + entry.title_bn.split())
        overlap = len(words.intersection(title_words))
        if overlap > 0:
            scored.append((overlap, entry))
            
    scored.sort(key=lambda x: x[0], reverse=True)
    top_3 = [x[1] for x in scored[:3]]
    
    titles = "\n".join([f"- {e.title_en} / {e.title_bn}" for e in top_3])
    
    reply = "I am currently unable to process your request. "
    if titles:
        reply += f"Here are some topics that might help:\n{titles}\n\n"
        
    reply += "For emergencies, please call 999 or 16163."
    
    return {
        "reply": reply,
        "language": "en",
        "action_ids": ["contact_support"],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": True,
        "kb_ids_used": [],
        "flags": ["FALLBACK"]
    }
