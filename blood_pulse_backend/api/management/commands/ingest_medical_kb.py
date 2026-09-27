# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import csv
from django.core.management.base import BaseCommand
from api.models import MedicalKnowledgeBase

class Command(BaseCommand):
    help = 'Ingests the medical_qa.csv into the MedicalKnowledgeBase model.'

    def add_arguments(self, parser):
        parser.add_argument('csv_path', type=str, help='Path to the medical_qa.csv file')

    def handle(self, *args, **kwargs):
        csv_path = kwargs['csv_path']
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            count = 0
            for row in reader:
                MedicalKnowledgeBase.objects.update_or_create(
                    question_en=row['question_en'],
                    defaults={
                        'topic': row['topic'],
                        'answer_en': row['answer_en'],
                        'question_bn': row['question_bn'],
                        'answer_bn': row['answer_bn'],
                        'sources': row['sources'],
                    }
                )
                count += 1
        self.stdout.write(self.style.SUCCESS(f'Successfully ingested {count} KB entries.'))
