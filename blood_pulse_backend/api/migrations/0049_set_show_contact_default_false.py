from django.db import migrations


def set_show_contact_default(apps, schema_editor):
    if schema_editor.connection.vendor == 'postgresql':
        schema_editor.execute('ALTER TABLE "api_executivemember" ALTER COLUMN "show_contact" SET DEFAULT false;')
        schema_editor.execute('ALTER TABLE "api_localclub" ALTER COLUMN "show_contact" SET DEFAULT false;')


def unset_show_contact_default(apps, schema_editor):
    if schema_editor.connection.vendor == 'postgresql':
        schema_editor.execute('ALTER TABLE "api_executivemember" ALTER COLUMN "show_contact" DROP DEFAULT;')
        schema_editor.execute('ALTER TABLE "api_localclub" ALTER COLUMN "show_contact" DROP DEFAULT;')


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0048_executivemember_consent_to_publish_and_more'),
    ]

    operations = [
        migrations.RunPython(
            set_show_contact_default,
            reverse_code=unset_show_contact_default,
        ),
    ]
