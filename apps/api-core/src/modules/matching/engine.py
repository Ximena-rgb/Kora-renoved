"""
modules/matching/engine.py
===========================
Motor de compatibilidad Kora.

Pesos:
  30% Intenciones compatibles
  25% Intereses / gustos comunes (Jaccard)
  20% Estilo de vida (hábitos, actividad)
  15% Carrera / facultad
  10% Horarios solapados
"""
from __future__ import annotations

import logging
from datetime import datetime, time

from django.db.models import Q
from django.utils import timezone

from .constants import (
    Modo, Accion, EstadoLike, PESOS_SCORE,
    DECK_SIZE, DECK_OVERFETCH, LIKES_DIARIOS,
)

logger = logging.getLogger(__name__)


# ══════════════════════════════════════════════════════════════════
# SCORING
# ══════════════════════════════════════════════════════════════════

def score_intenciones(intenciones_a: list, intenciones_b: list, modo: str) -> float:
    """
    1.0 → ambos tienen el modo activo en sus intenciones
    0.5 → uno tiene el modo, el otro tiene un modo compatible
    0.0 → incompatibles
    """
    set_a = set(intenciones_a)
    set_b = set(intenciones_b)
    if modo in set_a and modo in set_b:
        return 1.0
    # Amistad y pareja son parcialmente compatibles
    if modo == Modo.PAREJA and Modo.AMISTAD in set_a and Modo.AMISTAD in set_b:
        return 0.3
    return 0.0


def score_intereses(intereses_a: list, intereses_b: list) -> float:
    """Jaccard similarity entre gustos. 0.0–1.0"""
    set_a = {i.lower().strip() for i in intereses_a}
    set_b = {i.lower().strip() for i in intereses_b}
    if not set_a or not set_b:
        return 0.0
    return len(set_a & set_b) / len(set_a | set_b)


def score_estilo_vida(profile_a, profile_b) -> float:
    """
    Compara hábitos: fuma, bebe, sale_fiesta, nivel_actividad.
    Más similares = mayor score. Divisor dinámico para evitar 0.0 cuando no hay datos.
    """
    if not profile_a or not profile_b:
        return 0.5  # Sin datos → neutral

    puntos      = 0.0
    comparados  = 0  # Contamos solo campos con datos en AMBOS perfiles

    # Fuma
    if profile_a.fuma and profile_b.fuma:
        comparados += 1
        puntos += 1.0 if profile_a.fuma == profile_b.fuma else (
            0.5 if 'no' not in (profile_a.fuma, profile_b.fuma) else 0.0
        )

    # Bebe
    if profile_a.bebe and profile_b.bebe:
        comparados += 1
        puntos += 1.0 if profile_a.bebe == profile_b.bebe else (
            0.5 if 'no' not in (profile_a.bebe, profile_b.bebe) else 0.0
        )

    # Sale de fiesta
    if profile_a.sale_fiesta and profile_b.sale_fiesta:
        comparados += 1
        puntos += 1.0 if profile_a.sale_fiesta == profile_b.sale_fiesta else 0.5

    # Nivel de actividad
    if profile_a.nivel_actividad and profile_b.nivel_actividad:
        comparados += 1
        niveles    = {'sedentario': 0, 'moderado': 1, 'activo': 2, 'muy_activo': 3}
        na         = niveles.get(profile_a.nivel_actividad, 1)
        nb         = niveles.get(profile_b.nivel_actividad, 1)
        puntos     += max(0.0, 1.0 - abs(na - nb) * 0.4)

    # Si no hay ningún campo en común → neutral
    if comparados == 0:
        return 0.5

    return puntos / comparados


def score_carrera(carrera_a: str, facultad_a: str, carrera_b: str, facultad_b: str) -> float:
    """1.0 = misma carrera | 0.5 = misma facultad | 0.0 = nada"""
    if carrera_a and carrera_a.lower().strip() == carrera_b.lower().strip():
        return 1.0
    if facultad_a and facultad_b and facultad_a.lower().strip() == facultad_b.lower().strip():
        return 0.5
    return 0.0


