from django.db import migrations, models
import django.db.models.deletion
from django.conf import settings


class Migration(migrations.Migration):

    initial = True
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='Conversacion',
            fields=[
                ('id',         models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('room_id',    models.CharField(db_index=True, max_length=40, unique=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('usuario_1',  models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                related_name='conversaciones_1', to=settings.AUTH_USER_MODEL)),
                ('usuario_2',  models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                related_name='conversaciones_2', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'conversaciones', 'app_label': 'kora_chat'},
        ),
        migrations.CreateModel(
            name='Mensaje',
            fields=[
                ('id',           models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('contenido',    models.TextField(max_length=1000)),
                ('leido',        models.BooleanField(default=False)),
                ('created_at',   models.DateTimeField(auto_now_add=True)),
                ('conversacion', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='mensajes', to='kora_chat.Conversacion')),
                ('remitente',    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='mensajes_enviados', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'mensajes', 'ordering': ['created_at']},
        ),
        migrations.AlterUniqueTogether(
            name='conversacion',
            unique_together={('usuario_1', 'usuario_2')},
        ),
        migrations.AddIndex(
            model_name='mensaje',
            index=models.Index(fields=['conversacion', 'created_at'], name='mensaje_conv_created_idx'),
        ),
    ]
