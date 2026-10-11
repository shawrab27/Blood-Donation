import os
from django.core.management.base import BaseCommand
from api.models import DonorProfile, BloodRequest, LocalClub, Division, District
from api.data.bd_locations import BD_DIVISIONS_AND_DISTRICTS, DISTRICT_ALIASES, DIVISION_ALIASES


class Command(BaseCommand):
    help = (
        "Read-only location mismatch audit. Reports counts of DonorProfile, BloodRequest, "
        "and LocalClub rows whose district/division is not a canonical name or known alias. "
        "Guarantees ZERO PII exposure (aggregate counts only)."
    )

    def handle(self, *args, **options):
        canonical_divisions = set(BD_DIVISIONS_AND_DISTRICTS.keys())
        known_division_aliases = set(DIVISION_ALIASES.keys())
        all_valid_divisions = {d.lower() for d in canonical_divisions | known_division_aliases}

        canonical_districts = set()
        for dlist in BD_DIVISIONS_AND_DISTRICTS.values():
            canonical_districts.update(dlist)
        known_district_aliases = set(DISTRICT_ALIASES.keys())
        all_valid_districts = {d.lower() for d in canonical_districts | known_district_aliases}

        # 1. DonorProfile
        # district: CharField(max_length=100)
        # Note: DonorProfile has no division column
        total_donors = DonorProfile.objects.count()
        invalid_donor_districts = 0
        blank_donor_districts = 0
        for dp in DonorProfile.objects.only('district').iterator():
            val = (dp.district or '').strip()
            if not val:
                blank_donor_districts += 1
            elif val.lower() not in all_valid_districts:
                invalid_donor_districts += 1

        # 2. BloodRequest
        # district: CharField(max_length=100, blank=True, default='')
        # division: ForeignKey(Division, null=True, blank=True)
        total_requests = BloodRequest.objects.count()
        invalid_request_districts = 0
        blank_request_districts = 0
        invalid_request_divisions = 0
        blank_request_divisions = 0
        for br in BloodRequest.objects.select_related('division').only('district', 'division__name').iterator():
            dval = (br.district or '').strip()
            if not dval:
                blank_request_districts += 1
            elif dval.lower() not in all_valid_districts:
                invalid_request_districts += 1

            if not br.division:
                blank_request_divisions += 1
            else:
                div_name = (br.division.name or '').strip()
                if div_name.lower() not in all_valid_divisions:
                    invalid_request_divisions += 1

        # 3. LocalClub
        # division: ForeignKey(Division, null=True, blank=True)
        # district: ForeignKey(District, null=True, blank=True)
        total_clubs = LocalClub.objects.count()
        invalid_club_districts = 0
        blank_club_districts = 0
        invalid_club_divisions = 0
        blank_club_divisions = 0
        for lc in LocalClub.objects.select_related('division', 'district').only('division__name', 'district__name').iterator():
            if not lc.district:
                blank_club_districts += 1
            else:
                dist_name = (lc.district.name or '').strip()
                if dist_name.lower() not in all_valid_districts:
                    invalid_club_districts += 1

            if not lc.division:
                blank_club_divisions += 1
            else:
                div_name = (lc.division.name or '').strip()
                if div_name.lower() not in all_valid_divisions:
                    invalid_club_divisions += 1

        self.stdout.write("\n=======================================================")
        self.stdout.write("LOCATION MISMATCH AUDIT REPORT (Read-Only, Zero PII)")
        self.stdout.write("=======================================================")
        self.stdout.write(f"\n1. DonorProfile (Total: {total_donors}):")
        self.stdout.write(f"   - Invalid/Unknown district: {invalid_donor_districts}")
        self.stdout.write(f"   - Blank/Empty district:    {blank_donor_districts}")

        self.stdout.write(f"\n2. BloodRequest (Total: {total_requests}):")
        self.stdout.write(f"   - Invalid/Unknown district: {invalid_request_districts}")
        self.stdout.write(f"   - Blank/Empty district:    {blank_request_districts}")
        self.stdout.write(f"   - Invalid/Unknown division: {invalid_request_divisions}")
        self.stdout.write(f"   - Blank/Empty division:    {blank_request_divisions}")

        self.stdout.write(f"\n3. LocalClub (Total: {total_clubs}):")
        self.stdout.write(f"   - Invalid/Unknown district: {invalid_club_districts}")
        self.stdout.write(f"   - Blank/Empty district:    {blank_club_districts}")
        self.stdout.write(f"   - Invalid/Unknown division: {invalid_club_divisions}")
        self.stdout.write(f"   - Blank/Empty division:    {blank_club_divisions}")

        self.stdout.write("\n[Privacy Guarantee] Aggregate counts only. No names, phone numbers, or coordinates.")
        self.stdout.write("=======================================================\n")
