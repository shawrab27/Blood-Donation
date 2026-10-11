from django.core.management.base import BaseCommand
from api.models import ExecutiveMember, LocalClub, NationalCommunity


class Command(BaseCommand):
    help = "Read-only report on contact number visibility counts (no PII/phone numbers printed)."

    def handle(self, *args, **options):
        self.stdout.write("\n=======================================================")
        self.stdout.write("COMMUNITY CONTACT VISIBILITY AUDIT REPORT")
        self.stdout.write("=======================================================\n")

        # 1. Executive Members
        em_total = ExecutiveMember.objects.count()
        # Exposed condition: show_contact and consent_to_publish and verified_by_admin and phone_number non-empty
        em_visible = ExecutiveMember.objects.filter(
            show_contact=True,
            consent_to_publish=True,
            verified_by_admin=True,
        ).exclude(phone_number='').count()
        em_hidden = em_total - em_visible

        self.stdout.write("1. EXECUTIVE MEMBERS (Club Officers):")
        self.stdout.write(f"   - Total Officers: {em_total}")
        self.stdout.write(f"   - Visible Contacts: {em_visible}")
        self.stdout.write(f"   - Hidden / Masked Contacts: {em_hidden}")

        # 2. Local Clubs
        lc_total = LocalClub.objects.count()
        # Exposed condition: show_contact and verified_by_admin and contact_number non-empty
        lc_visible = LocalClub.objects.filter(
            show_contact=True,
            verified_by_admin=True,
        ).exclude(contact_number='').count()
        lc_hidden = lc_total - lc_visible

        self.stdout.write("\n2. LOCAL BLOOD CLUBS:")
        self.stdout.write(f"   - Total Clubs: {lc_total}")
        self.stdout.write(f"   - Visible Contacts: {lc_visible}")
        self.stdout.write(f"   - Hidden / Masked Contacts: {lc_hidden}")

        # 3. National Communities
        nc_total = NationalCommunity.objects.count()
        # Exposed condition: verified_by_admin and phone_number non-empty
        nc_visible = NationalCommunity.objects.filter(
            verified_by_admin=True,
        ).exclude(phone_number='').count()
        nc_hidden = nc_total - nc_visible

        self.stdout.write("\n3. NATIONAL COMMUNITIES & ORGANIZATIONS:")
        self.stdout.write(f"   - Total Organizations: {nc_total}")
        self.stdout.write(f"   - Visible Contacts: {nc_visible}")
        self.stdout.write(f"   - Hidden / Masked Contacts: {nc_hidden}")

        self.stdout.write("\n=======================================================")
        self.stdout.write("ZERO PII GUARANTEE: No raw phone numbers or credentials exposed.")
        self.stdout.write("=======================================================\n")
