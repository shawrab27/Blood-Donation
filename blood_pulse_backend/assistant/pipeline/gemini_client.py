# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import json
import time
import logging
from google import genai
from google.genai import types
from pydantic import BaseModel, Field
from assistant.conf import GEMINI_MODEL, TEMPERATURE, MAX_OUTPUT_TOKENS, GEMINI_TIMEOUT_SECONDS

logger = logging.getLogger(__name__)

class AssistantReplySchema(BaseModel):
    reply: str
    language: str = Field(description="'bn' or 'en'")
    action_ids: list[str] = Field(default_factory=list)
    emergency: bool = False
    out_of_scope: bool = False
    needs_human: bool = False
    kb_ids_used: list[int] = Field(default_factory=list)

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
    
    # Model fallback candidates in order of speed and stability
    candidate_models = []
    primary_model = os.environ.get('GEMINI_MODEL') or GEMINI_MODEL or 'gemini-flash-lite-latest'
    candidate_models.append(primary_model)
    for fallback in ['gemini-flash-lite-latest', 'gemini-3.5-flash', 'gemini-3.8-flash']:
        if fallback not in candidate_models:
            candidate_models.append(fallback)

    last_error = None
    for model_name in candidate_models:
        try:
            start_time = time.time()
            response = client.models.generate_content(
                model=model_name,
                contents=contents,
                config=config,
            )
            latency_ms = int((time.time() - start_time) * 1000)
            
            # Parse JSON schema response
            result_json = json.loads(response.text)
            
            tokens_in = response.usage_metadata.prompt_token_count if response.usage_metadata else 0
            tokens_out = response.usage_metadata.candidates_token_count if response.usage_metadata else 0
            
            return {
                "json": result_json,
                "latency_ms": latency_ms,
                "tokens_in": tokens_in,
                "tokens_out": tokens_out,
                "model_used": model_name
            }
        except Exception as e:
            last_error = e
            err_str = str(e)
            logger.warning(f"Gemini call with model '{model_name}' failed: {err_str}")
            # Try next candidate model immediately without hanging
            continue

    if last_error:
        raise last_error
    raise RuntimeError("All Gemini model candidates failed to respond.")
