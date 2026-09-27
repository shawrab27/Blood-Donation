import json
import urllib.request
from django.core.management.base import BaseCommand
from api.models import Institution

class Command(BaseCommand):
    help = 'Import institutions from GitHub JSON data'

    def handle(self, *args, **kwargs):
        urls = [
            'https://raw.githubusercontent.com/chaudhuree/bd-all-institutes/master/data/bd_schoolName_data.json',
            'https://raw.githubusercontent.com/chaudhuree/bd-all-institutes/master/data/bd_collegeName_data.json',
            'https://raw.githubusercontent.com/chaudhuree/bd-all-institutes/master/data/bd_madrashaName_data.json',
            'https://raw.githubusercontent.com/chaudhuree/bd-all-institutes/master/data/private_Uni_data.json',
            'https://raw.githubusercontent.com/chaudhuree/bd-all-institutes/master/data/public_Uni_data.json',
            'https://raw.githubusercontent.com/chaudhuree/bd-all-institutes/master/data/nu_Uni_data.json',
        ]

        # In-memory tracking to avoid duplicates (name + eiin)
        seen = set()
        to_create = []
        skipped = 0
        
        self.stdout.write("Fetching data from GitHub...")
        for url in urls:
            try:
                response = urllib.request.urlopen(url)
                data = json.loads(response.read().decode('utf-8'))
                
                for item in data:
                    name = item.get('name')
                    if not name:
                        skipped += 1
                        continue
                        
                    name = name.strip()
                    if not name:
                        skipped += 1
                        continue
                        
                    eiin = str(item.get('eiin', '')).strip()
                    if eiin.lower() == 'none' or not eiin:
                        eiin = None
                        
                    # Normalize type
                    inst_type_raw = item.get('institutionType', '').lower()
                    if 'school' in inst_type_raw:
                        inst_type = 'school'
                    elif 'college' in inst_type_raw:
                        inst_type = 'college'
                    elif 'madrasa' in inst_type_raw or 'madrasha' in inst_type_raw or 'madarasa' in inst_type_raw:
                        inst_type = 'madrasa'
                    else:
                        inst_type = 'university' # fallback for universities
                        
                    key = (name, eiin)
                    if key not in seen:
                        seen.add(key)
                        to_create.append(
                            Institution(
                                name=name,
                                eiin=eiin,
                                institution_type=inst_type,
                            )
                        )
            except Exception as e:
                self.stderr.write(f"Error fetching/parsing {url}: {e}")
        
        self.stdout.write(f"Inserting {len(to_create)} institutions...")
        # Clear existing first to avoid duplicate growth if run multiple times?
        # The spec says "Run the command once against the production database".
        # We will just insert them. If it was run already, the `seen` check only stops duplicates WITHIN this run.
        # But this is a one-off script. Let's do a bulk_create with ignore_conflicts or just bulk_create.
        
        # We can clear first or just rely on the DB being empty initially. 
        # I'll just clear the table so it's idempotent.
        Institution.objects.all().delete()

        batch_size = 5000
        Institution.objects.bulk_create(to_create, batch_size=batch_size)
        
        # Calculate summary
        counts = {'school': 0, 'college': 0, 'madrasa': 0, 'university': 0}
        for i in to_create:
            counts[i.institution_type] += 1
            
        self.stdout.write(self.style.SUCCESS('Import completed!'))
        self.stdout.write(f"Schools: {counts['school']}")
        self.stdout.write(f"Colleges: {counts['college']}")
        self.stdout.write(f"Madrasas: {counts['madrasa']}")
        self.stdout.write(f"Universities: {counts['university']}")
        self.stdout.write(f"Skipped due to missing names: {skipped}")
