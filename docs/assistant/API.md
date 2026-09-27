# BloodPulse Assistant API Guide

## Overview
All endpoints require authentication (Bearer token).

## Endpoints

### 1. Chat
**POST /api/assistant/chat/**

**Payload:**
```json
{
  "message": "When can I donate blood?",
  "conversation_id": 1, // Optional, omits for new conversation
  "locale": "en"
}
```

**Response:**
```json
{
  "conversation_id": 1,
  "message_id": 10,
  "reply": "You can donate blood every 120 days. According to your profile, you are eligible to donate today!",
  "language": "en",
  "actions": [
    {
      "id": "open_profile",
      "label_en": "Profile",
      "label_bn": "প্রোফাইল",
      "route": "/profile"
    }
  ],
  "emergency": False,
  "needs_human": False,
  "flags": [] // Possible values: EMERGENCY, BLOCKED_NUMBER, FALLBACK, CACHE_HIT
}
```

### 2. Feedback
**POST /api/assistant/feedback/**
Users can provide feedback on assistant answers.

**Payload:**
```json
{
  "message_id": 10,
  "rating": "UP", // UP, DOWN
  "reason": "UNCLEAR", // Optional: WRONG, UNCLEAR, UNSAFE, OTHER
  "note": "Optional comment max 200 chars"
}
```

### 3. Support Handoff
**POST /api/assistant/handoff/**
Open a support ticket with a human when the assistant is unable to help.

**Payload:**
```json
{
  "subject": "Need help finding a donor",
  "message": "I have been looking for O- blood.",
  "contact_preference": "PHONE" // IN_APP, EMAIL, PHONE
}
```

### 4. Quick Actions
**GET /api/assistant/quick-actions/**
Returns localized starter chips for the UI.

**Response:**
```json
[
  {
    "id": "q1",
    "text_en": "When can I donate next?",
    "text_bn": "আমি কবে রক্ত দিতে পারব?"
  },
  {
    "id": "q2",
    "text_en": "How to request blood?",
    "text_bn": "রক্তের রিকোয়েস্ট কীভাবে করব?"
  }
]
```

### 5. Privacy Consent
**POST /api/assistant/consent/**
Toggle conversation logging for quality assurance.
**Payload:**
```json
{
  "logging_consent": true
}
```

### 6. Delete Conversations
**DELETE /api/assistant/conversations/**
Wipes the user's stored conversations from the server.
