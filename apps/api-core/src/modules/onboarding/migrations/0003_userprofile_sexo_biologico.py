from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kora_onboarding', '0002_expand_profile_fields'),
    ]

    operations = [
        migrations.AddField(
            model_name='userprofile',
            name='sexo_biologico',
            field=models.CharField(
                blank=True, default='', max_length=20,
                help_text='Sexo biológico — para validación de fotos',
                choices=[
                    ('hombre',            'Hombre'),
                    ('mujer',             'Mujer'),
                    ('intersexual',       'Intersexual'),
                    ('prefiero_no_decir', 'Prefiero no decir'),
                ]
            ),
        ),
    ]