def score_horarios(horarios_a: list, horarios_b: list) -> float:
    """Minutos de solapamiento normalizados a [0,1]. Máximo 600 min."""
    if not horarios_a or not horarios_b:
        return 0.0

    dias_a: dict[str, list] = {}
    for b in horarios_a:
        try:
            dia = b.get('dia', '').lower()
            ini = datetime.strptime(b.get('inicio', '00:00'), '%H:%M').time()
            fin = datetime.strptime(b.get('fin',    '00:00'), '%H:%M').time()
            dias_a.setdefault(dia, []).append((ini, fin))
        except Exception:
            continue

    total = 0
    for b in horarios_b:
        try:
            dia  = b.get('dia', '').lower()
            ini_b = datetime.strptime(b.get('inicio', '00:00'), '%H:%M').time()
            fin_b = datetime.strptime(b.get('fin',    '00:00'), '%H:%M').time()
        except Exception:
            continue
        for ini_a, fin_a in dias_a.get(dia, []):
            s = max(ini_a, ini_b)
            e = min(fin_a, fin_b)
            if s < e:
                delta = datetime.combine(datetime.today(), e) - datetime.combine(datetime.today(), s)
                total += int(delta.total_seconds() / 60)

    return min(total / 600, 1.0)


def calcular_score_completo(user_a, user_b, modo: str) -> dict:
    """
    Score total entre dos usuarios para un modo dado.
    Retorna desglose completo 0-100.
    """
    # Obtener perfiles del onboarding
    profile_a = getattr(user_a, 'profile', None)
    profile_b = getattr(user_b, 'profile', None)

    int_a = profile_a.intenciones if profile_a else []
    int_b = profile_b.intenciones if profile_b else []

    s_intenciones  = score_intenciones(int_a, int_b, modo)
    s_intereses    = score_intereses(user_a.intereses, user_b.intereses)
    s_estilo       = score_estilo_vida(profile_a, profile_b)
    s_carrera      = score_carrera(user_a.carrera, user_a.facultad,
                                   user_b.carrera, user_b.facultad)
    s_horarios     = score_horarios(user_a.horarios, user_b.horarios)

    p = PESOS_SCORE
    total = (
        s_intenciones * p['intenciones'] +
        s_intereses   * p['intereses']   +
        s_estilo      * p['estilo_vida'] +
        s_carrera     * p['carrera']     +
        s_horarios    * p['horarios']
    ) * 100

    return {
        'score_total':       round(total, 1),
        'score_intenciones': round(s_intenciones * 100, 1),
        'score_intereses':   round(s_intereses   * 100, 1),
        'score_estilo_vida': round(s_estilo      * 100, 1),
        'score_carrera':     round(s_carrera     * 100, 1),
        'score_horarios':    round(s_horarios    * 100, 1),
    }


# ══════════════════════════════════════════════════════════════════
# FILTRADO DE CANDIDATOS
# ══════════════════════════════════════════════════════════════════

def get_ids_excluidos(user, modo: str) -> set:
    """
    IDs que NO deben aparecer en el deck del usuario:
    - Ya hizo swipe (like o pass)
    - Está bloqueado en cualquier dirección
    - El propio usuario
    """
    from .models import SwipeAction, Bloqueo

    ya_swipeados = set(
        SwipeAction.objects.filter(de_usuario=user, modo=modo)
        .values_list('a_usuario_id', flat=True)
    )
    bloqueados = set(
        Bloqueo.objects.filter(Q(bloqueador=user) | Q(bloqueado=user))
        .values_list('bloqueador_id', 'bloqueado_id')
    )
    ids_bloqueados = {uid for par in bloqueados for uid in par}

    return ya_swipeados | ids_bloqueados | {user.id}


