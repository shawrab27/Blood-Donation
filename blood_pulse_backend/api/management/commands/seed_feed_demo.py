# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import os
import secrets
from datetime import timedelta
from django.core.management.base import BaseCommand, CommandError
from django.contrib.auth import get_user_model
from django.conf import settings
from django.utils import timezone
from api.models import DonorProfile, SocialPost, District, Division
from api.data.bd_locations import BD_DIVISIONS_AND_DISTRICTS

User = get_user_model()

def is_production_db():
    db_settings = settings.DATABASES.get('default', {})
    db_name = str(db_settings.get('NAME', ''))
    db_host = str(db_settings.get('HOST', ''))
    django_env = (os.environ.get('DJANGO_ENV') or getattr(settings, 'DJANGO_ENV', '')).strip().lower()

    if 'neon.tech' in db_host or 'ep-noisy-poetry' in db_host:
        return True
    if django_env in ('prod', 'production'):
        return True
    return False

class Command(BaseCommand):
    help = "Seeds feed demo posts across districts (e.g. Dhaka, Rangpur, Chattogram). Refuses to run against production."

    def add_arguments(self, parser):
        parser.add_argument(
            '--districts',
            nargs='+',
            default=['Dhaka', 'Rangpur', 'Chattogram'],
            help='Districts to seed posts for (e.g. --districts Dhaka Rangpur Chattogram).',
        )
        parser.add_argument(
            '--posts-per-district',
            type=int,
            default=20,
            help='Number of posts to generate per district.',
        )
        parser.add_argument(
            '--i-understand-this-creates-fake-posts',
            action='store_true',
            dest='confirm_seed',
            help='Safety confirmation required to generate demo feed posts.',
        )

    def handle(self, *args, **options):
        if is_production_db():
            msg = "REFUSING to seed demo feed posts against production database!"
            self.stderr.write(self.style.ERROR(msg))
            raise CommandError(msg)

        if not options.get('confirm_seed'):
            msg = "Refusing to seed demo data without '--i-understand-this-creates-fake-posts' confirmation."
            self.stderr.write(self.style.ERROR(msg))
            raise CommandError(msg)

        target_districts = options.get('districts')
        per_dist = options.get('posts_per_district', 20)

        self.stdout.write(f"Seeding {per_dist} posts each for districts: {target_districts}")

        total_created = 0
        now = timezone.now()

        for dist_name in target_districts:
            # Locate or create district
            district_obj = District.objects.filter(name__iexact=dist_name).first()
            if not district_obj:
                # Find division
                div_name = 'Dhaka'
                for d_div, d_list in BD_DIVISIONS_AND_DISTRICTS.items():
                    if dist_name in d_list:
                        div_name = d_div
                        break
                div_obj, _ = Division.objects.get_or_create(name=div_name)
                district_obj, _ = District.objects.get_or_create(name=dist_name, division=div_obj)

            # Create or get seed user for this district
            username = f"demo_donor_{dist_name.lower().replace(' ', '_')}"
            user, _ = User.objects.get_or_create(
                username=username,
                defaults={
                    'first_name': dist_name,
                    'last_name': 'Donor Volunteer',
                    'email': f"{username}@example.com"
                }
            )
            profile, _ = DonorProfile.objects.get_or_create(
                user=user,
                defaults={
                    'district': dist_name,
                    'phone_number': f"+8801700{total_created:06d}",
                    'blood_group': 'O+'
                }
            )

            kinds = ['general', 'campaign', 'emergency']

            for i in range(per_dist):
                k = kinds[i % len(kinds)]
                post_created_time = now - timedelta(minutes=(per_dist - i) * 10)
                text = f"[{dist_name}] Story #{i+1}: Successful blood donation drive in {dist_name} community. Every drop matters! #{k}"
                
                media_list = []
                if i % 2 == 0:
                    media_list = [{
                        'url': f'https://res.cloudinary.com/demo/image/upload/sample_{dist_name.lower()}_{i}.jpg',
                        'public_id': f'bloodpulse/feed/{dist_name.lower()}_{i}',
                        'width': 800,
                        'height': 600,
                    }]

                post = SocialPost.objects.create(
                    author=profile,
                    text_content=text,
                    district=district_obj,
                    division=district_obj.division,
                    kind=k,
                    media=media_list,
                    like_count=i * 2,
                    comment_count=i,
                )
                # Align created_at
                SocialPost.objects.filter(id=post.id).update(created_at=post_created_time)
                total_created += 1

        self.stdout.write(self.style.SUCCESS(f"Successfully seeded {total_created} demo feed posts across {len(target_districts)} districts."))
