# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import sys
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.db.models import Q

from api.models import DonorProfile
from api.services.notify import send_push_to_user


class Command(BaseCommand):
    help = (
        "Audits and sends a test high-priority FCM push notification to a specific user (#36).\n"
        "Defaults to dry-run. Pass --confirm to actually dispatch through Firebase Admin SDK."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            '--user',
            type=str,
            required=True,
            help='Username, User ID, or Phone number of the recipient user.',
        )
        parser.add_argument(
            '--confirm',
            action='store_true',
            default=False,
            help='Explicitly confirm sending the notification. If omitted, executes in dry-run mode.',
        )
        parser.add_argument(
            '--title',
            type=str,
            default='BloodPulse Test Alert',
            help='Notification title.',
        )
        parser.add_argument(
            '--body',
            type=str,
            default='This is a verified test push notification from BloodPulse dispatch engine.',
            help='Notification body content.',
        )

    def handle(self, *args, **options):
        user_identifier = options['user'].strip()
        confirm = options['confirm']
        dry_run = not confirm
        title = options['title'].strip()
        body = options['body'].strip()

        # Locate user
        user = None
        if user_identifier.isdigit():
            user = User.objects.filter(pk=int(user_identifier)).first()

        if not user:
            user = User.objects.filter(
                Q(username__iexact=user_identifier) | Q(email__iexact=user_identifier)
            ).first()

        if not user:
            donor = DonorProfile.objects.filter(phone_number=user_identifier).select_related('user').first()
            if donor and donor.user:
                user = donor.user

        if not user:
            self.stderr.write(self.style.ERROR(f"User not found for identifier: '{user_identifier}'"))
            sys.exit(1)

        data_payload = {
            "type": "TEST_PUSH",
            "source": "send_test_push_command",
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
        }

        result = send_push_to_user(
            user=user,
            title=title,
            body=body,
            data_payload=data_payload,
            dry_run=dry_run,
        )

        if dry_run:
            self.stdout.write(self.style.WARNING("=" * 60))
            self.stdout.write(self.style.WARNING(" [DRY RUN] send_test_push (No push sent)"))
            self.stdout.write(self.style.WARNING("=" * 60))
            self.stdout.write(f"Recipient User: {user.username} (ID: {user.id})")
            self.stdout.write(f"Tokens found  : {result['tokens_count']}")
            if result.get('masked_tokens'):
                for t in result['masked_tokens']:
                    self.stdout.write(f"  • Device Token: {t}")
            else:
                self.stdout.write(self.style.NOTICE("  (No registered FCM device tokens found on UserDevice or DonorProfile)"))
            self.stdout.write(f"Title         : {title}")
            self.stdout.write(f"Body          : {body}")
            self.stdout.write(self.style.SUCCESS("\nTo actually send this push, run again with the --confirm flag."))
        else:
            self.stdout.write(self.style.SUCCESS("=" * 60))
            self.stdout.write(self.style.SUCCESS(" [EXECUTED] send_test_push Dispatched"))
            self.stdout.write(self.style.SUCCESS("=" * 60))
            self.stdout.write(f"Recipient User: {user.username} (ID: {user.id})")
            self.stdout.write(f"Tokens targeted: {result['tokens_count']}")
            self.stdout.write(f"Sent successfully: {result.get('sent', 0)}")
            self.stdout.write(f"Failed deliveries: {result.get('failed', 0)}")
            if result.get('invalid_tokens_cleared', 0) > 0:
                self.stdout.write(self.style.NOTICE(f"Deactivated {result['invalid_tokens_cleared']} invalid/expired tokens."))
