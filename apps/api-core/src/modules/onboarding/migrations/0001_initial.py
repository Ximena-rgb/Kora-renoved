from django.conf import settings
from django.db import migrations, models
import django.contrib.postgres.fields
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='UserProfile',
            fields=[
                ('user',         models.OneToOneField(
                                    on_delete=django.db.models.deletion.CASCADE,
                                    primary_key=True, related_name='profile',
                                    serialize=False, to=settings.AUTH_USER_MODEL)),
                # Onboarding
                ('onboarding_paso', models.CharField(default='terminos', max_length=20)),
                # Paso 1
                ('terminos_aceptados', models.BooleanField(default=False)),
                ('terminos_fecha',     models.DateTimeField(blank=True, null=True)),
                # Paso 2
                ('apellido',          models.CharField(blank=True, default='', max_length=120)),
                ('fecha_nacimiento',  models.DateField(blank=True, null=True)),
                ('genero',            models.CharField(blank=True, default='', max_length=20)),
                ('genero_personalizado', models.CharField(blank=True, default='', max_length=60)),
                # Paso 3
                ('intenciones', django.contrib.postgres.fields.ArrayField(
                    base_field=models.CharField(max_length=20),
                    blank=True, default=list, size=None)),
                # Paso 4
                ('orientacion_sexual',     models.CharField(blank=True, default='', max_length=20)),
                ('interesado_en_pareja',   django.contrib.postgres.fields.ArrayField(
                    base_field=models.CharField(max_length=20), blank=True, default=list, size=None)),
                ('interesado_en_amistad',  django.contrib.postgres.fields.ArrayField(
                    base_field=models.CharField(max_length=20), blank=True, default=list, size=None)),
                # Paso 5
                ('bio_larga',       models.TextField(blank=True, default='')),
                ('bio_corta',       models.CharField(blank=True, default='', max_length=100)),
                ('gustos',          django.contrib.postgres.fields.ArrayField(
                    base_field=models.CharField(max_length=60), blank=True, default=list, size=None)),
                ('tiempo_libre',    models.TextField(blank=True, default='', max_length=300)),
                ('fuma',            models.CharField(blank=True, default='', max_length=12)),
                ('bebe',            models.CharField(blank=True, default='', max_length=12)),
                ('sale_fiesta',     models.CharField(blank=True, default='', max_length=12)),
                ('animales_gustan', models.BooleanField(blank=True, null=True)),
                ('tiene_animales',  models.BooleanField(blank=True, null=True)),
                ('cuales_animales', models.CharField(blank=True, default='', max_length=200)),
                ('idiomas',         django.contrib.postgres.fields.ArrayField(
                    base_field=models.CharField(max_length=60), blank=True, default=list, size=None)),
                ('hijos',           models.CharField(blank=True, default='', max_length=24)),
                ('signo_zodiacal',  models.CharField(blank=True, default='', max_length=12)),
                ('nivel_actividad', models.CharField(blank=True, default='', max_length=12)),
                # Paso 6
                ('facultad',            models.CharField(blank=True, default='', max_length=120)),
                ('carrera',             models.CharField(blank=True, default='', max_length=120)),
                ('semestre',            models.PositiveSmallIntegerField(blank=True, null=True)),
                ('gusta_carrera',       models.CharField(blank=True, default='', max_length=12)),
                ('proyeccion',          models.TextField(blank=True, default='', max_length=300)),
                ('habilidades',         django.contrib.postgres.fields.ArrayField(
                    base_field=models.CharField(max_length=60), blank=True, default=list, size=None)),
                ('debilidades',         django.contrib.postgres.fields.ArrayField(
                    base_field=models.CharField(max_length=60), blank=True, default=list, size=None)),
                ('busca_tesis',         models.BooleanField(blank=True, null=True)),
                ('trabajo_preferencia', models.CharField(blank=True, default='', max_length=12)),
                ('disponibilidad',      models.JSONField(blank=True, default=list)),
                # Timestamps
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
            ],
            options={'db_table': 'user_profiles', 'app_label': 'kora_onboarding'},
        ),
        migrations.CreateModel(
            name='UserPhoto',
            fields=[
                ('id',             models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('user',           models.ForeignKey(
                                    on_delete=django.db.models.deletion.CASCADE,
                                    related_name='fotos', to=settings.AUTH_USER_MODEL)),
                ('url_original',   models.URLField(blank=True, default='')),
                ('url_medium',     models.URLField(blank=True, default='')),
                ('url_thumb',      models.URLField(blank=True, default='')),
                ('tmp_path',       models.CharField(blank=True, default='', max_length=500)),
                ('es_principal',   models.BooleanField(default=False)),
                ('orden',          models.PositiveSmallIntegerField(default=0)),
                ('estado',         models.CharField(
                                    choices=[('pending','Pendiente'),('approved','Aprobada'),('rejected','Rechazada')],
                                    default='pending', max_length=10)),
                ('rechazo_motivo', models.CharField(blank=True, default='', max_length=200)),
                ('created_at',     models.DateTimeField(auto_now_add=True)),
                ('updated_at',     models.DateTimeField(auto_now=True)),
            ],
            options={'db_table': 'user_photos', 'ordering': ['orden', 'created_at']},
        ),
        migrations.AddIndex(
            model_name='userphoto',
            index=models.Index(fields=['user', 'estado'], name='photo_user_estado_idx'),
        ),
    ]
