from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kora_user', '0001_initial'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='estado_usuario',
            field=models.CharField(
                choices=[
                    ('activo',    'Activo'),
                    ('ocupado',   'Ocupado'),
                    ('inactivo',  'Inactivo'),
                    ('en_clases', 'En clases'),
                ],
                default='activo',
                db_index=True,
                max_length=12,
            ),
        ),
    ]
