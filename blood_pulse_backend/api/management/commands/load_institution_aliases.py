import os
from django.core.management.base import BaseCommand
from django.conf import settings
from api.management.commands.institution_import_utils import load_institution_aliases_from_csv


class Command(BaseCommand):
    help = 'Load institution aliases from data/institutions/aliases.csv into InstitutionAlias table'

    def add_arguments(self, parser):
        parser.add_argument(
            'csv_path',
            nargs='?',
            default='data/institutions/aliases.csv',
            help='Path to aliases.csv (columns: alias,eiin,source_note)'
        )

    def handle(self, *args, **options):
        csv_path = options['csv_path']
        if not os.path.isabs(csv_path):
            csv_path = os.path.join(settings.BASE_DIR, csv_path)

        self.stdout.write(f"Loading institution aliases from: {csv_path}")
        loaded, skipped = load_institution_aliases_from_csv(csv_path, stdout=self.stdout)
        self.stdout.write(self.style.SUCCESS(f"Complete: {loaded} aliases active, {skipped} skipped."))
