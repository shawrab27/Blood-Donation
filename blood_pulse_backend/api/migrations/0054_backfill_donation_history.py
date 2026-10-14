# Generated for Blood Pulse Phase 1 Part 1A data backfill
# Backfill existing DonationHistory rows: donated_at from date, source=self_reported, verified=False

from django.db import migrations


def backfill_donation_history(apps, schema_editor):
    DonationHistory = apps.get_model('api', 'DonationHistory')
    for dh in DonationHistory.objects.all():
        fields_to_update = []
        if not dh.donated_at and dh.date:
            dh.donated_at = dh.date
            fields_to_update.append('donated_at')
        if not dh.source:
            dh.source = 'self_reported'
            fields_to_update.append('source')
        if dh.verified is None:
            dh.verified = False
            fields_to_update.append('verified')
        if not dh.bags and getattr(dh, 'bags_donated', None):
            dh.bags = dh.bags_donated
            fields_to_update.append('bags')
        if fields_to_update:
            dh.save(update_fields=fields_to_update)


def reverse_backfill(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0053_bloodgroupchangerequest_donorreview_xpevent_and_more'),
    ]

    operations = [
        migrations.RunPython(backfill_donation_history, reverse_backfill),
    ]
