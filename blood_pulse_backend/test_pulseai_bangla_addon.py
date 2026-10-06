# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import sys
import csv
import pytest
import django

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "blood_pulse_backend.settings")
django.setup()

from assistant.models import KBEntry
from assistant.pipeline.emergency import detect_emergency
from assistant.pipeline.guards import apply_guards
from assistant.pipeline.router import route_query

@pytest.fixture(scope="module")
def addon_csv_rows():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    csv_path = os.path.join(root_dir, 'data', 'bloodpulse_kb_bangla_addon.csv')
    if not os.path.exists(csv_path):
        csv_path = os.path.join('data', 'bloodpulse_kb_bangla_addon.csv')
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = list(csv.DictReader(f))
    return reader

def test_csv_validation(addon_csv_rows):
    """Validate 10 Bangla Q&A rows schema and completeness."""
    assert len(addon_csv_rows) == 10, f"Expected 10 rows, got {len(addon_csv_rows)}"
    ids = [int(r['id']) for r in addon_csv_rows]
    assert ids == list(range(34, 44)), f"Expected IDs 34..43, got {ids}"
    
    expected_cols = {'id', 'question_bn', 'question_en', 'answer_bn', 'answer_en', 'category', 'source', 'verified'}
    for r in addon_csv_rows:
        assert set(r.keys()) == expected_cols
        assert r['question_bn'].strip()
        assert r['question_en'].strip()
        assert r['answer_bn'].strip()
        assert r['answer_en'].strip()
        assert r['category'].strip()
        assert r['source'].strip()
        assert r['verified'].strip().lower() == 'true'

def test_postgres_total_count():
    """Verify exact count of 43 rows in pgvector database."""
    total_count = KBEntry.objects.count()
    assert total_count == 43, f"Expected exactly 43 rows in DB, got {total_count}"
    
    approved_count = KBEntry.objects.filter(status='APPROVED').count()
    assert approved_count == 43, f"Expected 43 approved rows, got {approved_count}"
    
    embedded_count = KBEntry.objects.filter(embedding__isnull=False).count()
    assert embedded_count == 43, f"Expected 43 embedded rows, got {embedded_count}"

def test_numeric_guard_q1_donation_interval():
    """Numeric guard Question 1: 120 days interval."""
    kb_34 = KBEntry.objects.get(id=34)
    
    # Grounded response (120 days)
    grounded = {
        "reply": "আপনি প্রতি ১২০ দিনের ব্যবধানে একবার রক্ত দান করতে পারেন। এটি আপনার শরীরকে রক্তকোষ তৈরিতে সাহায্য করে।",
        "language": "bn",
        "action_ids": [],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": False,
        "kb_ids_used": [34]
    }
    res_grounded = apply_guards(grounded, [kb_34])
    assert "BLOCKED_NUMBER" not in res_grounded.get("flags", [])
    
    # Hallucinated response (90 days)
    hallucinated = {
        "reply": "আপনি প্রতি ৯০ দিন পরপর রক্ত দান করতে পারেন।",
        "language": "bn",
        "action_ids": [],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": False,
        "kb_ids_used": [34]
    }
    res_hallucinated = apply_guards(hallucinated, [kb_34])
    assert "BLOCKED_NUMBER" in res_hallucinated.get("flags", [])
    assert "নিশ্চিত নই" in res_hallucinated["reply"]

def test_numeric_guard_q2_minimum_weight():
    """Numeric guard Question 2: 50 kg minimum weight."""
    kb_39 = KBEntry.objects.get(id=39)
    
    # Grounded response (50 kg)
    grounded = {
        "reply": "কম ওজনের কারণে দান করতে পারবেন না যদি আপনার ওজন ৫০ কেজির নিচে থাকে।",
        "language": "bn",
        "action_ids": [],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": False,
        "kb_ids_used": [39]
    }
    res_grounded = apply_guards(grounded, [kb_39])
    assert "BLOCKED_NUMBER" not in res_grounded.get("flags", [])
    
    # Hallucinated response (45 kg)
    hallucinated = {
        "reply": "কম ওজনের কারণে দান করতে পারবেন না যদি আপনার ওজন ৪৫ কেজির নিচে থাকে।",
        "language": "bn",
        "action_ids": [],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": False,
        "kb_ids_used": [39]
    }
    res_hallucinated = apply_guards(hallucinated, [kb_39])
    assert "BLOCKED_NUMBER" in res_hallucinated.get("flags", [])

def test_numeric_guard_q3_recovery_time():
    """Numeric guard Question 3: 24 to 48 hours recovery."""
    kb_37 = KBEntry.objects.get(id=37)
    
    # Grounded response (24 to 48 hours)
    grounded = {
        "reply": "বেশিরভাগ মানুষ ২৪ ঘন্টার মধ্যে স্বাভাবিক অনুভব করে। কিছু ক্লান্তি ৪৮ ঘন্টা পর্যন্ত থাকতে পারে।",
        "language": "bn",
        "action_ids": [],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": False,
        "kb_ids_used": [37]
    }
    res_grounded = apply_guards(grounded, [kb_37])
    assert "BLOCKED_NUMBER" not in res_grounded.get("flags", [])
    
    # Hallucinated response (12 hours)
    hallucinated = {
        "reply": "বেশিরভাগ মানুষ ১২ ঘন্টার মধ্যে স্বাভাবিক অনুভব করে।",
        "language": "bn",
        "action_ids": [],
        "emergency": False,
        "out_of_scope": False,
        "needs_human": False,
        "kb_ids_used": [37]
    }
    res_hallucinated = apply_guards(hallucinated, [kb_37])
    assert "BLOCKED_NUMBER" in res_hallucinated.get("flags", [])

def test_emergency_bangla_triggers():
    """Verify zero-latency emergency bypass on critical Bangla inputs."""
    res1 = detect_emergency("আমি প্রচুর রক্তক্ষরণ হয়ে মরে যাচ্ছি")
    assert res1 and res1["emergency"] is True
    assert res1["language"] == "bn"
    assert "call_999" in res1["action_ids"]
    assert "৯৯৯" in res1["reply"]
    
    res2 = detect_emergency("রক্তদানের সময় দাতা জ্ঞান হারিয়ে ফেললে")
    assert res2 and res2["emergency"] is True
    assert res2["language"] == "bn"

def test_bangla_semantic_retrieval():
    """Verify pgvector semantic search matches Bangla blood donation queries."""
    res = route_query("রক্তদানের আগে কি খাওয়া উচিত?")
    matches = res.get("matches", [])
    assert len(matches) > 0
    top_ids = [m.id for m in matches]
    assert 36 in top_ids, f"Expected ID 36 in top matches, got {top_ids}"

