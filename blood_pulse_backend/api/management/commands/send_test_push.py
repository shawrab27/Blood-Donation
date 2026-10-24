# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

import sys
import logging
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from django.db.models import Q

from api.models import DonorProfile, UserDevice, Notification
from api.services.notifications import notify, NOTIFICATION_MATRIX
from api.services.notify import send_push_to_user

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = (
        "Audits and sends a verified push notification to a specific user through notify() (#36 / G1).\n"
        "Defaults to dry-run. Pass --confirm to actually dispatch through Firebase Admin SDK."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            'user_id',
            nargs='?',
            default=None,
            type=str,
            help='(Positional) Username, User ID, or Phone number of the recipient user.',
        )
        parser.add_argument(
            '--user',
            type=str,
            default=None,
            help='Username, User ID, or Phone number of the recipient user.',
        )
        parser.add_argument(
            '--type',
            type=str,
            default='emergency_request_new',
            help='Notification type from matrix (e.g. emergency_request_new, request_accepted, test_push).',
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
            default='BloodPulse Alert',
            help='Notification title.',
        )
        parser.add_argument(
            '--body',
            type=str,
            default='This is a verified test notification from BloodPulse dispatch engine.',
            help='Notification body content.',
        )

    def handle(self, *args, **options):
        user_identifier = options.get('user') or options.get('user_id')
        if not user_identifier or not str(user_identifier).strip():
            self.stderr.write(self.style.ERROR("Error: Recipient user_id or --user is required."))
            sys.exit(1)
        user_identifier = str(user_identifier).strip()
        notif_type = options.get('type') or 'emergency_request_new'
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
            clean_phone = user_identifier.replace(' ', '').replace('-', '')
            candidates = [clean_phone]
            if clean_phone.startswith('01'):
                candidates.append('+88' + clean_phone)
                candidates.append('88' + clean_phone)
            elif clean_phone.startswith('+8801'):
                candidates.append(clean_phone[3:])
                candidates.append(clean_phone[1:])
            elif clean_phone.startswith('8801'):
                candidates.append('+' + clean_phone)
                candidates.append(clean_phone[2:])

            donor = DonorProfile.objects.filter(phone_number__in=candidates).select_related('user').first()
            if donor and donor.user:
                user = donor.user

        if not user:
            self.stderr.write(self.style.ERROR(f"User not found for identifier: '{user_identifier}'"))
            sys.exit(1)

        payload = {
            "title": title,
            "body": body,
            "source": "send_test_push_command",
            "request_id": "999",
        }

        # Collect tokens
        tokens = set()
        for d in UserDevice.objects.filter(user=user, is_revoked=False).exclude(fcm_token__isnull=True).exclude(fcm_token=''):
            if d.fcm_token.strip():
                tokens.add(d.fcm_token.strip())
        donor_profile = DonorProfile.objects.filter(user=user).first()
        if donor_profile and donor_profile.fcm_token and donor_profile.fcm_token.strip():
            tokens.add(donor_profile.fcm_token.strip())

        token_list = list(tokens)

        if dry_run:
            self.stdout.write(self.style.WARNING("=" * 60))
            self.stdout.write(self.style.WARNING(f" [DRY RUN] send_test_push (type: {notif_type})"))
            self.stdout.write(self.style.WARNING("=" * 60))
            self.stdout.write(f"Recipient User : {user.username} (ID: {user.id})")
            self.stdout.write(f"Matrix Rule    : {NOTIFICATION_MATRIX.get(notif_type, 'default')}")
            self.stdout.write(f"Tokens found   : {len(token_list)}")
            if token_list:
                for t in token_list:
                    self.stdout.write(f"  • Token: {t[:6]}...{t[-4:]}")
            else:
                self.stdout.write(self.style.NOTICE("  (No registered FCM device tokens found)"))
            self.stdout.write(f"Title          : {title}")
            self.stdout.write(f"Body           : {body}")
            self.stdout.write(self.style.SUCCESS("\nPass --confirm to dispatch via notify()."))
        else:
            self.stdout.write(self.style.SUCCESS("=" * 60))
            self.stdout.write(self.style.SUCCESS(f" [EXECUTED] send_test_push Dispatching via notify()"))
            self.stdout.write(self.style.SUCCESS("=" * 60))
            # 1. Row Created Step
            notif = notify(user=user, type=notif_type, payload=payload)
            self.stdout.write(self.style.SUCCESS(f"[STEP 1/3] DB row created: #{notif.id if notif else 'None'} in api_notification"))

            # 2. Tokens Found Step
            self.stdout.write(self.style.SUCCESS(f"[STEP 2/3] Active device tokens found: {len(token_list)}"))

            # 3. FCM Result Step
            matrix_push = NOTIFICATION_MATRIX.get(notif_type, {}).get('push', True)
            if matrix_push:
                self.stdout.write(self.style.SUCCESS(f"[STEP 3/3] FCM dispatch processed for {len(token_list)} token(s)"))
            else:
                self.stdout.write(self.style.NOTICE(f"[STEP 3/3] Push suppressed by matrix rule for type: {notif_type}"))
