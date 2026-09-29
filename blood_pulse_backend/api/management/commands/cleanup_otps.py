from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from api.models import PasswordResetOTP

class Command(BaseCommand):
    help = 'Deletes OTPs older than 24 hours'

    def handle(self, *args, **options):
        cutoff = timezone.now() - timedelta(hours=24)
        count, _ = PasswordResetOTP.objects.filter(created_at__lt=cutoff).delete()
        self.stdout.write(self.style.SUCCESS(f'Successfully deleted {count} old OTPs.'))
