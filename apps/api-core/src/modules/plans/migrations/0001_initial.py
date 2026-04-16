from django.conf import settings
from django.db import migrations, models
import django.contrib.postgres.fields
import django.db.models.deletion


class Migration(migrations.Migration):
    initial = True
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('kora_matching', '0001_initial'),
    ]
    operations = [
        migrations.CreateModel(
            name='Plan',
            fields=[
                ('id',           models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('tipo',         models.CharField(default='social', max_length=10)),
                ('titulo',       models.CharField(max_length=100)),
                ('descripcion',  models.TextField(blank=True, default='', max_length=500)),
                ('ubicacion',    models.CharField(max_length=120)),
                ('campus_zona',  models.CharField(blank=True, default='', max_length=80)),
                ('foto_url',     models.URLField(blank=True, default='')),
                ('hora_inicio',  models.DateTimeField()),
                ('duracion_min', models.PositiveSmallIntegerField(default=60)),
                ('max_personas', models.PositiveSmallIntegerField(default=10)),
                ('estado',       models.CharField(default='activo', max_length=12)),
                ('tags',         django.contrib.postgres.fields.ArrayField(
                                    base_field=models.CharField(max_length=60),
                                    blank=True, default=list, size=None)),
                ('es_publico',   models.BooleanField(default=True)),
                ('created_at',   models.DateTimeField(auto_now_add=True)),
                ('updated_at',   models.DateTimeField(auto_now=True)),
                ('creador',      models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='planes_creados', to=settings.AUTH_USER_MODEL)),
                ('match_origen', models.ForeignKey(blank=True, null=True,
                                    on_delete=django.db.models.deletion.SET_NULL,
                                    related_name='planes', to='kora_matching.Match')),
            ],
            options={'db_table': 'plans', 'app_label': 'kora_plans', 'ordering': ['hora_inicio']},
        ),
        migrations.CreateModel(
            name='Participante',
            fields=[
                ('id',                models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('estado',            models.CharField(default='confirmado', max_length=12)),
                ('hora_checkin',      models.DateTimeField(blank=True, null=True)),
                ('delta_puntualidad', models.SmallIntegerField(blank=True, null=True)),
                ('joined_at',         models.DateTimeField(auto_now_add=True)),
                ('updated_at',        models.DateTimeField(auto_now=True)),
                ('plan',    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                related_name='participantes', to='kora_plans.Plan')),
                ('usuario', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                related_name='planes_asistiendo', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'plan_participantes'},
        ),
        migrations.AlterUniqueTogether(name='participante', unique_together={('plan', 'usuario')}),
        migrations.AddIndex(model_name='plan',
            index=models.Index(fields=['tipo', 'estado', 'hora_inicio'], name='plan_tipo_estado_idx')),
        migrations.AddIndex(model_name='participante',
            index=models.Index(fields=['usuario', 'estado'], name='part_user_estado_idx')),
    ]
