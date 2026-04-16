"""
modules/matching/models.py
===========================
Modelos del motor de matching Kora.

SwipeAction     → registro de cada like/pass/superlike con TTL
Match           → match confirmado con intención acordada
Contrapropuesta → propuesta de cambio pareja→amistad
LikeDiario      → contador de likes por usuario/modo/día
Bloqueo         → perfiles ocultos entre sí
DuplaDos        → dupla para modo 2pa2
Match2pa2       → match entre dos duplas
"""

from django.conf import settings
from django.db import models
from django.utils import timezone

from .constants import (
    Modo, Accion, EstadoLike, EstadoMatch,
    EstadoContrapropuesta, EstadoDupla,
)


# ── SwipeAction ───────────────────────────────────────────────────
class SwipeAction(models.Model):
    """
    Registro de cada swipe.
    - Un usuario solo puede swipear a otro una vez por modo.
    - Los likes expiran en 24h si no hay respuesta.
    - Los pass son permanentes.
    """
    de_usuario  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='swipes_dados')
    a_usuario   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='swipes_recibidos')
    modo        = models.CharField(max_length=8, choices=Modo.CHOICES)
    accion      = models.CharField(max_length=10, choices=Accion.CHOICES)
    estado      = models.CharField(max_length=16, choices=EstadoLike.CHOICES,
                    default=EstadoLike.PENDIENTE)
    es_superlike = models.BooleanField(default=False)
    expira_en   = models.DateTimeField(null=True, blank=True,
                    help_text='Solo aplica para likes — 24h desde creación')
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        app_label       = 'kora_matching'
        db_table        = 'swipe_actions'
        # Un usuario solo puede swipear una vez a otro por modo
        unique_together = [['de_usuario', 'a_usuario', 'modo']]
        indexes         = [
            models.Index(fields=['a_usuario', 'modo', 'estado']),
            models.Index(fields=['de_usuario', 'modo', 'accion']),
            models.Index(fields=['expira_en', 'estado']),
        ]

    def __str__(self):
        return f'{self.de_usuario_id} →{self.accion}→ {self.a_usuario_id} [{self.modo}]'

    @property
    def esta_expirado(self) -> bool:
        if self.accion != Accion.LIKE:
            return False
        if not self.expira_en:
            return False
        return timezone.now() > self.expira_en

    def save(self, *args, **kwargs):
        # Setear TTL automáticamente en likes nuevos
        if not self.pk and self.accion in (Accion.LIKE, Accion.SUPERLIKE):
            from datetime import timedelta
            from .constants import LIKE_TTL_SEGUNDOS
            self.expira_en = timezone.now() + timedelta(seconds=LIKE_TTL_SEGUNDOS)
        super().save(*args, **kwargs)


# ── Match ─────────────────────────────────────────────────────────
class Match(models.Model):
    """
    Match confirmado. Se crea cuando:
    1. Hay like mutuo, O
    2. Se acepta una contrapropuesta
    """
    usuario_1   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='matches_1')
    usuario_2   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='matches_2')
    modo        = models.CharField(max_length=8, choices=Modo.CHOICES)
    score       = models.FloatField(default=0.0)
    estado      = models.CharField(max_length=10, choices=EstadoMatch.CHOICES,
                    default=EstadoMatch.ACTIVO)
    # FK a la conversación creada automáticamente
    conversacion_id = models.BigIntegerField(null=True, blank=True)
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        app_label       = 'kora_matching'
        db_table        = 'matches'
        unique_together = [['usuario_1', 'usuario_2', 'modo']]
        ordering        = ['-created_at']
        indexes         = [
            models.Index(fields=['usuario_1', 'modo', 'estado']),
            models.Index(fields=['usuario_2', 'modo', 'estado']),
        ]

    def __str__(self):
        return f'Match [{self.modo}] {self.usuario_1_id} ↔ {self.usuario_2_id}'

    @staticmethod
    def normalizar_usuarios(user_a, user_b):
        """Siempre guarda con el id menor primero para evitar duplicados."""
        return (user_a, user_b) if user_a.id < user_b.id else (user_b, user_a)

    def get_otro_usuario(self, user):
        return self.usuario_2 if self.usuario_1_id == user.id else self.usuario_1


# ── Contrapropuesta ───────────────────────────────────────────────
class Contrapropuesta(models.Model):
    """
    Solo disponible cuando la intención original era PAREJA.
    El receptor propone cambiar a AMISTAD.
    """
    like_original   = models.OneToOneField(SwipeAction, on_delete=models.CASCADE,
                        related_name='contrapropuesta')
    de_usuario      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                        related_name='contrapropuestas_enviadas',
                        help_text='Quien recibió el like y propone cambiar')
    a_usuario       = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                        related_name='contrapropuestas_recibidas',
                        help_text='Quien dio el like original')
    modo_propuesto  = models.CharField(max_length=8, default=Modo.AMISTAD,
                        help_text='Siempre AMISTAD — contrapropuesta solo pareja→amistad')
    estado          = models.CharField(max_length=10, choices=EstadoContrapropuesta.CHOICES,
                        default=EstadoContrapropuesta.PENDIENTE)
    expira_en       = models.DateTimeField(help_text='48h para responder la contrapropuesta')
    created_at      = models.DateTimeField(auto_now_add=True)
    updated_at      = models.DateTimeField(auto_now=True)

    class Meta:
        app_label = 'kora_matching'
        db_table  = 'contrapropuestas'
        indexes   = [
            models.Index(fields=['a_usuario', 'estado']),
            models.Index(fields=['expira_en', 'estado']),
        ]

    def save(self, *args, **kwargs):
        if not self.pk:
            from datetime import timedelta
            self.expira_en = timezone.now() + timedelta(hours=48)
        super().save(*args, **kwargs)

    def __str__(self):
        return f'Contrapropuesta {self.de_usuario_id}→{self.a_usuario_id} [{self.estado}]'


