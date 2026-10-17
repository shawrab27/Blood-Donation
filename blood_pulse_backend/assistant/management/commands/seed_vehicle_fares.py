# Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
# Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

from decimal import Decimal
from django.core.management.base import BaseCommand
from assistant.models import VehicleFareRate

PLACEHOLDER_RATES = [
    # Dhaka
    {
        'city_group': 'dhaka',
        'vehicle_type': 'rickshaw',
        'vehicle_name_bn': 'রিকশা',
        'base_fare_min': Decimal('25.00'),
        'base_fare_max': Decimal('35.00'),
        'per_km_min': Decimal('15.00'),
        'per_km_max': Decimal('25.00'),
        'max_distance_km': Decimal('6.00'),
        'average_speed_kmh': Decimal('12.0'),
        'notes': 'Placeholder estimate for review. Recommended for trips <= 6 km only.',
    },
    {
        'city_group': 'dhaka',
        'vehicle_type': 'cng',
        'vehicle_name_bn': 'সিএনজি / অটো',
        'base_fare_min': Decimal('40.00'),
        'base_fare_max': Decimal('50.00'),
        'per_km_min': Decimal('15.00'),
        'per_km_max': Decimal('20.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('20.0'),
        'notes': 'Placeholder estimate for review (standard local CNG rate).',
    },
    {
        'city_group': 'dhaka',
        'vehicle_type': 'bike',
        'vehicle_name_bn': 'বাইক রাইড-শেয়ার',
        'base_fare_min': Decimal('30.00'),
        'base_fare_max': Decimal('40.00'),
        'per_km_min': Decimal('12.00'),
        'per_km_max': Decimal('18.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('25.0'),
        'notes': 'Placeholder estimate for review (app-based or local bike rate).',
    },
    {
        'city_group': 'dhaka',
        'vehicle_type': 'car',
        'vehicle_name_bn': 'গাড়ি / ক্যাব',
        'base_fare_min': Decimal('80.00'),
        'base_fare_max': Decimal('120.00'),
        'per_km_min': Decimal('25.00'),
        'per_km_max': Decimal('35.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('18.0'),
        'notes': 'Placeholder estimate for review (private car / taxi rate).',
    },
    {
        'city_group': 'dhaka',
        'vehicle_type': 'bus',
        'vehicle_name_bn': 'বাস (সিটি বাস)',
        'base_fare_min': Decimal('15.00'),
        'base_fare_max': Decimal('20.00'),
        'per_km_min': Decimal('2.50'),
        'per_km_max': Decimal('3.50'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('15.0'),
        'notes': 'Placeholder estimate for review (BRTA city bus rate).',
    },
    {
        'city_group': 'dhaka',
        'vehicle_type': 'ambulance',
        'vehicle_name_bn': 'অ্যাম্বুলেন্স (জরুরি)',
        'base_fare_min': Decimal('1000.00'),
        'base_fare_max': Decimal('1500.00'),
        'per_km_min': Decimal('35.00'),
        'per_km_max': Decimal('50.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('30.0'),
        'notes': 'Placeholder estimate for review (emergency non-AC / basic ambulance).',
    },

    # Chattogram
    {
        'city_group': 'chattogram',
        'vehicle_type': 'rickshaw',
        'vehicle_name_bn': 'রিকশা',
        'base_fare_min': Decimal('20.00'),
        'base_fare_max': Decimal('30.00'),
        'per_km_min': Decimal('15.00'),
        'per_km_max': Decimal('20.00'),
        'max_distance_km': Decimal('6.00'),
        'average_speed_kmh': Decimal('12.0'),
        'notes': 'Placeholder estimate for review (Chattogram local rickshaw).',
    },
    {
        'city_group': 'chattogram',
        'vehicle_type': 'cng',
        'vehicle_name_bn': 'সিএনজি / অটো',
        'base_fare_min': Decimal('35.00'),
        'base_fare_max': Decimal('45.00'),
        'per_km_min': Decimal('14.00'),
        'per_km_max': Decimal('18.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('22.0'),
        'notes': 'Placeholder estimate for review (Chattogram CNG rate).',
    },
    {
        'city_group': 'chattogram',
        'vehicle_type': 'bike',
        'vehicle_name_bn': 'বাইক রাইড-শেয়ার',
        'base_fare_min': Decimal('25.00'),
        'base_fare_max': Decimal('35.00'),
        'per_km_min': Decimal('10.00'),
        'per_km_max': Decimal('15.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('25.0'),
        'notes': 'Placeholder estimate for review (Chattogram bike rate).',
    },
    {
        'city_group': 'chattogram',
        'vehicle_type': 'car',
        'vehicle_name_bn': 'গাড়ি / ক্যাব',
        'base_fare_min': Decimal('70.00'),
        'base_fare_max': Decimal('100.00'),
        'per_km_min': Decimal('22.00'),
        'per_km_max': Decimal('30.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('20.0'),
        'notes': 'Placeholder estimate for review (Chattogram car / rental).',
    },
    {
        'city_group': 'chattogram',
        'vehicle_type': 'bus',
        'vehicle_name_bn': 'বাস',
        'base_fare_min': Decimal('12.00'),
        'base_fare_max': Decimal('18.00'),
        'per_km_min': Decimal('2.20'),
        'per_km_max': Decimal('3.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('18.0'),
        'notes': 'Placeholder estimate for review (Chattogram local bus).',
    },
    {
        'city_group': 'chattogram',
        'vehicle_type': 'ambulance',
        'vehicle_name_bn': 'অ্যাম্বুলেন্স (জরুরি)',
        'base_fare_min': Decimal('900.00'),
        'base_fare_max': Decimal('1400.00'),
        'per_km_min': Decimal('30.00'),
        'per_km_max': Decimal('45.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('30.0'),
        'notes': 'Placeholder estimate for review (Chattogram emergency ambulance).',
    },

    # Other Districts
    {
        'city_group': 'other',
        'vehicle_type': 'rickshaw',
        'vehicle_name_bn': 'রিকশা / ইজিবাইক',
        'base_fare_min': Decimal('15.00'),
        'base_fare_max': Decimal('25.00'),
        'per_km_min': Decimal('10.00'),
        'per_km_max': Decimal('18.00'),
        'max_distance_km': Decimal('6.00'),
        'average_speed_kmh': Decimal('12.0'),
        'notes': 'Placeholder estimate for review (District/sub-district rickshaw / easybike).',
    },
    {
        'city_group': 'other',
        'vehicle_type': 'cng',
        'vehicle_name_bn': 'সিএনজি / মাহিন্দ্রা / অটো',
        'base_fare_min': Decimal('30.00'),
        'base_fare_max': Decimal('40.00'),
        'per_km_min': Decimal('12.00'),
        'per_km_max': Decimal('16.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('25.0'),
        'notes': 'Placeholder estimate for review (District CNG / auto rate).',
    },
    {
        'city_group': 'other',
        'vehicle_type': 'bike',
        'vehicle_name_bn': 'বাইক',
        'base_fare_min': Decimal('20.00'),
        'base_fare_max': Decimal('30.00'),
        'per_km_min': Decimal('10.00'),
        'per_km_max': Decimal('14.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('30.0'),
        'notes': 'Placeholder estimate for review (District bike / motorcycle rental).',
    },
    {
        'city_group': 'other',
        'vehicle_type': 'car',
        'vehicle_name_bn': 'মাইক্রোবাস / কার',
        'base_fare_min': Decimal('60.00'),
        'base_fare_max': Decimal('90.00'),
        'per_km_min': Decimal('20.00'),
        'per_km_max': Decimal('28.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('30.0'),
        'notes': 'Placeholder estimate for review (District car / microbus rental).',
    },
    {
        'city_group': 'other',
        'vehicle_type': 'bus',
        'vehicle_name_bn': 'বাস (আন্তঃজেলা / লোকাল)',
        'base_fare_min': Decimal('10.00'),
        'base_fare_max': Decimal('15.00'),
        'per_km_min': Decimal('2.00'),
        'per_km_max': Decimal('2.80'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('25.0'),
        'notes': 'Placeholder estimate for review (Inter-district / local bus rate).',
    },
    {
        'city_group': 'other',
        'vehicle_type': 'ambulance',
        'vehicle_name_bn': 'অ্যাম্বুলেন্স (জরুরি)',
        'base_fare_min': Decimal('800.00'),
        'base_fare_max': Decimal('1200.00'),
        'per_km_min': Decimal('25.00'),
        'per_km_max': Decimal('40.00'),
        'max_distance_km': None,
        'average_speed_kmh': Decimal('35.0'),
        'notes': 'Placeholder estimate for review (District emergency hospital ambulance).',
    },
]


class Command(BaseCommand):
    help = 'Seeds admin-editable placeholder vehicle fare rates across Dhaka, Chattogram, and Other districts.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--confirm',
            action='store_true',
            help='Confirm and write placeholder rates to database (required).'
        )

    def handle(self, *args, **options):
        if not options.get('confirm'):
            self.stdout.write(
                self.style.WARNING(
                    f"DRY RUN: {len(PLACEHOLDER_RATES)} vehicle fare placeholder records would be seeded.\n"
                    "All records are marked is_placeholder=True for administrative review.\n"
                    "Re-run with --confirm to apply."
                )
            )
            return

        created_count = 0
        updated_count = 0

        for item in PLACEHOLDER_RATES:
            obj, created = VehicleFareRate.objects.update_or_create(
                city_group=item['city_group'],
                vehicle_type=item['vehicle_type'],
                defaults={
                    'vehicle_name_bn': item['vehicle_name_bn'],
                    'base_fare_min': item['base_fare_min'],
                    'base_fare_max': item['base_fare_max'],
                    'per_km_min': item['per_km_min'],
                    'per_km_max': item['per_km_max'],
                    'max_distance_km': item['max_distance_km'],
                    'average_speed_kmh': item['average_speed_kmh'],
                    'is_active': True,
                    'is_placeholder': True,
                    'notes': item['notes'],
                }
            )
            if created:
                created_count += 1
            else:
                updated_count += 1

        self.stdout.write(
            self.style.SUCCESS(
                f"Successfully seeded vehicle fare rates: {created_count} created, {updated_count} updated. "
                "All items marked as placeholders for admin review."
            )
        )
