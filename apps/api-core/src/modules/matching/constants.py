class Modo:
    PAREJA     = 'pareja'
    AMISTAD    = 'amistad'
    ESTUDIO    = 'estudio'
    DOS_PA_DOS = '2pa2'

    CHOICES = [
        ('pareja',  'Pareja'),
        ('amistad', 'Amistad'),
        ('estudio', 'Estudio'),
        ('2pa2',    '2pa2'),
    ]
    TODOS = ['pareja', 'amistad', 'estudio', '2pa2']


class Accion:
    LIKE      = 'like'
    PASS      = 'pass'
    SUPERLIKE = 'superlike'

    CHOICES = [
        ('like',      'Like'),
        ('pass',      'Pass'),
        ('superlike', 'Super Like'),
    ]


class EstadoLike:
    PENDIENTE      = 'pendiente'
    ACEPTADO       = 'aceptado'
    RECHAZADO      = 'rechazado'
    EXPIRADO       = 'expirado'
    CONTRAPROPUESTA = 'contrapropuesta'

    CHOICES = [
        ('pendiente',      'Pendiente'),
        ('aceptado',       'Aceptado'),
        ('rechazado',      'Rechazado'),
        ('expirado',       'Expirado'),
        ('contrapropuesta','Contrapropuesta enviada'),
    ]


class EstadoMatch:
    ACTIVO    = 'activo'
    ARCHIVADO = 'archivado'
    BLOQUEADO = 'bloqueado'

    CHOICES = [
        ('activo',    'Activo'),
        ('archivado', 'Archivado'),
        ('bloqueado', 'Bloqueado'),
    ]


class EstadoContrapropuesta:
    PENDIENTE = 'pendiente'
    ACEPTADA  = 'aceptada'
    RECHAZADA = 'rechazada'
    EXPIRADA  = 'expirada'

    CHOICES = [
        ('pendiente', 'Pendiente'),
        ('aceptada',  'Aceptada'),
        ('rechazada', 'Rechazada'),
        ('expirada',  'Expirada'),
    ]


class EstadoDupla:
    PENDIENTE_INVITACION = 'pendiente_inv'
    ACTIVA               = 'activa'
    BUSCANDO             = 'buscando'
    EN_MATCH             = 'en_match'
    CERRADA              = 'cerrada'

    CHOICES = [
        ('pendiente_inv', 'Pendiente de aceptar invitación'),
        ('activa',        'Activa'),
        ('buscando',      'Buscando pareja'),
        ('en_match',      'En match 2pa2'),
        ('cerrada',       'Cerrada'),
    ]


# Límites diarios (todos 10)
LIKES_DIARIOS = {
    'pareja':  10,
    'amistad': 10,
    'estudio': 10,
    '2pa2':    10,
}

SUPERLIKES_DIARIOS = 1
LIKE_TTL_SEGUNDOS  = 24 * 60 * 60  # 24h

# Pesos del score — coincide exactamente con engine.py
PESOS_SCORE = {
    'intenciones': 0.30,
    'intereses':   0.25,
    'estilo_vida': 0.20,
    'carrera':     0.15,
    'horarios':    0.10,
}

DECK_SIZE      = 20
DECK_OVERFETCH = 60
