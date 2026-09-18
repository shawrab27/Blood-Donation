from django.core.management.base import BaseCommand
from api.models import (
    BloodScienceArticle, CompatibilityRule, DonationGuideSection,
    EmergencyContact, RecoveryTimelineStep
)

class Command(BaseCommand):
    help = 'Seeds Health Hub educational articles, compatibility matrix, donation guide, emergency contacts, and recovery timeline.'

    def handle(self, *args, **options):
        self.stdout.write(self.style.NOTICE("Seeding Health Hub Content..."))

        # 1. Compatibility Rules
        compatibility_data = [
            {
                "blood_group": "O-",
                "can_give_to": "O-, O+, A-, A+, B-, B+, AB-, AB+",
                "can_receive_from": "O-",
            },
            {
                "blood_group": "O+",
                "can_give_to": "O+, A+, B+, AB+",
                "can_receive_from": "O+, O-",
            },
            {
                "blood_group": "A-",
                "can_give_to": "A-, A+, AB-, AB+",
                "can_receive_from": "A-, O-",
            },
            {
                "blood_group": "A+",
                "can_give_to": "A+, AB+",
                "can_receive_from": "A+, A-, O+, O-",
            },
            {
                "blood_group": "B-",
                "can_give_to": "B-, B+, AB-, AB+",
                "can_receive_from": "B-, O-",
            },
            {
                "blood_group": "B+",
                "can_give_to": "B+, AB+",
                "can_receive_from": "B+, B-, O+, O-",
            },
            {
                "blood_group": "AB-",
                "can_give_to": "AB-, AB+",
                "can_receive_from": "AB-, A-, B-, O-",
            },
            {
                "blood_group": "AB+",
                "can_give_to": "AB+",
                "can_receive_from": "AB+, AB-, A+, A-, B+, B-, O+, O-",
            },
        ]

        for item in compatibility_data:
            obj, created = CompatibilityRule.objects.get_or_create(
                blood_group=item["blood_group"],
                defaults={
                    "can_give_to": item["can_give_to"],
                    "can_receive_from": item["can_receive_from"],
                }
            )
            action = "Created" if created else "Exists"
            self.stdout.write(f"  [Compatibility] {action}: {obj.blood_group}")

        # 2. Blood Science Articles
        articles_data = [
            {
                "title": "Red Blood Cells (Erythrocytes)",
                "content": "Red blood cells make up approximately 40-45% of blood volume. Packed with iron-rich hemoglobin, they carry vital oxygen from your lungs to every tissue and organ in your body, returning carbon dioxide back to your lungs for exhalation.",
                "order": 1,
            },
            {
                "title": "White Blood Cells (Leukocytes)",
                "content": "White blood cells constitute your immune defense system. They actively identify and eliminate viral or bacterial pathogens, neutralize foreign toxins, and maintain cellular memory against future infections.",
                "order": 2,
            },
            {
                "title": "Platelets (Thrombocytes)",
                "content": "Platelets are microscopic cellular fragments essential for healthy hemostasis. When a blood vessel is damaged, platelets aggregate at the wound site and trigger the coagulation cascade to halt blood loss.",
                "order": 3,
            },
            {
                "title": "Blood Plasma",
                "content": "Plasma is the golden liquid portion of your blood, comprising roughly 55% of total volume. It is 92% water and carries essential proteins, electrolytes, antibodies, clotting factors, and hormones throughout your body.",
                "order": 4,
            },
        ]

        for item in articles_data:
            obj, created = BloodScienceArticle.objects.get_or_create(
                title=item["title"],
                defaults={
                    "content": item["content"],
                    "order": item["order"],
                }
            )
            action = "Created" if created else "Exists"
            self.stdout.write(f"  [Article] {action}: {obj.title}")

        # 3. Donation Guide Sections
        guide_data = [
            {
                "category": "eligibility",
                "title": "General Donor Eligibility",
                "content": "To donate whole blood, you must be between 18 and 60 years old, weigh at least 50 kg (110 lbs), have a hemoglobin level >= 12.5 g/dL, and have normal blood pressure and pulse.",
                "order": 1,
            },
            {
                "category": "preparation",
                "title": "Pre-Donation Preparation",
                "content": "Drink an extra 500 mL of water before your appointment. Eat a nutritious meal rich in iron within 2 to 3 hours prior to donation. Avoid fatty or greasy foods, and get a restful night's sleep.",
                "order": 2,
            },
            {
                "category": "journey",
                "title": "The Donation Experience",
                "content": "A typical whole blood donation takes just 8 to 10 minutes. The entire appointment, including confidential health screening and mini-physical, takes about 35 to 45 minutes.",
                "order": 3,
            },
            {
                "category": "journey",
                "title": "Post-Donation Rest & Refreshments",
                "content": "Relax in the recovery observation area for 10-15 minutes with water, juice, and light snacks. Keep the bandage on for 4 hours and avoid heavy lifting or strenuous exercise for the rest of the day.",
                "order": 4,
            },
            {
                "category": "myth",
                "title": "Does Donating Blood Make You Weak?",
                "content": "Myth: Donating blood causes lasting weakness or illness. Fact: Your body quickly replaces lost plasma volume within 24 to 48 hours and replenishes red blood cells within several weeks. Healthy donors experience zero long-term stamina loss.",
                "order": 5,
            },
            {
                "category": "why_donate",
                "title": "Every Donation Saves Up to 3 Lives",
                "content": "Each unit of whole blood can be separated into red cells, platelets, and plasma, helping trauma patients, surgical recipients, and individuals battling anemia or cancer.",
                "order": 6,
            },
        ]

        for item in guide_data:
            obj, created = DonationGuideSection.objects.get_or_create(
                category=item["category"],
                title=item["title"],
                defaults={
                    "content": item["content"],
                    "order": item["order"],
                }
            )
            action = "Created" if created else "Exists"
            self.stdout.write(f"  [Guide] {action}: [{obj.category}] {obj.title}")

        # 4. Emergency Contacts
        contacts_data = [
            {
                "name": "National Emergency Helpline",
                "phone_number": "999",
                "description": "Toll-free 24/7 hotline for Police, Fire Service, and Government Ambulance",
                "is_24_hours": True,
            },
            {
                "name": "Red Crescent Blood Center",
                "phone_number": "+880-2-9880000",
                "description": "Central Blood Bank & 24/7 Transfusion Emergency Support",
                "is_24_hours": True,
            },
            {
                "name": "National Blood Transfusion Service (DMC Unit)",
                "phone_number": "+880-2-55165000",
                "description": "Government Central Blood Bank Emergency Desk",
                "is_24_hours": True,
            },
            {
                "name": "Institute of Public Health (IPH) Blood Helpline",
                "phone_number": "+880-1700-000999",
                "description": "National donor registry coordination & urgent matching desk",
                "is_24_hours": True,
            },
        ]

        for item in contacts_data:
            obj, created = EmergencyContact.objects.get_or_create(
                name=item["name"],
                defaults={
                    "phone_number": item["phone_number"],
                    "description": item["description"],
                    "is_24_hours": item["is_24_hours"],
                }
            )
            action = "Created" if created else "Exists"
            self.stdout.write(f"  [Emergency Contact] {action}: {obj.name}")

        # 5. Recovery Timeline Steps
        timeline_data = [
            {
                "hour_mark": 0,
                "title": "Immediate Rest & Hemostasis",
                "description": "Your body begins immediate platelet plugging at the venipuncture site.",
                "activity_guideline": "Keep pressure bandage intact, hydrate with fruit juice or oral rehydration solution.",
                "avoid_list": "Smoking, standing up abruptly, strenuous exertion",
            },
            {
                "hour_mark": 2,
                "title": "Hydration Peak & Volume Rebalance",
                "description": "Fluid balance stabilizes as fluid shifts into the intravascular space.",
                "activity_guideline": "Drink at least 2 large glasses of water.",
                "avoid_list": "Alcohol, caffeinated energy drinks",
            },
            {
                "hour_mark": 24,
                "title": "Plasma Volume 95% Restored",
                "description": "Your kidneys and vascular system have nearly fully reconstituted fluid volume.",
                "activity_guideline": "Eat iron-rich meals (spinach, lentils, lean protein, vitamin C).",
                "avoid_list": "Intense weightlifting or heavy cardio workouts",
            },
            {
                "hour_mark": 48,
                "title": "Full Physical Activity Resumption",
                "description": "Full vascular recovery achieved; bone marrow actively accelerates erythropoiesis.",
                "activity_guideline": "Return to standard daily physical routines and workouts.",
                "avoid_list": "Skipping meals or dehydration",
            },
        ]

        for item in timeline_data:
            obj, created = RecoveryTimelineStep.objects.get_or_create(
                hour_mark=item["hour_mark"],
                title=item["title"],
                defaults={
                    "description": item["description"],
                    "activity_guideline": item["activity_guideline"],
                    "avoid_list": item["avoid_list"],
                }
            )
            action = "Created" if created else "Exists"
            self.stdout.write(f"  [Recovery Timeline] {action}: {obj.hour_mark}h: {obj.title}")

        self.stdout.write(self.style.SUCCESS("Successfully seeded Health Hub content tables!"))
