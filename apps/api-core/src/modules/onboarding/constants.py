"""
modules/onboarding/constants.py
================================
Choices y constantes del módulo de onboarding.
Centralizados aquí para reutilizar en models, serializers y tests.
"""

# ── Pasos del onboarding (orden secuencial) ───────────────────────
class PasoOnboarding:
    TERMINOS          = 'terminos'
    BASICO            = 'basico'
    INTENCIONES       = 'intenciones'
    PREFERENCIAS      = 'preferencias'
    PERSONAL          = 'personal'
    INSTITUCIONAL     = 'institucional'
    FOTOS             = 'fotos'
    COMPLETO          = 'completo'

    ORDEN = [
        TERMINOS, BASICO, INTENCIONES, PREFERENCIAS,
        PERSONAL, INSTITUCIONAL, FOTOS, COMPLETO,
    ]

    @classmethod
    def siguiente(cls, paso_actual: str) -> str | None:
        try:
            idx = cls.ORDEN.index(paso_actual)
            return cls.ORDEN[idx + 1] if idx + 1 < len(cls.ORDEN) else None
        except ValueError:
            return None


# ── Género ────────────────────────────────────────────────────────
GENERO_CHOICES = [
    ('masculino',  'Masculino'),
    ('femenino',   'Femenino'),
    ('no_binario', 'No binario'),
    ('otro',       'Otro'),
    ('prefiero_no_decir', 'Prefiero no decir'),
]

# ── Intenciones ───────────────────────────────────────────────────
INTENCION_CHOICES = [
    ('pareja',  'Pareja'),
    ('amistad', 'Amistad'),
    ('estudio', 'Grupos de estudio'),
]

# ── Orientación sexual ────────────────────────────────────────────
ORIENTACION_CHOICES = [
    ('heterosexual',    'Heterosexual'),
    ('gay',             'Gay'),
    ('lesbiana',        'Lesbiana'),
    ('bisexual',        'Bisexual'),
    ('pansexual',       'Pansexual'),
    ('asexual',         'Asexual'),
    ('prefiero_no_decir', 'Prefiero no decir'),
]

# ── Interesado en conocer ─────────────────────────────────────────
INTERESADO_EN_CHOICES = [
    ('hombres', 'Hombres'),
    ('mujeres', 'Mujeres'),
    ('otros',   'Otros géneros'),
    ('todos',   'Todos'),
]

# ── Hábitos ───────────────────────────────────────────────────────
HABITO_CHOICES = [
    ('no',         'No'),
    ('ocasional',  'Ocasionalmente'),
    ('si',         'Sí'),
]

FIESTA_CHOICES = [
    ('no',       'No'),
    ('a_veces',  'A veces'),
    ('si',       'Sí, soy fiestero/a'),
]

# ── Hijos ─────────────────────────────────────────────────────────
HIJOS_CHOICES = [
    ('no_tengo_no_quiero', 'No tengo y no quiero'),
    ('no_tengo_quiero',    'No tengo pero quiero'),
    ('tengo',              'Tengo hijos'),
    ('prefiero_no_decir',  'Prefiero no decir'),
]

# ── Actividad física ──────────────────────────────────────────────
ACTIVIDAD_CHOICES = [
    ('sedentario', 'Sedentario'),
    ('moderado',   'Moderado'),
    ('activo',     'Activo'),
    ('muy_activo', 'Muy activo'),
]

# ── Qué siente por su carrera ─────────────────────────────────────
GUSTA_CARRERA_CHOICES = [
    ('la_amo',     'La amo, es mi pasión'),
    ('esta_ok',    'Está bien, me gusta'),
    ('no_mucho',   'No mucho, pero aquí voy'),
    ('la_odio',    'La odio, error mío'),
]

# ── Trabajo preferido ─────────────────────────────────────────────
TRABAJO_PREF_CHOICES = [
    ('grupo',       'Prefiero trabajo en grupo'),
    ('individual',  'Prefiero trabajo individual'),
    ('ambos',       'Me adapto a los dos'),
]

# ── Estado de la foto ─────────────────────────────────────────────
FOTO_ESTADO_CHOICES = [
    ('pending',  'Pendiente de revisión'),
    ('approved', 'Aprobada'),
    ('rejected', 'Rechazada (contenido inapropiado)'),
]

# ── Signos zodiacales ─────────────────────────────────────────────
SIGNO_CHOICES = [
    ('aries',       'Aries'),
    ('tauro',       'Tauro'),
    ('geminis',     'Géminis'),
    ('cancer',      'Cáncer'),
    ('leo',         'Leo'),
    ('virgo',       'Virgo'),
    ('libra',       'Libra'),
    ('escorpio',    'Escorpio'),
    ('sagitario',   'Sagitario'),
    ('capricornio', 'Capricornio'),
    ('acuario',     'Acuario'),
    ('piscis',      'Piscis'),
    ('',            'Prefiero no decir'),
]

# ── Límites ───────────────────────────────────────────────────────
EDAD_MINIMA      = 18
MAX_FOTOS        = 5
MIN_FOTOS        = 2
MAX_GUSTOS       = 15
MAX_HABILIDADES  = 10
MAX_DEBILIDADES  = 5
MAX_IDIOMAS      = 8