# ── LikeDiario ────────────────────────────────────────────────────
class LikeDiario(models.Model):
    """
    Contador de likes por usuario/modo/día.
    Reset automático a medianoche (gestionado por el engine).
    """
    usuario    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='likes_diarios')
    modo       = models.CharField(max_length=8, choices=Modo.CHOICES)
    fecha      = models.DateField(help_text='Fecha del conteo (UTC-5 Bogotá)')
    cantidad   = models.PositiveSmallIntegerField(default=0)
    superlike_usado = models.BooleanField(default=False)

    class Meta:
        app_label       = 'kora_matching'
        db_table        = 'likes_diarios'
        unique_together = [['usuario', 'modo', 'fecha']]

    def __str__(self):
        return f'{self.usuario_id} | {self.modo} | {self.fecha} → {self.cantidad}'


# ── Bloqueo ───────────────────────────────────────────────────────
class Bloqueo(models.Model):
    """
    Perfiles ocultos entre sí.
    Se crea al rechazar un like o al bloquear manualmente.
    Es bidireccional: ninguno ve al otro.
    """
    bloqueador  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='bloqueos_hechos')
    bloqueado   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='bloqueos_recibidos')
    motivo      = models.CharField(max_length=20, default='rechazo',
                    choices=[
                        ('rechazo',  'Rechazo de like'),
                        ('manual',   'Bloqueo manual'),
                        ('reporte',  'Reporte'),
                    ])
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label       = 'kora_matching'
        db_table        = 'bloqueos'
        unique_together = [['bloqueador', 'bloqueado']]
        indexes         = [models.Index(fields=['bloqueado'])]

    def __str__(self):
        return f'Bloqueo {self.bloqueador_id} → {self.bloqueado_id}'


# ── MatchScore (cache de scores pre-calculados) ───────────────────
class MatchScore(models.Model):
    usuario_1           = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                            related_name='scores_1')
    usuario_2           = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                            related_name='scores_2')
    score_total         = models.FloatField(default=0.0)
    score_intenciones   = models.FloatField(default=0.0)
    score_intereses     = models.FloatField(default=0.0)
    score_estilo_vida   = models.FloatField(default=0.0)
    score_carrera       = models.FloatField(default=0.0)
    score_horarios      = models.FloatField(default=0.0)
    updated_at          = models.DateTimeField(auto_now=True)

    class Meta:
        app_label       = 'kora_matching'
        db_table        = 'match_scores'
        unique_together = [['usuario_1', 'usuario_2']]


# ── DuplaDos (modo 2pa2) ──────────────────────────────────────────
class DuplaDos(models.Model):
    """
    Dupla de dos amigos para el modo 2pa2.
    user_1 invita a user_2.
    """
    user_1      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='duplas_creadas')
    user_2      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='duplas_recibidas')
    estado      = models.CharField(max_length=16, choices=EstadoDupla.CHOICES,
                    default=EstadoDupla.PENDIENTE_INVITACION)
    # Preferencia de género dentro de la dupla
    pref_user_1 = models.CharField(max_length=20, blank=True, default='',
                    help_text='Qué género busca user_1 en el 2pa2')
    pref_user_2 = models.CharField(max_length=20, blank=True, default='',
                    help_text='Qué género busca user_2 en el 2pa2')
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        app_label = 'kora_matching'
        db_table  = 'duplas_dos'
        indexes   = [
            models.Index(fields=['user_2', 'estado']),
            models.Index(fields=['estado']),
        ]

    def __str__(self):
        return f'Dupla {self.user_1_id}+{self.user_2_id} [{self.estado}]'

    def get_otro(self, user):
        return self.user_2 if self.user_1_id == user.id else self.user_1


# ── Match2pa2 ─────────────────────────────────────────────────────
class Match2pa2(models.Model):
    """
    Match entre dos duplas.
    Estados: pendiente (esperando que ambas acepten) → activo → rechazado
    """
    class Estado(models.TextChoices):
        PENDIENTE_A  = 'pendiente_a', 'Esperando respuesta de dupla A'
        PENDIENTE_B  = 'pendiente_b', 'Esperando respuesta de dupla B'
        ACTIVO       = 'activo',      'Ambas duplas aceptaron'
        RECHAZADO    = 'rechazado',   'Una dupla rechazó'
        EXPIRADO     = 'expirado',    'Sin respuesta en 24h'

    dupla_a     = models.ForeignKey(DuplaDos, on_delete=models.CASCADE,
                    related_name='matches_como_a')
    dupla_b     = models.ForeignKey(DuplaDos, on_delete=models.CASCADE,
                    related_name='matches_como_b')
    estado      = models.CharField(max_length=12, choices=Estado.choices,
                    default=Estado.PENDIENTE_A)
    acepto_a    = models.BooleanField(null=True)
    acepto_b    = models.BooleanField(null=True)
    expira_en   = models.DateTimeField()
    conversacion_grupal_id = models.BigIntegerField(null=True, blank=True)
    created_at  = models.DateTimeField(auto_now_add=True)
    updated_at  = models.DateTimeField(auto_now=True)

    class Meta:
        app_label = 'kora_matching'
        db_table  = 'matches_2pa2'

    def save(self, *args, **kwargs):
        if not self.pk:
            from datetime import timedelta
            self.expira_en = timezone.now() + timedelta(hours=24)
        super().save(*args, **kwargs)

    def __str__(self):
        return f'2pa2: Dupla{self.dupla_a_id} ↔ Dupla{self.dupla_b_id} [{self.estado}]'
