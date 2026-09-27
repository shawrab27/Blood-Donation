import os
import sqlite3
import requests
from bs4 import BeautifulSoup
from django.core.management.base import BaseCommand
from api.models import Institution, District

class Command(BaseCommand):
    help = 'Import institutions from official sources (KonSchool, NU, UGC)'

    def handle(self, *args, **kwargs):
        seen = set()
        to_create = []
        counts = {'school': 0, 'college': 0, 'madrasa': 0, 'university': 0}
        skipped = {'school': 0, 'college': 0, 'university': 0}

        Institution.objects.all().delete()
        self.stdout.write("Cleared existing institutions.")

        # 1. SCHOOLS (KonSchool SQLite)
        sqlite_path = 'konschool.sqlite'
        if os.path.exists(sqlite_path):
            self.stdout.write(f"Importing Schools from {sqlite_path}...")
            try:
                conn = sqlite3.connect(sqlite_path)
                cursor = conn.cursor()
                cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
                tables = [t[0] for t in cursor.fetchall() if t[0] not in ('sqlite_sequence', 'sqlite_stat1')]
                table_name = 'Schools' if 'Schools' in tables else (tables[0] if tables else None)

                if table_name:
                    cursor.execute(f"PRAGMA table_info({table_name});")
                    columns = [info[1].lower() for info in cursor.fetchall()]
                    
                    name_col = next((c for c in columns if c == 'name'), None)
                    eiin_col = next((c for c in columns if c == 'eiin'), None)
                    dist_col = next((c for c in columns if c == 'district'), None)
                    
                    if name_col:
                        cols_to_select = [name_col]
                        if eiin_col: cols_to_select.append(eiin_col)
                        if dist_col: cols_to_select.append(dist_col)
                        
                        cursor.execute(f"SELECT {','.join(cols_to_select)} FROM {table_name}")
                        for row in cursor.fetchall():
                            name = row[0]
                            if not name or not str(name).strip():
                                skipped['school'] += 1
                                continue
                                
                            eiin = None
                            district_name = None
                            if eiin_col and dist_col:
                                eiin, district_name = row[1], row[2]
                            elif eiin_col:
                                eiin = row[1]
                            elif dist_col:
                                district_name = row[1]
                                
                            eiin = str(eiin).strip() if eiin else None
                            district = None
                            if district_name:
                                district = District.objects.filter(name__iexact=str(district_name).strip()).first()

                            key = (str(name).strip(), eiin)
                            if key not in seen:
                                seen.add(key)
                                to_create.append(Institution(
                                    name=str(name).strip(),
                                    eiin=eiin,
                                    institution_type='school',
                                    district=district
                                ))
                                counts['school'] += 1
                conn.close()
            except Exception as e:
                self.stderr.write(f"Error parsing SQLite DB: {e}")
        else:
            self.stderr.write(f"SQLite file '{sqlite_path}' not found! Skipping schools import.")
            self.stderr.write("Please download the KonSchool DB from Google Drive and place it at blood_pulse_backend/konschool.sqlite")

        # 2. COLLEGES (NU portal)
        self.stdout.write("Importing Colleges from NU...")
        self.stderr.write("Note: NU's official site (collegeportal.nu.ac.bd) requires login/authentication or offers non-machine-readable PDFs for their affiliated college list.")
        self.stderr.write("Skipping automated college extraction as requested, since data is not publicly machine-readable without auth.")

        # 3. UNIVERSITIES (UGC)
        self.stdout.write("Importing Universities from UGC...")
        ugc_urls = [
            'http://www.ugc-universities.gov.bd/public-universities',
            'http://www.ugc-universities.gov.bd/private-universities',
            'http://www.ugc-universities.gov.bd/international-universities'
        ]
        for url in ugc_urls:
            try:
                resp = requests.get(url, timeout=10)
                if resp.status_code == 200:
                    soup = BeautifulSoup(resp.text, 'html.parser')
                    rows = soup.select('.table tbody tr')
                    for r in rows:
                        tds = r.find_all('td')
                        if len(tds) >= 2:
                            name = tds[1].text.strip()[:255]
                            if not name:
                                skipped['university'] += 1
                                continue
                            
                            key = (name, None)
                            if key not in seen:
                                seen.add(key)
                                to_create.append(Institution(
                                    name=name,
                                    eiin=None,
                                    institution_type='university',
                                ))
                                counts['university'] += 1
            except Exception as e:
                self.stderr.write(f"Error fetching universities from {url}: {e}")
                
        # Insert to DB
        self.stdout.write(f"Inserting {len(to_create)} institutions...")
        batch_size = 5000
        Institution.objects.bulk_create(to_create, batch_size=batch_size)
        
        self.stdout.write(self.style.SUCCESS('Import completed!'))
        self.stdout.write(f"Schools: {counts['school']}")
        self.stdout.write(f"Colleges: {counts['college']}")
        self.stdout.write(f"Madrasas: {counts['madrasa']}")
        self.stdout.write(f"Universities: {counts['university']}")
        self.stdout.write(f"Skipped due to missing data: Schools({skipped['school']}), Colleges({skipped['college']}), Universities({skipped['university']})")
