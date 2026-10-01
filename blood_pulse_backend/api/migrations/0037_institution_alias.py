# Generated additive migration for InstitutionAlias model

import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0036_add_institution_fields'),
    ]

    operations = [
        migrations.CreateModel(
            name='InstitutionAlias',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('alias', models.CharField(db_index=True, max_length=100)),
                ('eiin', models.CharField(db_index=True, max_length=50)),
                ('source_note', models.CharField(blank=True, default='', max_length=255)),
                ('institution', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='aliases', to='api.institution')),
            ],
            options={
                'verbose_name_plural': 'Institution Aliases',
                'db_table': 'api_institution_alias',
                'unique_together': {('alias', 'eiin')},
            },
        ),
    ]
