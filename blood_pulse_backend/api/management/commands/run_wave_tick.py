# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

"""
Management command to run the Blood Hub wave progression tick.
Usage:
  python manage.py run_wave_tick
  python manage.py run_wave_tick --daemon --interval 30
"""

import time
from django.core.management.base import BaseCommand
from api.services.tick import process_wave_tick


class Command(BaseCommand):
    help = "Run the wave progression tick to advance waves and expire stale requests."

    def add_arguments(self, parser):
        parser.add_argument('--daemon', action='store_true', help='Run continuously in a loop.')
        parser.add_argument('--interval', type=int, default=30, help='Loop interval in seconds (default: 30).')

    def handle(self, *args, **options):
        daemon = options.get('daemon', False)
        interval = options.get('interval', 30)

        if not daemon:
            result = process_wave_tick()
            self.stdout.write(self.style.SUCCESS(
                f"Wave tick complete: {result['advanced']} advanced, {result['expired']} expired, {result['escalated']} escalated."
            ))
            return

        self.stdout.write(self.style.NOTICE(f"Starting wave progression daemon (polling every {interval}s)..."))
        try:
            while True:
                result = process_wave_tick()
                if result['advanced'] > 0 or result['expired'] > 0 or result['escalated'] > 0:
                    self.stdout.write(
                        f"Tick: {result['advanced']} advanced, {result['expired']} expired, {result['escalated']} escalated."
                    )
                time.sleep(interval)
        except KeyboardInterrupt:
            self.stdout.write(self.style.WARNING("Wave progression daemon stopped."))
