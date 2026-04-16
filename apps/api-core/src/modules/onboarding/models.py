"""
modules/onboarding/models.py
=============================
UserProfile  → extensión 1:1 de User con toda la info del onboarding
UserPhoto    → fotos del perfil (min 2, max 5)
"""

from django.conf import settings
from django.contrib.postgres.fields import ArrayField
from django.db import models
from django.utils import timezone

from .constants import (
    GENERO_CHOICES, ORIENTACION_CHOICES, INTERESADO_EN_CHOICES,
    HABITO_CHOICES, FIESTA_CHOICES, HIJOS_CHOICES, ACTIVIDAD_CHOICES,
    GUSTA_CARRERA_CHOICES, TRABAJO_PREF_CHOICES, FOTO_ESTADO_CHOICES,
    SIGNO_CHOICES, PasoOnboarding,
)


class UserProfile(models.Model):
    """
    Perfil extendido del usuario — separado del modelo User base
    para mantener la autenticación limpia.
    Relación 1:1 con User, se crea al aceptar T&C.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='profile',
        primary_key=True,
    )

    # ── Paso actual del onboarding ────────────────────────────────
    onboarding_paso = models.CharField(
        max_length=20,
        default=PasoOnboarding.TERMINOS,
        choices=[(p, p) for p in PasoOnboarding.ORDEN],
    )

    # ══ PASO 1: Términos y condiciones ════════════════════════════
    terminos_aceptados = models.BooleanField(default=False)
    terminos_fecha     = models.DateTimeField(null=True, blank=True)

    # ══ PASO 2: Info básica ═══════════════════════════════════════
    apellido          = models.CharField(max_length=120, blank=True, default='')
    fecha_nacimiento  = models.DateField(null=True, blank=True)
    genero            = models.CharField(
        max_length=20, blank=True, default='', choices=GENERO_CHOICES
    )
    genero_personalizado = models.CharField(
        max_length=60, blank=True, default='',
        help_text='Solo si genero="otro"'
    )

    # ══ PASO 3: Intenciones ═══════════════════════════════════════
    # ['pareja', 'amistad', 'estudio'] — puede tener los 3
    intenciones = ArrayField(
        models.CharField(max_length=20),
        default=list, blank=True,
        help_text='pareja | amistad | estudio'
    )

    # ══ PASO 4: Preferencias de pareja/amistad ════════════════════
    orientacion_sexual = models.CharField(
        max_length=20, blank=True, default='', choices=ORIENTACION_CHOICES
    )
    # Para pareja Y amistad — qué género le interesa conocer
    interesado_en_pareja  = ArrayField(
        models.CharField(max_length=20), default=list, blank=True
    )
    interesado_en_amistad = ArrayField(
        models.CharField(max_length=20), default=list, blank=True
    )

    # ══ PASO 5: Preferencias personales ══════════════════════════
    bio_larga    = models.TextField(blank=True, default='')
    bio_corta    = models.CharField(
        max_length=100, blank=True, default='',
        help_text='Máximo 100 caracteres — se muestra en la tarjeta'
    )
    gustos       = ArrayField(
        models.CharField(max_length=60), default=list, blank=True,
        help_text='Máximo 15 gustos/hobbies'
    )
    tiempo_libre = models.TextField(
        max_length=300, blank=True, default='',
        help_text='Qué hace en su tiempo libre'
    )
    fuma         = models.CharField(max_length=12, blank=True, default='', choices=HABITO_CHOICES)
    bebe         = models.CharField(max_length=12, blank=True, default='', choices=HABITO_CHOICES)
    sale_fiesta  = models.CharField(max_length=12, blank=True, default='', choices=FIESTA_CHOICES)

    # Animales
    animales_gustan = models.BooleanField(null=True, blank=True)
    tiene_animales  = models.BooleanField(null=True, blank=True)
    cuales_animales = models.CharField(max_length=200, blank=True, default='')

    # Más personal
    idiomas          = ArrayField(
        models.CharField(max_length=60), default=list, blank=True
    )
    hijos            = models.CharField(
        max_length=24, blank=True, default='', choices=HIJOS_CHOICES
    )
    signo_zodiacal   = models.CharField(
        max_length=12, blank=True, default='', choices=SIGNO_CHOICES
    )
    nivel_actividad  = models.CharField(
        max_length=12, blank=True, default='', choices=ACTIVIDAD_CHOICES
    )

    # ══ PASO 6: Perfil institucional ══════════════════════════════
    facultad          = models.CharField(max_length=120, blank=True, default='')
    carrera           = models.CharField(max_length=120, blank=True, default='')
    semestre          = models.PositiveSmallIntegerField(null=True, blank=True)
    gusta_carrera     = models.CharField(
        max_length=12, blank=True, default='', choices=GUSTA_CARRERA_CHOICES
    )
    proyeccion        = models.TextField(
        max_length=300, blank=True, default='',
        help_text='Qué quiere hacer al graduarse'
    )
    habilidades       = ArrayField(
        models.CharField(max_length=60), default=list, blank=True
    )
    debilidades       = ArrayField(
        models.CharField(max_length=60), default=list, blank=True
    )
    busca_tesis       = models.BooleanField(null=True, blank=True)
    trabajo_preferencia = models.CharField(
        max_length=12, blank=True, default='', choices=TRABAJO_PREF_CHOICES
    )
    # Horarios de disponibilidad para matching de estudio
    disponibilidad    = models.JSONField(
        default=list, blank=True,
        help_text='[{"dia":"lunes","inicio":"08:00","fin":"10:00"}]'
    )

    # ── Timestamps ───────────────────────────────────────────────
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        app_label = 'kora_onboarding'
        db_table  = 'user_profiles'

    def __str__(self):
        return f'Perfil de {self.user.email} [{self.onboarding_paso}]'

    # ── Helpers ───────────────────────────────────────────────────
    @property
    def edad(self) -> int | None:
        if not self.fecha_nacimiento:
            return None
        hoy   = timezone.now().date()
        years = hoy.year - self.fecha_nacimiento.year
        # Ajustar si aún no ha cumplido este año
        if (hoy.month, hoy.day) < (self.fecha_nacimiento.month, self.fecha_nacimiento.day):
            years -= 1
        return years

    @property
    def es_mayor_de_edad(self) -> bool:
        edad = self.edad
        return edad is not None and edad >= 18

    @property
    def fotos_aprobadas(self):
        return self.user.fotos.filter(estado='approved').order_by('orden')

    @property
    def onboarding_completo(self) -> bool:
        return self.onboarding_paso == PasoOnboarding.COMPLETO

    def avanzar_paso(self):
        siguiente = PasoOnboarding.siguiente(self.onboarding_paso)
        if siguiente:
            self.onboarding_paso = siguiente
            self.save(update_fields=['onboarding_paso'])
        return self.onboarding_paso


class UserPhoto(models.Model):
    """
    Fotos del perfil del usuario.
    Mínimo 2 aprobadas para completar el onboarding.
    Máximo 5 en total.
    """
    user      = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='fotos',
    )
    # URLs generadas por api-media worker
    url_original = models.URLField(blank=True, default='')
    url_medium   = models.URLField(blank=True, default='')
    url_thumb    = models.URLField(blank=True, default='')

    # Path temporal mientras api-media procesa
    tmp_path    = models.CharField(max_length=500, blank=True, default='')

    es_principal = models.BooleanField(default=False)
    orden        = models.PositiveSmallIntegerField(default=0)
    estado       = models.CharField(
        max_length=10, choices=FOTO_ESTADO_CHOICES, default='pending'
    )
    rechazo_motivo = models.CharField(max_length=200, blank=True, default='')

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        app_label = 'kora_onboarding'
        db_table  = 'user_photos'
        ordering  = ['orden', 'created_at']

    def __str__(self):
        return f'Foto {self.orden} de {self.user.email} [{self.estado}]'
