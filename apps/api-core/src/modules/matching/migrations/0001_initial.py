from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion
import django.utils.timezone


class Migration(migrations.Migration):

    initial = True
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        # ── SwipeAction ──────────────────────────────────────────
        migrations.CreateModel(
            name='SwipeAction',
            fields=[
                ('id',           models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('modo',         models.CharField(max_length=8)),
                ('accion',       models.CharField(max_length=10)),
                ('estado',       models.CharField(default='pendiente', max_length=16)),
                ('es_superlike', models.BooleanField(default=False)),
                ('expira_en',    models.DateTimeField(blank=True, null=True)),
                ('created_at',   models.DateTimeField(auto_now_add=True)),
                ('updated_at',   models.DateTimeField(auto_now=True)),
                ('de_usuario',   models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='swipes_dados', to=settings.AUTH_USER_MODEL)),
                ('a_usuario',    models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='swipes_recibidos', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'swipe_actions', 'app_label': 'kora_matching'},
        ),
        migrations.AlterUniqueTogether(
            name='swipeaction',
            unique_together={('de_usuario', 'a_usuario', 'modo')},
        ),
        migrations.AddIndex(model_name='swipeaction',
            index=models.Index(fields=['a_usuario', 'modo', 'estado'], name='swipe_recv_idx')),
        migrations.AddIndex(model_name='swipeaction',
            index=models.Index(fields=['de_usuario', 'modo', 'accion'], name='swipe_sent_idx')),
        migrations.AddIndex(model_name='swipeaction',
            index=models.Index(fields=['expira_en', 'estado'], name='swipe_expiry_idx')),

        # ── Match ────────────────────────────────────────────────
        migrations.CreateModel(
            name='Match',
            fields=[
                ('id',                  models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('modo',                models.CharField(max_length=8)),
                ('score',               models.FloatField(default=0.0)),
                ('estado',              models.CharField(default='activo', max_length=10)),
                ('conversacion_id',     models.BigIntegerField(blank=True, null=True)),
                ('created_at',          models.DateTimeField(auto_now_add=True)),
                ('updated_at',          models.DateTimeField(auto_now=True)),
                ('usuario_1',           models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                            related_name='matches_1', to=settings.AUTH_USER_MODEL)),
                ('usuario_2',           models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                            related_name='matches_2', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'matches', 'ordering': ['-created_at'], 'app_label': 'kora_matching'},
        ),
        migrations.AlterUniqueTogether(
            name='match',
            unique_together={('usuario_1', 'usuario_2', 'modo')},
        ),

        # ── Contrapropuesta ──────────────────────────────────────
        migrations.CreateModel(
            name='Contrapropuesta',
            fields=[
                ('id',              models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('modo_propuesto',  models.CharField(default='amistad', max_length=8)),
                ('estado',          models.CharField(default='pendiente', max_length=10)),
                ('expira_en',       models.DateTimeField()),
                ('created_at',      models.DateTimeField(auto_now_add=True)),
                ('updated_at',      models.DateTimeField(auto_now=True)),
                ('like_original',   models.OneToOneField(on_delete=django.db.models.deletion.CASCADE,
                                        related_name='contrapropuesta', to='kora_matching.SwipeAction')),
                ('de_usuario',      models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                        related_name='contrapropuestas_enviadas', to=settings.AUTH_USER_MODEL)),
                ('a_usuario',       models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                        related_name='contrapropuestas_recibidas', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'contrapropuestas', 'app_label': 'kora_matching'},
        ),

        # ── LikeDiario ───────────────────────────────────────────
        migrations.CreateModel(
            name='LikeDiario',
            fields=[
                ('id',              models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('modo',            models.CharField(max_length=8)),
                ('fecha',           models.DateField()),
                ('cantidad',        models.PositiveSmallIntegerField(default=0)),
                ('superlike_usado', models.BooleanField(default=False)),
                ('usuario',         models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                        related_name='likes_diarios', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'likes_diarios', 'app_label': 'kora_matching'},
        ),
        migrations.AlterUniqueTogether(
            name='likediario',
            unique_together={('usuario', 'modo', 'fecha')},
        ),

        # ── Bloqueo ──────────────────────────────────────────────
        migrations.CreateModel(
            name='Bloqueo',
            fields=[
                ('id',         models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('motivo',     models.CharField(default='rechazo', max_length=20)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('bloqueador', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='bloqueos_hechos', to=settings.AUTH_USER_MODEL)),
                ('bloqueado',  models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='bloqueos_recibidos', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'bloqueos', 'app_label': 'kora_matching'},
        ),
        migrations.AlterUniqueTogether(
            name='bloqueo',
            unique_together={('bloqueador', 'bloqueado')},
        ),

        # ── MatchScore ───────────────────────────────────────────
        migrations.CreateModel(
            name='MatchScore',
            fields=[
                ('id',                  models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('score_total',         models.FloatField(default=0.0)),
                ('score_intenciones',   models.FloatField(default=0.0)),
                ('score_intereses',     models.FloatField(default=0.0)),
                ('score_estilo_vida',   models.FloatField(default=0.0)),
                ('score_carrera',       models.FloatField(default=0.0)),
                ('score_horarios',      models.FloatField(default=0.0)),
                ('updated_at',          models.DateTimeField(auto_now=True)),
                ('usuario_1',           models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                            related_name='scores_1', to=settings.AUTH_USER_MODEL)),
                ('usuario_2',           models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                            related_name='scores_2', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'match_scores', 'app_label': 'kora_matching'},
        ),
        migrations.AlterUniqueTogether(
            name='matchscore',
            unique_together={('usuario_1', 'usuario_2')},
        ),

        # ── DuplaDos ─────────────────────────────────────────────
        migrations.CreateModel(
            name='DuplaDos',
            fields=[
                ('id',          models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('estado',      models.CharField(default='pendiente_inv', max_length=16)),
                ('pref_user_1', models.CharField(blank=True, default='', max_length=20)),
                ('pref_user_2', models.CharField(blank=True, default='', max_length=20)),
                ('created_at',  models.DateTimeField(auto_now_add=True)),
                ('updated_at',  models.DateTimeField(auto_now=True)),
                ('user_1',      models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='duplas_creadas', to=settings.AUTH_USER_MODEL)),
                ('user_2',      models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                    related_name='duplas_recibidas', to=settings.AUTH_USER_MODEL)),
            ],
            options={'db_table': 'duplas_dos', 'app_label': 'kora_matching'},
        ),

        # ── Match2pa2 ────────────────────────────────────────────
        migrations.CreateModel(
            name='Match2pa2',
            fields=[
                ('id',                      models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                ('estado',                  models.CharField(default='pendiente_a', max_length=12)),
                ('acepto_a',                models.BooleanField(null=True)),
                ('acepto_b',                models.BooleanField(null=True)),
                ('expira_en',               models.DateTimeField()),
                ('conversacion_grupal_id',  models.BigIntegerField(blank=True, null=True)),
                ('created_at',              models.DateTimeField(auto_now_add=True)),
                ('updated_at',              models.DateTimeField(auto_now=True)),
                ('dupla_a',                 models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                                related_name='matches_como_a', to='kora_matching.DuplaDos')),
                ('dupla_b',                 models.ForeignKey(on_delete=django.db.models.deletion.CASCADE,
                                                related_name='matches_como_b', to='kora_matching.DuplaDos')),
            ],
            options={'db_table': 'matches_2pa2', 'app_label': 'kora_matching'},
        ),
    ]
