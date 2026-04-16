from django.conf import settings
from django.core.validators import MinValueValidator, MaxValueValidator
from django.db import models


class ScoreConfianza(models.Model):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='score_confianza', primary_key=True,
    )
    score_total            = models.FloatField(default=0.0)
    score_calificacion     = models.FloatField(default=0.0)
    score_puntualidad      = models.FloatField(default=0.0)
    score_asistencia       = models.FloatField(default=0.0)
    planes_confirmados     = models.PositiveIntegerField(default=0)
    planes_asistidos       = models.PositiveIntegerField(default=0)
    checkins_puntuales     = models.PositiveIntegerField(default=0)
    checkins_total         = models.PositiveIntegerField(default=0)
    calificaciones_recibidas = models.PositiveIntegerField(default=0)
    suma_calificaciones    = models.FloatField(default=0.0)
    updated_at             = models.DateTimeField(auto_now=True)

    class Meta:
        app_label = 'kora_reputation'
        db_table  = 'scores_confianza'

    def __str__(self):
        return f'Score {self.user_id}: {self.score_total:.1f}/100'

    def recalcular(self):
        if self.calificaciones_recibidas > 0:
            prom = self.suma_calificaciones / self.calificaciones_recibidas
            self.score_calificacion = (prom / 5.0) * 100
        else:
            self.score_calificacion = 50.0

        if self.checkins_total > 0:
            self.score_puntualidad = (self.checkins_puntuales / self.checkins_total) * 100
        else:
            self.score_puntualidad = 50.0

        if self.planes_confirmados > 0:
            self.score_asistencia = (self.planes_asistidos / self.planes_confirmados) * 100
        else:
            self.score_asistencia = 50.0

        self.score_total = (
            self.score_calificacion * 0.40 +
            self.score_puntualidad  * 0.30 +
            self.score_asistencia   * 0.30
        )
        self.save(update_fields=[
            'score_total', 'score_calificacion',
            'score_puntualidad', 'score_asistencia',
        ])
        return self.score_total


class Calificacion(models.Model):
    de_usuario = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='calificaciones_dadas')
    a_usuario  = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='calificaciones_recibidas')
    plan       = models.ForeignKey(
        'kora_plans.Plan', on_delete=models.CASCADE,
        related_name='calificaciones')
    nota       = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)])
    comentario = models.TextField(max_length=200, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label       = 'kora_reputation'
        db_table        = 'calificaciones'
        unique_together = [['de_usuario', 'a_usuario', 'plan']]
        indexes         = [models.Index(fields=['a_usuario', 'created_at'])]

    def __str__(self):
        return f'{self.de_usuario_id} -> {self.a_usuario_id}: {self.nota}*'

    def save(self, *args, **kwargs):
        is_new = self.pk is None
        super().save(*args, **kwargs)
        if is_new:
            _actualizar_score_calificacion(self.a_usuario, self.nota)


class EventoReputacion(models.Model):
    class TipoEvento(models.TextChoices):
        CHECKIN_PUNTUAL   = 'checkin_puntual',   'Check-in puntual'
        CHECKIN_TARDE     = 'checkin_tarde',      'Check-in tardio'
        NO_ASISTIO        = 'no_asistio',         'No asistio'
        CALIFICACION_ALTA = 'calificacion_alta',  'Calificacion alta'
        CALIFICACION_BAJA = 'calificacion_baja',  'Calificacion baja'
        PLAN_ORGANIZADO   = 'plan_organizado',    'Organizo plan'
        CALIFICO_OTROS    = 'califico_otros',     'Califico a otros'

    usuario     = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='eventos_reputacion')
    tipo        = models.CharField(max_length=20, choices=TipoEvento.choices)
    descripcion = models.CharField(max_length=200)
    delta       = models.FloatField(default=0.0)
    plan        = models.ForeignKey(
        'kora_plans.Plan', on_delete=models.SET_NULL,
        null=True, blank=True, related_name='eventos_reputacion')
    created_at  = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label = 'kora_reputation'
        db_table  = 'eventos_reputacion'
        ordering  = ['-created_at']

    def __str__(self):
        return f'{self.usuario_id} | {self.tipo} | {self.delta:+.1f}'


