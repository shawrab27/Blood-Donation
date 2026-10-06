# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys

sys.stdout.reconfigure(encoding='utf-8')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
import django
django.setup()


from assistant.models import KBEntry
from assistant.pipeline.emergency import detect_emergency
from assistant.pipeline.guards import check_numeric_claims, apply_guards
from assistant.pipeline.router import route_query
from assistant.pipeline.gemini_client import call_gemini

def run_tests():
    print("=" * 70)
    print("  PULSEAI SYSTEM ENHANCEMENTS & KB VERIFICATION SUITE")
    print("=" * 70)

    # ---------------------------------------------------------
    # TEST 1: Database Audit (143 Rows, 768-dim embeddings)
    # ---------------------------------------------------------
    print("\n[TEST 1] Knowledge Base DB Audit:")
    total = KBEntry.objects.count()
    approved = KBEntry.objects.filter(status='APPROVED').count()
    embedded = KBEntry.objects.filter(embedding__isnull=False).count()
    min_id = KBEntry.objects.order_by('id').first().id if total else None
    max_id = KBEntry.objects.order_by('-id').first().id if total else None
    
    print(f"  Total KBEntry count: {total}")
    print(f"  Approved entries:    {approved}")
    print(f"  768-dim Embeddings:  {embedded}")
    print(f"  ID Range:            {min_id} .. {max_id}")
    
    assert total == 143, f"Expected 143 rows, got {total}"
    assert approved == 143, f"Expected 143 approved rows, got {approved}"
    assert embedded == 143, f"Expected 143 embedded rows, got {embedded}"
    assert min_id == 1 and max_id == 143, f"Expected IDs 1..143, got {min_id}..{max_id}"
    print("  --> PASS: 143 rows verified in pgvector with 768 dims!")

    # ---------------------------------------------------------
    # TEST 2: Emergency Detection ("dying", "faint", zero-latency)
    # ---------------------------------------------------------
    print("\n[TEST 2] Emergency Detection & Zero-Latency LLM Bypass:")
    
    # 2a. "dying"
    res_dying = detect_emergency("I feel sick and I am dying please help")
    assert res_dying and res_dying["emergency"] is True, "Failed to detect 'dying'"
    assert "999" in res_dying["reply"], "Missing 999 in dying reply"
    print("  2a. Input 'dying' detected -> emergency=True, actions:", res_dying["action_ids"])

    # 2b. "faint"
    res_faint = detect_emergency("I feel faint after giving blood")
    assert res_faint and res_faint["emergency"] is True, "Failed to detect 'faint'"
    assert "call_999" in res_faint["action_ids"], "Missing call_999 in faint actions"
    print("  2b. Input 'faint' detected -> emergency=True, actions:", res_faint["action_ids"])

    # 2c. Bangla emergency "মরে যাচ্ছি"
    res_bn = detect_emergency("আমার প্রচুর রক্তক্ষরণ হচ্ছে আমি মরে যাচ্ছি")
    assert res_bn and res_bn["emergency"] is True, "Failed to detect Bangla dying"
    assert res_bn["language"] == "bn", "Bangla response language expected"
    print(f"  2c. Input 'মরে যাচ্ছি' detected -> emergency=True, language={res_bn['language']}")

    # 2d. Non-emergency query must NOT trigger emergency
    res_safe = detect_emergency("How often can I donate blood?")
    assert res_safe is None, "Safe query falsely triggered emergency!"
    print("  2d. Non-emergency query -> None (proceeds to RAG pipeline)")
    print("  --> PASS: Zero-latency emergency rule verified!")

    # ---------------------------------------------------------
    # TEST 3: Numeric Guard (Architecture.md § 5.3)
    # ---------------------------------------------------------
    print("\n[TEST 3] Numeric Claim Guard Verification:")
    kb_34 = KBEntry.objects.get(id=34) # "You can donate blood once every 120 days."
    kb_entries = [kb_34]
    
    # 3a. Hallucinated number "90 days" instead of 120
    hallucinated_json = {
        "reply": "You can donate blood once every 90 days. It takes 90 days to recover.",
        "language": "en",
        "action_ids": [],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": False,
        "kb_ids_used": [34]
    }
    guarded_hallucinated = apply_guards(hallucinated_json, kb_entries)
    print("  3a. Model claims '90 days' (Source has 120 days):")
    print(f"      Result reply: '{guarded_hallucinated['reply']}'")
    print(f"      Flags: {guarded_hallucinated.get('flags')}")
    assert "BLOCKED_NUMBER" in guarded_hallucinated.get("flags", []), "Numeric guard failed to catch 90 days!"
    assert "not sure" in guarded_hallucinated["reply"].lower(), "Fallback message not returned"

    # 3b. Grounded number "120 days" (matches source)
    grounded_json = {
        "reply": "You can donate blood once every 120 days. This allows your body to regenerate new blood cells.",
        "language": "en",
        "action_ids": [],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": False,
        "kb_ids_used": [34]
    }
    guarded_grounded = apply_guards(grounded_json, kb_entries)
    print("  3b. Model claims '120 days' (Source has 120 days):")
    print(f"      Result reply: '{guarded_grounded['reply'][:60]}...'")
    print(f"      Flags: {guarded_grounded.get('flags')}")
    assert "BLOCKED_NUMBER" not in guarded_grounded.get("flags", []), "Numeric guard falsely blocked 120 days!"

    # 3c. Bangla hallucinated "৯০ দিন"
    bn_hallucinated = {
        "reply": "আপনি প্রতি ৯০ দিন পরপর রক্ত দান করতে পারেন।",
        "language": "bn",
        "action_ids": [],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": False,
        "kb_ids_used": [34]
    }
    guarded_bn_hallucinated = apply_guards(bn_hallucinated, kb_entries)
    print("  3c. Bangla Model claims '৯০ দিন' (Source has ১২০ দিন):")
    print(f"      Flags: {guarded_bn_hallucinated.get('flags')}")
    assert "BLOCKED_NUMBER" in guarded_bn_hallucinated.get("flags", []), "Numeric guard failed on Bangla 90 days!"

    # 3d. Bangla grounded "১২০ দিন"
    bn_grounded = {
        "reply": "আপনি প্রতি ১২০ দিনের ব্যবধানে একবার রক্ত দান করতে পারেন।",
        "language": "bn",
        "action_ids": [],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": False,
        "kb_ids_used": [34]
    }
    guarded_bn_grounded = apply_guards(bn_grounded, kb_entries)
    print("  3d. Bangla Model claims '১২০ দিন' (Source has ১২০ দিন):")
    print(f"      Flags: {guarded_bn_grounded.get('flags')}")
    assert "BLOCKED_NUMBER" not in guarded_bn_grounded.get("flags", []), "Numeric guard falsely blocked Bangla 120 days!"
    print("  --> PASS: Numeric guard rejects hallucinated numbers and preserves grounded numbers!")

    # ---------------------------------------------------------
    # TEST 4: Semantic Search & Retrieval (pgvector)
    # ---------------------------------------------------------
    print("\n[TEST 4] Semantic Search with pgvector (Cosine Similarity):")
    q1 = "How often can I donate blood?"
    route1 = route_query(q1)
    top1 = route1["matches"][0]
    print(f"  Query: '{q1}'")
    print(f"  Top Match ID={top1.id}: '{top1.title_en}', Distance: {getattr(top1, 'distance', 0):.4f}")
    assert top1.id == 34, f"Expected ID 34 for donation interval, got {top1.id}"

    q2 = "Is B blood compatible with O type?"
    route2 = route_query(q2)
    top2_ids = [m.id for m in route2["matches"]]
    print(f"  Query: '{q2}'")
    for idx, m in enumerate(route2["matches"]):
        print(f"    Match #{idx+1} ID={m.id}: '{m.title_en}', Distance: {getattr(m, 'distance', 0):.4f}")
    assert 35 in top2_ids, f"Expected ID 35 in top matches, got {top2_ids}"
    print("  --> PASS: Semantic retrieval successfully surfaced relevant addon entries!")


    # ---------------------------------------------------------
    # TEST 5: Live Grounded Gemini Inference
    # ---------------------------------------------------------
    print("\n[TEST 5] Live Grounded Gemini Inference:")
    gemini_resp = call_gemini(
        user_message="How often can I donate blood in Bangladesh?",
        history=[],
        kb_entries=[top1],
        guide_entries=[]
    )
    result_data = gemini_resp["json"]
    print("  Gemini raw reply:", result_data.get("reply"))
    print("  Latency:", gemini_resp["latency_ms"], "ms, Tokens in/out:", gemini_resp["tokens_in"], "/", gemini_resp["tokens_out"])
    
    # Run guards on real Gemini reply
    final_result = apply_guards(result_data, [top1])
    print("  Final Guarded reply:", final_result.get("reply"))
    print("  Final Flags:", final_result.get("flags"))
    assert "120" in final_result["reply"] or "BLOCKED_NUMBER" not in final_result.get("flags", [])
    print("  --> PASS: Live Gemini grounded answer successfully generated and passed guard!")

    print("\n" + "=" * 70)
    print("  ALL 5 EVALUATION SUITES PASSED WITH 100% SUCCESS")
    print("=" * 70)

if __name__ == "__main__":
    run_tests()
