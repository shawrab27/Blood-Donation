# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from assistant.pipeline.shortcuts import evaluate_shortcuts
from assistant.embeddings import get_query_embedding
from assistant.models import KBEntry
from pgvector.django import CosineDistance

def route_query(text: str, user=None):
    """
    Routes a query to Track A, Track B, or Track C.
    """
    # Tracks A & B: Deterministic shortcuts (greetings, days-until-eligible, nearest hospital)
    shortcut_res = evaluate_shortcuts(text, user)
    if shortcut_res:
        return {"track": "A_B", "response": shortcut_res}
    
    # Track C: Semantic Search
    query_emb = get_query_embedding(text)
    if not query_emb:
        return {"track": "C", "matches": []}
        
    # Get top 3 by cosine similarity from APPROVED rows
    matches = KBEntry.objects.filter(
        status='APPROVED',
        embedding__isnull=False
    ).annotate(
        distance=CosineDistance('embedding', query_emb)
    ).order_by('distance')[:3]
    
    return {"track": "C", "matches": list(matches)}
