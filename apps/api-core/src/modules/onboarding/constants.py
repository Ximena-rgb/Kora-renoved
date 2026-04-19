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


# ── Género expandido ─────────────────────────────────────────────
GENERO_CHOICES = [
    # Hombre
    ('hombre_cis',       'Hombre cisgénero'),
    ('hombre_trans',     'Hombre trans'),
    ('hombre_intersex',  'Hombre intersexual'),
    ('transmasculino',   'Transmasculino'),
    # Mujer
    ('mujer_cis',        'Mujer cisgénero'),
    ('mujer_trans',      'Mujer trans'),
    ('mujer_intersex',   'Mujer intersexual'),
    ('transfemenino',    'Transfemenino'),
    # Más allá del binario
    ('agénero',          'Agénero'),
    ('bigénero',         'Bigénero'),
    ('género_fluido',    'Género fluido'),
    ('genderqueer',      'Genderqueer'),
    ('no_binario',       'No binario'),
    ('pangénero',        'Pangénero'),
    ('dos_espíritus',    'Dos espíritus'),
    ('otro',             'Otro (especificar)'),
    ('prefiero_no_decir','Prefiero no decir'),
]

# Grupos para la UI de Flutter
GENERO_GRUPOS = {
    'Hombre': ['hombre_cis', 'hombre_trans', 'hombre_intersex', 'transmasculino'],
    'Mujer':  ['mujer_cis',  'mujer_trans',  'mujer_intersex',  'transfemenino'],
    'Más allá del binario': [
        'agénero', 'bigénero', 'género_fluido', 'genderqueer',
        'no_binario', 'pangénero', 'dos_espíritus', 'otro',
    ],
}

# Géneros que se consideran "masculino" / "femenino" para matching de imagen
GENERO_BINARIO_MASCULINO = {'hombre_cis', 'hombre_trans', 'hombre_intersex', 'transmasculino'}
GENERO_BINARIO_FEMENINO  = {'mujer_cis',  'mujer_trans',  'mujer_intersex',  'transfemenino'}

def genero_a_categoria(genero: str) -> str:
    """Devuelve 'masculino' | 'femenino' | '' (para géneros no-binarios/otro)."""
    if genero in GENERO_BINARIO_MASCULINO:
        return 'masculino'
    if genero in GENERO_BINARIO_FEMENINO:
        return 'femenino'
    return ''

# ── Intenciones ───────────────────────────────────────────────────
INTENCION_CHOICES = [
    ('pareja',  'Pareja'),
    ('amistad', 'Amistad'),
    ('estudio', 'Grupos de estudio'),
]

# ── Orientación sexual expandida ──────────────────────────────────
ORIENTACION_CHOICES = [
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
]

# ── ¿A quién te interesa ver? ─────────────────────────────────────
INTERESADO_EN_CHOICES = [
    ('hombres',  'Hombres'),
    ('mujeres',  'Mujeres'),
    ('no_binario', 'Más allá del género binario'),
    ('todos',    'Todxs'),
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

# ── Ejercicio ─────────────────────────────────────────────────────
EJERCICIO_CHOICES = [
    ('no',        'No hago ejercicio'),
    ('ocasional', 'Ocasionalmente'),
    ('regular',   'Regularmente'),
    ('deportista','Deportista / atleta'),
]

# ── Mascotas ──────────────────────────────────────────────────────
MASCOTAS_CHOICES = [
    ('si',  'Sí, tengo mascotas'),
    ('no',  'No tengo'),
    ('quiero', 'No tengo pero quiero'),
    ('alergia', 'Soy alérgico/a'),
]

# ── Estilo de comunicación ────────────────────────────────────────
COMUNICACION_CHOICES = [
    ('texto',     'Texto / chat'),
    ('llamada',   'Llamadas / voz'),
    ('presencial','Presencial'),
    ('mixto',     'Mixto'),
]

# ── Lenguaje del amor ─────────────────────────────────────────────
AMOR_CHOICES = [
    ('palabras', 'Palabras de afirmación'),
    ('tiempo',   'Tiempo de calidad'),
    ('actos',    'Actos de servicio'),
    ('regalos',  'Regalos'),
    ('contacto', 'Contacto físico'),
]

# ── Nivel de escolaridad ──────────────────────────────────────────
ESCOLARIDAD_CHOICES = [
    ('pregrado',  'Pregrado (en curso)'),
    ('tecnico',   'Técnico / tecnólogo'),
    ('posgrado',  'Posgrado'),
    ('otro',      'Otro'),
]

# ── Categorías de gustos (14 categorías) ──────────────────────────
GUSTOS_CATEGORIAS = [
    ('aire_libre',   'Aire libre 🏕️'),
    ('bienestar',    'Bienestar 🧘'),
    ('comer_beber',  'Comer & Beber 🍜'),
    ('fans',         'Fans & Fandoms 🎭'),
    ('creatividad',  'Creatividad 🎨'),
    ('deporte',      'Deporte ⚽'),
    ('musica',       'Música 🎵'),
    ('en_casa',      'En casa 🏠'),
    ('redes',        'Redes sociales 📱'),
    ('salir',        'Salir & Fiesta 🎉'),
    ('series',       'Series & Cine 🎬'),
    ('valores',      'Valores & Espiritualidad 🌿'),
    ('videojuegos',  'Videojuegos 🎮'),
    ('tecnologia',   'Tecnología 💻'),
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
