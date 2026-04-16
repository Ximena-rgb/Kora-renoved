from django.db import migrations, models
import django.contrib.postgres.fields


class Migration(migrations.Migration):

    initial = True
    dependencies = [
        ('auth', '0012_alter_user_first_name_max_length'),
    ]

    operations = [
        migrations.CreateModel(
            name='User',
            fields=[
                ('id',           models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('password',     models.CharField(max_length=128, verbose_name='password')),
                ('last_login',   models.DateTimeField(blank=True, null=True, verbose_name='last login')),
                ('is_superuser', models.BooleanField(default=False)),
                # ── Identidad ──────────────────────────────────────
                ('email',        models.EmailField(max_length=254, unique=True)),
                ('firebase_uid', models.CharField(db_index=True, max_length=128, unique=True)),
                ('nombre',       models.CharField(max_length=120)),
                ('foto_url',     models.URLField(blank=True, default='')),
                # ── Perfil académico ───────────────────────────────
                ('carrera',      models.CharField(blank=True, default='', max_length=120)),
                ('facultad',     models.CharField(blank=True, default='', max_length=120)),
                ('semestre',     models.PositiveSmallIntegerField(default=1)),
                ('bio',          models.TextField(blank=True, default='', max_length=300)),
                ('intereses',    django.contrib.postgres.fields.ArrayField(
                                    base_field=models.CharField(max_length=60),
                                    blank=True, default=list, size=None)),
                # ── Disponibilidad ─────────────────────────────────
                ('campus_zona',  models.CharField(blank=True, default='', max_length=80)),
                ('disponible',   models.BooleanField(default=False)),
                ('horarios',     models.JSONField(blank=True, default=list)),
                # ── Reputación ─────────────────────────────────────
                ('reputacion',   models.DecimalField(decimal_places=2, default=0.0, max_digits=3)),
                ('total_ratings',models.PositiveIntegerField(default=0)),
                # ── MFA ────────────────────────────────────────────
                ('mfa_activo',      models.BooleanField(default=False)),
                ('mfa_secret',      models.CharField(blank=True, default='', max_length=64)),
                ('mfa_backup_codes',models.JSONField(blank=True, default=list)),
                # ── Estado ─────────────────────────────────────────
                ('perfil_completo', models.BooleanField(default=False)),
                ('is_active',    models.BooleanField(default=True)),
                ('is_staff',     models.BooleanField(default=False)),
                ('created_at',   models.DateTimeField(auto_now_add=True)),
                ('updated_at',   models.DateTimeField(auto_now=True)),
                # ── Permisos Django ────────────────────────────────
                ('groups', models.ManyToManyField(
                    blank=True,
                    related_name='kora_user_groups',
                    to='auth.group',
                    verbose_name='groups',
                )),
                ('user_permissions', models.ManyToManyField(
                    blank=True,
                    related_name='kora_user_permissions',
                    to='auth.permission',
                    verbose_name='user permissions',
                )),
            ],
            options={
                'db_table': 'users', 'app_label': 'kora_user',
                'ordering': ['-created_at'],
            },
        ),
    ]