def get_deck(user, modo: str, limit: int = DECK_SIZE) -> list[dict]:
    """
    Genera el deck de candidatos para el usuario en el modo dado.

    Filtros aplicados:
    1. Perfil completo con fotos aprobadas
    2. Tiene la intención del modo activo
    3. No ha sido swipeado antes
    4. No bloqueado entre sí
    5. Para pareja: compatibilidad de género/orientación
    6. Rankeado por score descendente
    """
    from django.contrib.auth import get_user_model
    from modules.onboarding.models import UserProfile, UserPhoto

    User = get_user_model()

    excluidos = get_ids_excluidos(user, modo)

    # Usuarios base: perfil completo y activos
    candidatos_qs = User.objects.filter(
        is_active=True,
        perfil_completo=True,
    ).exclude(
        id__in=excluidos
    ).select_related('profile').prefetch_related('fotos')

    # Solo usuarios con fotos aprobadas
    con_fotos = set(
        UserPhoto.objects.filter(estado='approved')
        .values_list('user_id', flat=True)
    )
    candidatos_qs = candidatos_qs.filter(id__in=con_fotos)

    # Filtrar por intención del modo
    if modo != Modo.DOS_PA_DOS:
        usuarios_con_intencion = set(
            UserProfile.objects.filter(intenciones__contains=[modo])
            .values_list('user_id', flat=True)
        )
        candidatos_qs = candidatos_qs.filter(id__in=usuarios_con_intencion)

    # Filtro de género para modo pareja
    profile_user = getattr(user, 'profile', None)
    if modo == Modo.PAREJA and profile_user:
        candidatos_qs = _filtrar_por_preferencia_genero(
            candidatos_qs, user, profile_user
        )

    # Calcular scores y rankear
    resultados = []
    for candidato in candidatos_qs[:DECK_OVERFETCH]:
        scores = calcular_score_completo(user, candidato, modo)
        resultados.append({'usuario': candidato, **scores})

    resultados.sort(key=lambda x: x['score_total'], reverse=True)
    return resultados[:limit]


def _filtrar_por_preferencia_genero(qs, user, profile_user):
    """
    Filtra candidatos de pareja según:
    - Lo que el usuario busca (interesado_en_pareja)
    - Lo que el candidato busca (interesado_en_pareja)
    """
    from modules.onboarding.models import UserProfile

    mi_genero            = getattr(profile_user, 'genero', '')
    lo_que_busco         = profile_user.interesado_en_pareja

    if not lo_que_busco or 'todos' in lo_que_busco:
        return qs

    # Mapeo género → filtro
    GENERO_A_INTERES = {
        'masculino': 'hombres',
        'femenino':  'mujeres',
        'no_binario': 'otros',
        'otro':      'otros',
    }
    mi_valor_interes = GENERO_A_INTERES.get(mi_genero, '')

    # Candidatos que buscan mi género (o todos)
    if mi_valor_interes:
        ids_que_me_buscan = set(
            UserProfile.objects.filter(
                Q(interesado_en_pareja__contains=[mi_valor_interes]) |
                Q(interesado_en_pareja__contains=['todos'])
            ).values_list('user_id', flat=True)
        )
        qs = qs.filter(id__in=ids_que_me_buscan)

    # Candidatos cuyo género me interesa
    filtro_genero = Q()
    for interes in lo_que_busco:
        INTERES_A_GENERO = {
            'hombres': ['masculino'],
            'mujeres': ['femenino'],
            'otros':   ['no_binario', 'otro'],
            'todos':   ['masculino', 'femenino', 'no_binario', 'otro'],
        }
        generos = INTERES_A_GENERO.get(interes, [])
        for g in generos:
            filtro_genero |= Q(profile__genero=g)

    if filtro_genero:
        qs = qs.filter(filtro_genero)

    return qs


# ══════════════════════════════════════════════════════════════════
# LÍMITES DIARIOS
# ══════════════════════════════════════════════════════════════════

def get_likes_restantes(user, modo: str) -> dict:
    """Retorna cuántos likes le quedan hoy al usuario en ese modo."""
    from .models import LikeDiario
    from .constants import LIKES_DIARIOS, SUPERLIKES_DIARIOS

    hoy = timezone.localdate()
    registro, _ = LikeDiario.objects.get_or_create(
        usuario=user, modo=modo, fecha=hoy,
        defaults={'cantidad': 0, 'superlike_usado': False}
    )

    limite = LIKES_DIARIOS.get(modo, 10)
    return {
        'usados':          registro.cantidad,
        'limite':          limite,
        'restantes':       max(0, limite - registro.cantidad),
        'superlike_disponible': not registro.superlike_usado,
        'puede_likear':    registro.cantidad < limite,
    }


