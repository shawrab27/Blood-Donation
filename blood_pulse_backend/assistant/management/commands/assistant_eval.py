# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import csv
import json
from django.core.management.base import BaseCommand
from assistant.pipeline.emergency import detect_emergency
from assistant.pipeline.shortcuts import evaluate_shortcuts
from assistant.pipeline.gemini_client import call_gemini
from assistant.pipeline.guards import apply_guards
from assistant.pipeline.fallback import get_fallback_response
from assistant.models import KBEntry, AppGuideEntry

class Command(BaseCommand):
    help = 'Evaluate the Assistant pipeline with a CSV'

    def add_arguments(self, parser):
        parser.add_argument('--csv', type=str, required=True)
        parser.add_argument('--out', type=str, required=True)

    def handle(self, *args, **options):
        csv_path = options['csv']
        out_path = options['out']
        
        kb_entries = list(KBEntry.objects.filter(status='APPROVED'))
        guide_entries = list(AppGuideEntry.objects.filter(status='APPROVED'))
        
        results = []
        counts = {'pass': 0, 'fail': 0, 'bn': 0, 'en': 0, 'banglish': 0, 
                  'ANSWER_FROM_KB': {'pass':0, 'fail':0},
                  'REFUSE': {'pass':0, 'fail':0},
                  'EMERGENCY': {'pass':0, 'fail':0},
                  'HANDOFF': {'pass':0, 'fail':0},
                  'APP_HELP': {'pass':0, 'fail':0}}
                  
        with open(csv_path, newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                q = row['question']
                expected = row['expected']
                lang = row['language']
                must_inc = row.get('must_include', '').strip()
                must_not_inc = row.get('must_not_include', '').strip()
                
                # Run pipeline logic
                em_res = detect_emergency(q)
                if em_res:
                    res = em_res
                else:
                    sc_res = evaluate_shortcuts(q, None)
                    if sc_res:
                        res = sc_res
                    else:
                        try:
                            gem_res = call_gemini(q, [], kb_entries, guide_entries)
                            res = apply_guards(gem_res["json"], kb_entries)
                        except Exception:
                            res = get_fallback_response(q)
                            
                # Check pass/fail
                passed = True
                
                if expected == 'EMERGENCY' and not res.get('emergency'):
                    passed = False
                elif expected == 'REFUSE' and not res.get('out_of_scope') and 'I am not sure' not in res.get('reply', ''):
                    passed = False
                
                if must_inc and must_inc.lower() not in res.get('reply', '').lower():
                    passed = False
                    
                if must_not_inc and must_not_inc.lower() in res.get('reply', '').lower():
                    passed = False
                    
                counts[lang] = counts.get(lang, 0) + 1
                if passed:
                    counts['pass'] += 1
                    counts[expected]['pass'] += 1
                else:
                    counts['fail'] += 1
                    counts[expected]['fail'] += 1
                    
                results.append({
                    'id': row['id'],
                    'question': q,
                    'reply': res.get('reply'),
                    'passed': passed,
                    'expected': expected
                })
                
        with open(out_path, 'w', encoding='utf-8') as out:
            out.write("# Evaluation Report\n\n")
            out.write(f"Total: {counts['pass']+counts['fail']} (Pass: {counts['pass']}, Fail: {counts['fail']})\n\n")
            
            for k in ['ANSWER_FROM_KB', 'REFUSE', 'EMERGENCY', 'HANDOFF', 'APP_HELP']:
                t = counts[k]['pass'] + counts[k]['fail']
                out.write(f"**{k}**: {t} total, {counts[k]['pass']} passed, {counts[k]['fail']} failed\n")
                
            out.write("\n## Details\n")
            for r in results:
                status = "✅" if r['passed'] else "❌"
                out.write(f"### {status} [{r['id']}] Expected: {r['expected']}\n")
                out.write(f"**Q:** {r['question']}\n")
                out.write(f"**A:** {r['reply']}\n\n")
                
        self.stdout.write(self.style.SUCCESS(f"Evaluation complete. Results saved to {out_path}"))
