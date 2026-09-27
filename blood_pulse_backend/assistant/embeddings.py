# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
from django.conf import settings
from google import genai
from google.genai import types

def get_embedding(text: str) -> list[float]:
    """Calls Gemini embedding model and returns a 768-dimensional vector."""
    if not text.strip():
        return []
    
    client = genai.Client(api_key=settings.GEMINI_API_KEY)
    
    response = client.models.embed_content(
        model='gemini-embedding-2',
        contents=text,
        config=types.EmbedContentConfig(
            task_type='RETRIEVAL_DOCUMENT',
            output_dimensionality=768
        )
    )
    return response.embeddings[0].values

def get_query_embedding(query: str) -> list[float]:
    """Calls Gemini embedding model for a search query."""
    if not query.strip():
        return []
    
    client = genai.Client(api_key=settings.GEMINI_API_KEY)
    
    response = client.models.embed_content(
        model='gemini-embedding-2',
        contents=query,
        config=types.EmbedContentConfig(
            task_type='RETRIEVAL_QUERY',
            output_dimensionality=768
        )
    )
    return response.embeddings[0].values

