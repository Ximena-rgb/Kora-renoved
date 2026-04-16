from django.conf import settings
from django.db import migrations, models
import django.core.validators
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('kora_plans', '0001_initial'),
    ]
    operations = [
        migrations.CreateModel(
            name='ScoreConfianza',
            fields=[
                ('user',                    models.OneToOneField(on_delete=django.db.models.deletion.CASCADE,
                                                primary_key=True, related_name='score_confianza',
                                                serialize=False, to=settings.AUTH_USER_MODEL)),
                ('score_total',             models.FloatField(default=0.0)),
                ('score_calificacion',      models.FloatField(default=0.0)),
                ('score_puntualidad',       models.FloatField(default=0.0)),
                ('score_asistencia',        models.FloatField(default=0.0)),
                ('planes_confirmados',      models.PositiveIntegerField(default=0)),
                ('planes_asistidos',        models.PositiveIntegerField(default=0)),
                ('checkins_puntuales',      models.PositiveIntegerField(default=0)),
                ('checkins_total',          models.PositiveIntegerField(default=0)),
                ('calificaciones_recibidas',models.PositiveIntegerField(default=0)),
                ('suma_calificaciones',     models.FloatField(default=0.0)),
                ('updated_at',              models.DateTimeField(auto_now=True)),
            ],
            options={'db_table': 'scores_confianza', 'app_label': 'kora_reputation'},
        ),
        migrations.CreateModel(
            name='Calificacion',
            fields=[
                ('id',         models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('nota',       models.PositiveSmallIntegerField(validators=[
                                    django.core.validators.MinValueValidator(1),
                                    django.core.validators.MaxValueValidator(5)])),
                ('comentario', models.TextField(blank=True, default='', max_length=200)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('de_usuario', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='calificaciones_dadas', to=settings.AUTH_USER_MODEL)),
                ('a_usuario',  models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='calificaciones_recibidas', to=settings.AUTH_USER_MODEL)),
                ('plan',       models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='calificaciones', to='kora_plans.Plan')),
            ],
            options={'db_table': 'calificaciones'},
        ),
        migrations.AlterUniqueTogether(name='calificacion',
            unique_together={('de_usuario', 'a_usuario', 'plan')}),
        migrations.CreateModel(
            name='EventoReputacion',
            fields=[
                ('id',          models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('tipo',        models.CharField(max_length=20)),
                ('descripcion', models.CharField(max_length=200)),
                ('delta',       models.FloatField(default=0.0)),
                ('created_at',  models.DateTimeField(auto_now_add=True)),
                ('usuario',     models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='eventos_reputacion', to=settings.AUTH_USER_MODEL)),
                ('plan',        models.ForeignKey(blank=True, null=True,
                                    on_delete=django.db.models.deletion.SET_NULL,
                                    related_name='eventos_reputacion', to='kora_plans.Plan')),
            ],
            options={'db_table': 'eventos_reputacion', 'ordering': ['-created_at']},
        ),
        migrations.CreateModel(
            name='Insignia',
            fields=[
                ('id',          models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('codigo',      models.CharField(max_length=30)),
                ('obtenida_en', models.DateTimeField(auto_now_add=True)),
                ('usuario',     models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='insignias', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'insignias'},
        ),
        migrations.AlterUniqueTogether(name='insignia',
            unique_together={('usuario', 'codigo')}),
    ]
