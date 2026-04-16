from django.conf import settings
from django.contrib.postgres.fields import ArrayField
from django.db import models
from django.utils import timezone


class Plan(models.Model):
    class Tipo(models.TextChoices):
        SOCIAL  = 'social',  'Social / Parche'
        ESTUDIO = 'estudio', 'Grupo de Estudio'
        DATE    = 'date',    'Date'

    class Estado(models.TextChoices):
        ACTIVO     = 'activo',     'Activo'
        EN_CURSO   = 'en_curso',   'En curso'
        FINALIZADO = 'finalizado', 'Finalizado'
        CANCELADO  = 'cancelado',  'Cancelado'

    tipo         = models.CharField(max_length=10, choices=Tipo.choices, default=Tipo.SOCIAL)
    creador      = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='planes_creados')
    titulo       = models.CharField(max_length=100)
    descripcion  = models.TextField(max_length=500, blank=True, default='')
    ubicacion    = models.CharField(max_length=120)
    campus_zona  = models.CharField(max_length=80, blank=True, default='')
    foto_url     = models.URLField(blank=True, default='')
    hora_inicio  = models.DateTimeField()
    duracion_min = models.PositiveSmallIntegerField(default=60)
    max_personas = models.PositiveSmallIntegerField(default=10)
    estado       = models.CharField(max_length=12, choices=Estado.choices, default=Estado.ACTIVO)
    tags         = ArrayField(models.CharField(max_length=60), default=list, blank=True)
    es_publico   = models.BooleanField(default=True)
    match_origen = models.ForeignKey(
        'kora_matching.Match', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='planes',
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        app_label = 'kora_plans'
        db_table  = 'plans'
        ordering  = ['hora_inicio']
        indexes   = [
            models.Index(fields=['tipo', 'estado', 'hora_inicio']),
            models.Index(fields=['campus_zona']),
        ]

    def __str__(self):
        return f'[{self.get_tipo_display()}] {self.titulo}'

    @property
    def participantes_activos(self):
        return self.participantes.filter(estado__in=['confirmado', 'asistio'])

    @property
    def participantes_count(self):
        return self.participantes_activos.count()

    @property
    def esta_lleno(self):
        return self.participantes_count >= self.max_personas

    @property
    def hora_fin(self):
        from datetime import timedelta
        return self.hora_inicio + timedelta(minutes=self.duracion_min)

    @property
    def puede_checkin(self):
        from datetime import timedelta
        ahora = timezone.now()
        return (self.hora_inicio - timedelta(minutes=15)) <= ahora <= (self.hora_inicio + timedelta(minutes=30))

    def puede_unirse(self, user) -> tuple:
        if self.estado not in ('activo',):
            return False, 'Este plan ya no acepta asistentes.'
        if self.esta_lleno:
            return False, 'El plan esta lleno.'
        if self.participantes.filter(usuario=user).exclude(estado='cancelado').exists():
            return False, 'Ya confirmaste asistencia a este plan.'
        if self.tipo == 'date' and self.match_origen:
            ids = {self.match_origen.usuario_1_id, self.match_origen.usuario_2_id}
            if user.id not in ids:
                return False, 'Este date es privado.'
        return True, ''


class Participante(models.Model):
    class Estado(models.TextChoices):
        CONFIRMADO = 'confirmado', 'Confirmo asistencia'
        ASISTIO    = 'asistio',    'Asistio (check-in)'
        NO_ASISTIO = 'no_asistio', 'No asistio'
        CANCELADO  = 'cancelado',  'Cancelo'

    plan             = models.ForeignKey(Plan, on_delete=models.CASCADE, related_name='participantes')
    usuario          = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='planes_asistiendo')
    estado           = models.CharField(max_length=12, choices=Estado.choices, default=Estado.CONFIRMADO)
    hora_checkin     = models.DateTimeField(null=True, blank=True)
    delta_puntualidad = models.SmallIntegerField(null=True, blank=True)
    joined_at        = models.DateTimeField(auto_now_add=True)
    updated_at       = models.DateTimeField(auto_now=True)

    class Meta:
        app_label       = 'kora_plans'
        db_table        = 'plan_participantes'
        unique_together = [['plan', 'usuario']]
        indexes         = [models.Index(fields=['usuario', 'estado'])]

    def __str__(self):
        return f'{self.usuario_id} en {self.plan.titulo} [{self.estado}]'

    @property
    def fue_puntual(self):
        if self.delta_puntualidad is None:
            return None
        return abs(self.delta_puntualidad) <= 15