class Insignia(models.Model):
    CATALOGO = {
        'puntual_estrella':     {'nombre': 'Siempre puntual',      'desc': 'Check-in puntual en 10 planes'},
        'organizador_estrella': {'nombre': 'Organizador estrella', 'desc': 'Organizo 5 planes exitosos'},
        'social_butterfly':     {'nombre': 'Social butterfly',     'desc': 'Asistio a 20 planes sociales'},
        'mentor_estudio':       {'nombre': 'Mentor de estudio',    'desc': 'Asistio a 10 grupos de estudio'},
        'cinco_estrellas':      {'nombre': 'Cinco estrellas',      'desc': 'Calificacion promedio 4.8+'},
        'confiable':            {'nombre': 'Super confiable',      'desc': 'Score de confianza > 90'},
    }

    usuario     = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='insignias')
    codigo      = models.CharField(max_length=30)
    obtenida_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label       = 'kora_reputation'
        db_table        = 'insignias'
        unique_together = [['usuario', 'codigo']]

    def __str__(self):
        return f'{self.usuario_id} -> {self.codigo}'

    @property
    def info(self):
        return self.CATALOGO.get(self.codigo, {'nombre': self.codigo, 'desc': ''})


def _actualizar_score_calificacion(usuario, nota: float):
    score, _ = ScoreConfianza.objects.get_or_create(user=usuario)
    score.calificaciones_recibidas += 1
    score.suma_calificaciones      += nota
    score.save(update_fields=['calificaciones_recibidas', 'suma_calificaciones'])
    score.recalcular()
    usuario.actualizar_reputacion(nota)


def registrar_checkin(participante):
    from django.utils import timezone
    ahora = timezone.now()
    delta = int((ahora - participante.plan.hora_inicio).total_seconds() / 60)
    participante.hora_checkin      = ahora
    participante.delta_puntualidad = delta
    participante.estado            = 'asistio'
    participante.save(update_fields=['hora_checkin', 'delta_puntualidad', 'estado'])

    usuario = participante.usuario
    score, _ = ScoreConfianza.objects.get_or_create(user=usuario)
    score.checkins_total   += 1
    score.planes_asistidos += 1
    if abs(delta) <= 15:
        score.checkins_puntuales += 1
    score.save(update_fields=['checkins_total', 'planes_asistidos', 'checkins_puntuales'])
    score.recalcular()

    es_puntual = abs(delta) <= 15
    tipo       = EventoReputacion.TipoEvento.CHECKIN_PUNTUAL if es_puntual else EventoReputacion.TipoEvento.CHECKIN_TARDE
    EventoReputacion.objects.create(
        usuario     = usuario,
        tipo        = tipo,
        descripcion = f'Check-in en "{participante.plan.titulo}"' + (' (puntual)' if es_puntual else f' ({delta} min tarde)'),
        delta       = 3.0 if es_puntual else 0.0,
        plan        = participante.plan,
    )
    _verificar_insignias(usuario, score)


def registrar_no_asistencia(participante):
    usuario = participante.usuario
    participante.estado = 'no_asistio'
    participante.save(update_fields=['estado'])
    score, _ = ScoreConfianza.objects.get_or_create(user=usuario)
    score.planes_confirmados += 1
    score.save(update_fields=['planes_confirmados'])
    score.recalcular()
    EventoReputacion.objects.create(
        usuario     = usuario,
        tipo        = EventoReputacion.TipoEvento.NO_ASISTIO,
        descripcion = f'No asistio a "{participante.plan.titulo}"',
        delta       = -5.0,
        plan        = participante.plan,
    )


def _verificar_insignias(usuario, score: ScoreConfianza):
    otorgadas = set(Insignia.objects.filter(usuario=usuario).values_list('codigo', flat=True))

    def otorgar(codigo):
        if codigo not in otorgadas:
            Insignia.objects.create(usuario=usuario, codigo=codigo)

    if score.checkins_puntuales >= 10:
        otorgar('puntual_estrella')
    if score.score_total >= 90:
        otorgar('confiable')
    if score.calificaciones_recibidas >= 5:
        prom = score.suma_calificaciones / score.calificaciones_recibidas
        if prom >= 4.8:
            otorgar('cinco_estrellas')
