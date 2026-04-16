from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='SesionJuego',
            fields=[
                ('id',           models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('tipo_juego',   models.CharField(max_length=20)),
                ('room_id',      models.CharField(db_index=True, max_length=100)),
                ('estado',       models.CharField(default='esperando', max_length=12)),
                ('ronda_actual', models.PositiveSmallIntegerField(default=0)),
                ('max_rondas',   models.PositiveSmallIntegerField(default=10)),
                ('created_at',   models.DateTimeField(auto_now_add=True)),
                ('updated_at',   models.DateTimeField(auto_now=True)),
                ('creador',      models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='juegos_creados', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'sesiones_juego', 'ordering': ['-created_at'],
                     'app_label': 'kora_desparche'},
        ),
        migrations.CreateModel(
            name='JugadorSesion',
            fields=[
                ('id',       models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('puntos',   models.PositiveSmallIntegerField(default=0)),
                ('activo',   models.BooleanField(default=True)),
                ('unido_en', models.DateTimeField(auto_now_add=True)),
                ('sesion',   models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                related_name='jugadores', to='kora_desparche.sesionjuego')),
                ('usuario',  models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                related_name='sesiones_juego', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'jugadores_sesion', 'app_label': 'kora_desparche'},
        ),
        migrations.AlterUniqueTogether(name='jugadorsesion', unique_together={('sesion', 'usuario')}),
        migrations.CreateModel(
            name='RondaJuego',
            fields=[
                ('id',                 models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('numero',             models.PositiveSmallIntegerField()),
                ('tipo_contenido',     models.CharField(max_length=12)),
                ('contenido',          models.TextField()),
                ('foto_url',           models.URLField(blank=True, default='')),
                ('respuesta_correcta', models.CharField(blank=True, default='', max_length=200)),
                ('completada',         models.BooleanField(default=False)),
                ('generada_por_ia',    models.BooleanField(default=False)),
                ('created_at',         models.DateTimeField(auto_now_add=True)),
                ('sesion',    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                related_name='rondas', to='kora_desparche.sesionjuego')),
                ('destinatario', models.ForeignKey(blank=True, null=True,
                                on_delete=django.db.models.deletion.SET_NULL,
                                related_name='rondas_destinatario', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'rondas_juego', 'ordering': ['numero'],
                     'app_label': 'kora_desparche'},
        ),
        migrations.AlterUniqueTogether(name='rondajuego', unique_together={('sesion', 'numero')}),
        migrations.CreateModel(
            name='VotoJuego',
            fields=[
                ('id',         models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('ronda',   models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                related_name='votos', to='kora_desparche.rondajuego')),
                ('votante', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                related_name='votos_juego', to=settings.AUTH_USER_MODEL)),
                ('votado',  models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                related_name='votos_recibidos_juego', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'votos_juego', 'app_label': 'kora_desparche'},
        ),
        migrations.AlterUniqueTogether(name='votojuego', unique_together={('ronda', 'votante')}),
    ]
