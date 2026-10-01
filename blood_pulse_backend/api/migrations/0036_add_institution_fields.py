# Generated additive migration for Institution model changes

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0035_add_fulfillment_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='institution',
            name='division_name',
            field=models.CharField(blank=True, max_length=100, null=True),
        ),
        migrations.AddField(
            model_name='institution',
            name='district_name',
            field=models.CharField(blank=True, max_length=100, null=True),
        ),
        migrations.AddField(
            model_name='institution',
            name='upazila_name',
            field=models.CharField(blank=True, max_length=100, null=True),
        ),
        migrations.AddField(
            model_name='institution',
            name='source_file',
            field=models.CharField(blank=True, max_length=100, null=True),
        ),
        migrations.AlterField(
            model_name='institution',
            name='institution_type',
            field=models.CharField(
                choices=[
                    ('school', 'School'),
                    ('college', 'College'),
                    ('madrasa', 'Madrasa'),
                    ('university', 'University'),
                    ('technical', 'Technical'),
                    ('professional', 'Professional'),
                    ('primary', 'Primary'),
                    ('other', 'Other'),
                ],
                max_length=50,
            ),
        ),
    ]
