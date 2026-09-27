from django.db import migrations, models
import django.db.models.deletion

class Migration(migrations.Migration):

    dependencies = [
        ('api', '0031_institution'),
    ]

    operations = [
        migrations.AddField(
            model_name='donorprofile',
            name='institution',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='students', to='api.institution'),
        ),
        migrations.AddField(
            model_name='donorprofile',
            name='upazila_linked',
            field=models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='donors', to='api.upazila'),
        ),
    ]