def registrar_like(user, modo: str, es_superlike: bool = False) -> bool:
    """
    Registra un like en el contador diario.
    Retorna True si se pudo registrar, False si ya agotó el límite.
    """
    from .models import LikeDiario
    from .constants import LIKES_DIARIOS

    hoy    = timezone.localdate()
    limite = LIKES_DIARIOS.get(modo, 10)

    registro, _ = LikeDiario.objects.get_or_create(
        usuario=user, modo=modo, fecha=hoy,
        defaults={'cantidad': 0, 'superlike_usado': False}
    )

    if registro.cantidad >= limite:
        return False
    if es_superlike and registro.superlike_usado:
        return False

    registro.cantidad += 1
    if es_superlike:
        registro.superlike_usado = True
    registro.save(update_fields=['cantidad', 'superlike_usado'])
    return True


# ══════════════════════════════════════════════════════════════════
# MOTOR DE MATCH
# ══════════════════════════════════════════════════════════════════

def procesar_match(like: 'SwipeAction') -> 'Match | None':
    """
    Verifica si hay like recíproco y crea el Match si es así.
    Crea la conversación automáticamente.
    """
    from .models import Match, SwipeAction

    reciproco = SwipeAction.objects.filter(
        de_usuario_id = like.a_usuario_id,
        a_usuario_id  = like.de_usuario_id,
        modo          = like.modo,
        accion__in    = [Accion.LIKE, Accion.SUPERLIKE],
        estado        = EstadoLike.PENDIENTE,
    ).first()

    if not reciproco:
        return None

    # Like recíproco → crear match
    u1, u2 = Match.normalizar_usuarios(like.de_usuario, like.a_usuario)
    scores = calcular_score_completo(u1, u2, like.modo)

    match, created = Match.objects.get_or_create(
        usuario_1 = u1,
        usuario_2 = u2,
        modo      = like.modo,
        defaults  = {'score': scores['score_total']},
    )

    if created:
        # Marcar ambos likes como aceptados
        like.estado      = EstadoLike.ACEPTADO
        reciproco.estado = EstadoLike.ACEPTADO
        SwipeAction.objects.bulk_update([like, reciproco], ['estado'])

        # Crear conversación automáticamente
        _crear_conversacion_match(match)

        logger.info(f'[Match] Nuevo match [{like.modo}] {u1.id} ↔ {u2.id} score={scores["score_total"]}')

    return match if created else None


def _crear_conversacion_match(match: 'Match'):
    """
    Crea la conversación de chat al hacer match.
    Si el match es de PAREJA, publica AI_COACH_REQUEST para que
    el asistente del amor genere el primer mensaje (icebreaker).
    """
    try:
        from modules.chat.models import Conversacion
        from shared.broker import broker

        u1, u2 = match.usuario_1, match.usuario_2
        room_id = Conversacion.get_or_create_room_id(u1.id, u2.id)
        conv, created = Conversacion.objects.get_or_create(
            room_id  = room_id,
            defaults = {'usuario_1': u1, 'usuario_2': u2}
        )
        match.conversacion_id = conv.id
        match.save(update_fields=['conversacion_id'])

        # Solo para matches de PAREJA: icebreaker automático
        if created and match.modo == 'pareja':
            p1 = getattr(u1, 'profile', None)
            p2 = getattr(u2, 'profile', None)
            broker.publish('AI_COACH_REQUEST', {
                'tipo':    'icebreaker',
                'user_id': u1.id,
                'room_id': room_id,
                'contexto': {
                    'nombre_mio':     u1.nombre,
                    'nombre_otro':    u2.nombre,
                    'carrera_mia':    u1.carrera,
                    'carrera_otro':   u2.carrera,
                    'intereses_mios': u1.intereses,
                    'intereses_otro': u2.intereses,
                    'gustos_mios':    getattr(p1, 'gustos', []) if p1 else [],
                    'gustos_otro':    getattr(p2, 'gustos', []) if p2 else [],
                },
            })
            logger.info(f'[Match] Icebreaker IA publicado para room={room_id}')

    except Exception as exc:
        logger.error(f'[Match] Error creando conversación: {exc}')


# ══════════════════════════════════════════════════════════════════
# EXPIRACIÓN (llamar desde management command / celery)
# ══════════════════════════════════════════════════════════════════

