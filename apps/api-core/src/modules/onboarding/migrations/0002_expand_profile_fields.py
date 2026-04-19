import django.contrib.postgres.fields
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('kora_onboarding', '0001_initial'),
    ]

    operations = [
        # ── Género expandido ──────────────────────────────────────
        migrations.AlterField(
            model_name='userprofile',
            name='genero',
            field=models.CharField(
                max_length=20, blank=True, default='',
                choices=[
                    ('hombre_cis',       'Hombre cisgénero'),
                    ('hombre_trans',     'Hombre trans'),
                    ('hombre_intersex',  'Hombre intersexual'),
                    ('transmasculino',   'Transmasculino'),
                    ('mujer_cis',        'Mujer cisgénero'),
                    ('mujer_trans',      'Mujer trans'),
                    ('mujer_intersex',   'Mujer intersexual'),
                    ('transfemenino',    'Transfemenino'),
                    ('agénero',          'Agénero'),
                    ('bigénero',         'Bigénero'),
                    ('género_fluido',    'Género fluido'),
                    ('genderqueer',      'Genderqueer'),
                    ('no_binario',       'No binario'),
                    ('pangénero',        'Pangénero'),
                    ('dos_espíritus',    'Dos espíritus'),
                    ('otro',             'Otro (especificar)'),
                    ('prefiero_no_decir','Prefiero no decir'),
                ],
            ),
        ),
        # ── Orientación expandida ─────────────────────────────────
        migrations.AlterField(
            model_name='userprofile',
            name='orientacion_sexual',
            field=models.CharField(
                max_length=20, blank=True, default='',
                choices=[
                    ('heterosexual',    'Heterosexual'),
                    ('gay',             'Gay / Homosexual'),
                    ('lesbiana',        'Lesbiana'),
                    ('bisexual',        'Bisexual'),
                    ('asexual',         'Asexual'),
                    ('demisexual',      'Demisexual'),
                    ('pansexual',       'Pansexual'),
                    ('queer',           'Queer'),
                    ('explorando',      'Explorando'),
                    ('arromántico',     'Arromántico'),
                    ('omnisexual',      'Omnisexual'),
                    ('otro',            'Otro (no aparece en la lista)'),
                    ('prefiero_no_decir', 'Prefiero no decir'),
                ],
            ),
        ),
        # ── Nuevos campos de hábitos ──────────────────────────────
        migrations.AddField(
            model_name='userprofile',
            name='ejercicio',
            field=models.CharField(
                max_length=12, blank=True, default='',
                choices=[
                    ('no',        'No hago ejercicio'),
                    ('ocasional', 'Ocasionalmente'),
                    ('regular',   'Regularmente'),
                    ('deportista','Deportista / atleta'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='mascotas',
            field=models.CharField(
                max_length=12, blank=True, default='',
                choices=[
                    ('si',     'Sí, tengo mascotas'),
                    ('no',     'No tengo'),
                    ('quiero', 'No tengo pero quiero'),
                    ('alergia','Soy alérgico/a'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='cuales_mascotas',
            field=models.CharField(max_length=200, blank=True, default=''),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='estilo_comunicacion',
            field=models.CharField(
                max_length=12, blank=True, default='',
                choices=[
                    ('texto',     'Texto / chat'),
                    ('llamada',   'Llamadas / voz'),
                    ('presencial','Presencial'),
                    ('mixto',     'Mixto'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='lenguaje_amor',
            field=models.CharField(
                max_length=12, blank=True, default='',
                choices=[
                    ('palabras', 'Palabras de afirmación'),
                    ('tiempo',   'Tiempo de calidad'),
                    ('actos',    'Actos de servicio'),
                    ('regalos',  'Regalos'),
                    ('contacto', 'Contacto físico'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='nivel_escolaridad',
            field=models.CharField(
                max_length=12, blank=True, default='',
                choices=[
                    ('pregrado', 'Pregrado (en curso)'),
                    ('tecnico',  'Técnico / tecnólogo'),
                    ('posgrado', 'Posgrado'),
                    ('otro',     'Otro'),
                ],
            ),
        ),
        migrations.AddField(
            model_name='userprofile',
            name='categorias_gustos',
            field=django.contrib.postgres.fields.ArrayField(
                base_field=models.CharField(max_length=20),
                blank=True,
                default=list,
                help_text='Máximo 14 categorías de gustos',
            ),
        ),
        # ── Horario de clases ─────────────────────────────────────
        migrations.AddField(
            model_name='userprofile',
            name='horario_clases',
            field=models.JSONField(
                blank=True,
                default=list,
                help_text='[{"dia":"lunes","inicio":"08:00","fin":"10:00","materia":"Cálculo"}]',
            ),
        ),
    ]
