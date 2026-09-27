# BloodPulse Assistant Admin Guide

## Overview
The Assistant relies on an admin-curated Knowledge Base (KB) and App Guide to safely answer user queries without hallucinating medical advice.

## Managing the Knowledge Base (KB)

1. **Creating Entries:**
   Navigate to `Assistant > Kb entrys`. When you create a new entry, its status defaults to `DRAFT`.
   **The Assistant will NOT use `DRAFT` entries to answer questions.**
   
2. **Approving Entries:**
   To make an entry live:
   - Select it from the list.
   - Choose the Action: "Approve selected entries".
   - Click "Go".
   - This bumps the internal version, invalidates the NLP cache, and makes the entry immediately available to the AI.
   
3. **Content Constraints:**
   - Both English and Bangla text bodies should be concise, ideally under 120 words.
   - Avoid numerical guesswork. The Assistant uses a strict Guard: if it attempts to quote a number or duration (like 120 days) that doesn't exist explicitly in your KB text, the output is blocked.

## Managing the App Guide
Similar to the KB, App Guide entries provide instructions for using the BloodPulse app (e.g., "How to verify identity"). They also require Admin approval before the AI can serve them.

## Support Tickets & Handoffs
When the AI falls back, or when a user clicks "Contact Support", a Support Ticket is generated.
- Access via `Assistant > Support tickets`.
- Update the status from `OPEN` to `IN PROGRESS` to `CLOSED`.

## Assistant Stats
Go to `Assistant > Assistant Stats` to view:
- Total Messages Processed
- Fallback Rate (times the AI could not answer and fell back to simple keyword matching)
- Blocked Number Rate (times the AI tried to invent a number/duration and was caught by the guard)
- Thumbs Down Rate (negative user feedback)

## PII Redaction
By default, the pipeline scrubs BD Phone numbers, Emails, and NID-like strings before logging or sending them to Gemini. You will never see these in the AssistantMessage logs unless explicitly consented by the user (and even then, only redacted). Logs are retained for 30 days max.
