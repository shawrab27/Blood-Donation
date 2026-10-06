# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import json
import time
from google import genai
from google.genai import types
from pydantic import BaseModel, Field
from assistant.conf import GEMINI_MODEL, TEMPERATURE, MAX_OUTPUT_TOKENS, GEMINI_TIMEOUT_SECONDS

class AssistantReplySchema(BaseModel):
    reply: str
    language: str = Field(description="'bn' or 'en'")
    action_ids: list[str]
    emergency: bool
    out_of_scope: bool
    needs_human: bool
    kb_ids_used: list[int]

def get_system_instruction() -> str:
    path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'prompts', 'system.md')
    with open(path, 'r', encoding='utf-8') as f:
        return f.read()

def format_kb_context(kb_entries, guide_entries) -> str:
    parts = []
    if kb_entries:
        parts.append("KNOWLEDGE BASE:")
        for kb in kb_entries:
            parts.append(f"[{kb.id}] {kb.title_en} / {kb.title_bn}: {kb.body_en} | {kb.body_bn}")
    if guide_entries:
        parts.append("APP GUIDE:")
        for g in guide_entries:
            parts.append(f"[{g.id}] {g.title_en} / {g.title_bn}: {g.body_en} | {g.body_bn}")
    return "\n".join(parts)

def call_gemini(user_message: str, history, kb_entries, guide_entries, temperature=None):
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY not set")
        
    client = genai.Client(api_key=api_key)
    
    system_instruction = get_system_instruction()
    kb_context = format_kb_context(kb_entries, guide_entries)
    
    contents = []
    if kb_context:
        contents.append(types.Content(role="user", parts=[types.Part.from_text(text=f"Context:\n{kb_context}")]))
        contents.append(types.Content(role="model", parts=[types.Part.from_text(text="Context received.")]))
        
    for msg in history:
        contents.append(types.Content(role=msg.role, parts=[types.Part.from_text(text=msg.text_redacted)]))
        
    contents.append(types.Content(role="user", parts=[types.Part.from_text(text=user_message)]))
    
    # Configure request
    temp = temperature if temperature is not None else TEMPERATURE
    config = types.GenerateContentConfig(
        system_instruction=system_instruction,
        temperature=temp,
        max_output_tokens=MAX_OUTPUT_TOKENS,
        response_mime_type="application/json",
        response_schema=AssistantReplySchema,
    )
    
    # Attempt generation with exponential backoff retry on 503/429
    max_attempts = 4
    for attempt in range(max_attempts):
        try:
            start_time = time.time()
            response = client.models.generate_content(
                model=GEMINI_MODEL,
                contents=contents,
                config=config,
            )
            latency_ms = int((time.time() - start_time) * 1000)
            
            # Use response.text because it will be JSON mapped to the schema
            result_json = json.loads(response.text)
            
            # Approximate tokens from usage_metadata if available
            tokens_in = response.usage_metadata.prompt_token_count if response.usage_metadata else 0
            tokens_out = response.usage_metadata.candidates_token_count if response.usage_metadata else 0
            
            return {
                "json": result_json,
                "latency_ms": latency_ms,
                "tokens_in": tokens_in,
                "tokens_out": tokens_out
            }
            
        except Exception as e:
            # Catch rate limit or temporary server capacity spikes (429/503)
            err_str = str(e)
            if attempt < max_attempts - 1 and ("429" in err_str or "503" in err_str or "Too Many Requests" in err_str or "UNAVAILABLE" in err_str):
                backoff = (attempt + 1) * 2.0
                time.sleep(backoff)
                continue
            raise e