def expirar_likes_vencidos() -> int:
    """
    Expira los likes que llevan más de 24h sin respuesta.
    Retorna cantidad de likes expirados.
    """
    from .models import SwipeAction, Contrapropuesta

    ahora = timezone.now()

    # Expirar likes
    expirados = SwipeAction.objects.filter(
        accion__in = [Accion.LIKE, Accion.SUPERLIKE],
        estado     = EstadoLike.PENDIENTE,
        expira_en__lte = ahora,
    ).update(estado=EstadoLike.EXPIRADO)

    # Expirar contrapropuestas
    from .constants import EstadoContrapropuesta
    Contrapropuesta.objects.filter(
        estado    = EstadoContrapropuesta.PENDIENTE,
        expira_en__lte = ahora,
    ).update(estado=EstadoContrapropuesta.EXPIRADA)

    # Expirar matches 2pa2
    from .models import Match2pa2
    Match2pa2.objects.filter(
        estado__in = [Match2pa2.Estado.PENDIENTE_A, Match2pa2.Estado.PENDIENTE_B],
        expira_en__lte = ahora,
    ).update(estado=Match2pa2.Estado.EXPIRADO)

    if expirados:
        logger.info(f'[Engine] {expirados} likes expirados')

    return expirados


# ══════════════════════════════════════════════════════════════════
# MOTOR 2PA2
# ══════════════════════════════════════════════════════════════════

def buscar_dupla_compatible(dupla: 'DuplaDos') -> 'DuplaDos | None':
    """
    Busca una dupla compatible para el modo 2pa2.

    Compatibilidad:
    - pref_user_1 de dupla_a debe coincidir con género de algún user de dupla_b
    - pref_user_2 de dupla_a debe coincidir con género del otro user de dupla_b
    - No deben haberse rechazado antes
    """
    from .models import DuplaDos, Match2pa2
    from .constants import EstadoDupla

    # Duplas activas buscando match (excluyendo la propia)
    candidatas = DuplaDos.objects.filter(
        estado = EstadoDupla.BUSCANDO,
    ).exclude(
        id = dupla.id,
    ).select_related('user_1__profile', 'user_2__profile')

    # Filtrar rechazos previos
    rechazadas = set(
        Match2pa2.objects.filter(
            Q(dupla_a=dupla) | Q(dupla_b=dupla),
            estado=Match2pa2.Estado.RECHAZADO,
        ).values_list('dupla_a_id', 'dupla_b_id')
    )
    ids_rechazadas = {uid for par in rechazadas for uid in par} - {dupla.id}

    for candidata in candidatas:
        if candidata.id in ids_rechazadas:
            continue

        if _son_duplas_compatibles(dupla, candidata):
            return candidata

    return None


def _son_duplas_compatibles(dupla_a: 'DuplaDos', dupla_b: 'DuplaDos') -> bool:
    """
    Verifica cross-compatibilidad de géneros entre dos duplas.
    Juan(busca mujer) + Sara(busca hombre) ↔ Pedro(busca mujer) + María(busca hombre)
    → Juan↔María ✅  Sara↔Pedro ✅
    """
    GENERO_PARA_INTERES = {
        'hombres': ['masculino'],
        'mujeres': ['femenino'],
        'otros':   ['no_binario', 'otro'],
        'todos':   ['masculino', 'femenino', 'no_binario', 'otro'],
    }

    def genero_de(user):
        p = getattr(user, 'profile', None)
        return getattr(p, 'genero', '') if p else ''

    ga1 = genero_de(dupla_a.user_1)
    ga2 = genero_de(dupla_a.user_2)
    gb1 = genero_de(dupla_b.user_1)
    gb2 = genero_de(dupla_b.user_2)

    def busca(pref: str, genero: str) -> bool:
        if not pref or not genero:
            return True  # Sin preferencia → acepta cualquiera
        permitidos = GENERO_PARA_INTERES.get(pref, [])
        return genero in permitidos

    # Combinación 1: a1↔b1, a2↔b2
    combo1 = (
        busca(dupla_a.pref_user_1, gb1) and busca(dupla_b.pref_user_1, ga1) and
        busca(dupla_a.pref_user_2, gb2) and busca(dupla_b.pref_user_2, ga2)
    )
    # Combinación 2: a1↔b2, a2↔b1
    combo2 = (
        busca(dupla_a.pref_user_1, gb2) and busca(dupla_b.pref_user_2, ga1) and
        busca(dupla_a.pref_user_2, gb1) and busca(dupla_b.pref_user_1, ga2)
    )

    return combo1 or combo2
