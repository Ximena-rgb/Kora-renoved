"""
modules/matching/views.py  — Motor de matching Kora (sin doble notificación)
"""
import logging
from django.contrib.auth import get_user_model
from django.db.models import Q
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from shared.audit import audit
from shared.broker import broker
from modules.notifications.service import enviar_notificacion_ws

from .constants import (
    Modo, Accion, EstadoLike, EstadoMatch,
    EstadoContrapropuesta, EstadoDupla,
)
from .engine import (
    get_deck, get_likes_restantes, registrar_like,
    procesar_match, buscar_dupla_compatible,
)
from .models import (
    SwipeAction, Match, Contrapropuesta,
    Bloqueo, LikeDiario, DuplaDos, Match2pa2,
)
from .serializers import (
    DeckSerializer, SwipeSerializer, ResponderLikeSerializer,
    MatchSerializer, DuplaDosSerializer, CrearDuplaSerializer,
)

logger = logging.getLogger(__name__)
User   = get_user_model()


def _publicar_match(match, modo):
    """Publica MATCH_CREATED al broker — el stream-consumer notifica a los usuarios."""
    broker.publish('MATCH_CREATED', {
        'match_id':  match.id,
        'usuario_1': match.usuario_1_id,
        'usuario_2': match.usuario_2_id,
        'modo':      modo,
        'score':     match.score,
    })
    audit.log(None, audit.MATCH_CREATED, {'match_id': match.id, 'modo': modo})


# ── GET /matching/deck/ ───────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def deck(request):
    modo = request.query_params.get('modo', Modo.PAREJA)
    if modo not in [Modo.PAREJA, Modo.AMISTAD, Modo.ESTUDIO]:
        return Response({'error': 'Modo inválido. Usa: pareja, amistad, estudio'},
                        status=status.HTTP_400_BAD_REQUEST)
    if not request.user.perfil_completo:
        return Response({'error': 'Completa tu perfil antes de usar el matching.'},
                        status=status.HTTP_403_FORBIDDEN)

    # Verificar que el usuario tiene la intención del modo solicitado
    try:
        intenciones_usuario = list(request.user.profile.intenciones or [])
    except Exception:
        intenciones_usuario = []

    if intenciones_usuario and modo not in intenciones_usuario:
        return Response(
            {
                'error': f'No tienes "{modo}" entre tus intenciones. '
                         f'Actualiza tu perfil para acceder a este modo.',
                'intenciones': intenciones_usuario,
            },
            status=status.HTTP_403_FORBIDDEN,
        )

    candidatos = get_deck(request.user, modo)
    likes_info = get_likes_restantes(request.user, modo)
    return Response({
        'modo':            modo,
        'likes_restantes': likes_info,
        'candidatos':      DeckSerializer(candidatos, many=True,
                               context={'request': request}).data,
    })


# ── POST /matching/swipe/ ─────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def swipe(request):
    s = SwipeSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    data = s.validated_data

    a_usuario_id = data['a_usuario_id']
    modo         = data['modo']
    accion       = data['accion']
    es_superlike = data.get('es_superlike', False)

    if a_usuario_id == request.user.id:
        return Response({'error': 'No puedes hacerte swipe a ti mismo.'},
                        status=status.HTTP_400_BAD_REQUEST)

    try:
        target = User.objects.get(pk=a_usuario_id, is_active=True, perfil_completo=True)
    except User.DoesNotExist:
        return Response({'error': 'Usuario no encontrado.'}, status=status.HTTP_404_NOT_FOUND)

    if Bloqueo.objects.filter(
        Q(bloqueador=request.user, bloqueado=target) |
        Q(bloqueador=target, bloqueado=request.user)
    ).exists():
        return Response({'error': 'No puedes interactuar con este usuario.'},
                        status=status.HTTP_400_BAD_REQUEST)

    if SwipeAction.objects.filter(
        de_usuario=request.user, a_usuario=target, modo=modo
    ).exists():
        return Response({'error': 'Ya hiciste swipe a este usuario en este modo.'},
                        status=status.HTTP_400_BAD_REQUEST)

    if accion in (Accion.LIKE, Accion.SUPERLIKE):
        if not registrar_like(request.user, modo, es_superlike=es_superlike):
            info = get_likes_restantes(request.user, modo)
            return Response({
                'error': 'Agotaste tus likes de hoy. Vuelve mañana.',
                'likes_info': info,
            }, status=status.HTTP_429_TOO_MANY_REQUESTS)

    like = SwipeAction.objects.create(
        de_usuario   = request.user,
        a_usuario    = target,
        modo         = modo,
        accion       = accion,
        es_superlike = es_superlike,
        estado       = EstadoLike.PENDIENTE if accion != Accion.PASS else EstadoLike.RECHAZADO,
    )

    if accion == Accion.PASS:
        # Pass: solo registrar swipe, NO crear Bloqueo
        return Response({'accion': 'pass', 'match': None,
                         'likes_restantes': get_likes_restantes(request.user, modo)})

    # Notificar al target (sin revelar quién si no es superlike)
    titulo = '⭐ ¡Super Like!' if es_superlike else '💌 Alguien te dio like'
    cuerpo = f'{request.user.nombre} te dio Super Like 🔥' if es_superlike else \
             'Revisa tu bandeja para ver quién es.'
    enviar_notificacion_ws(target.id, titulo, cuerpo,
        {'tipo': 'like_recibido', 'modo': modo, 'superlike': es_superlike,
         'de_usuario_id': request.user.id if es_superlike else None})

    match = procesar_match(like)
    if match:
        _publicar_match(match, modo)  # Una sola notificación via broker

    return Response({
        'accion':          accion,
        'match_creado':    match is not None,
        'match':           MatchSerializer(match, context={'request': request}).data if match else None,
        'likes_restantes': get_likes_restantes(request.user, modo),
    })


# ── GET /matching/bandeja/ ────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def bandeja(request):
    modo = request.query_params.get('modo')
    ahora = timezone.now()
    likes_qs = SwipeAction.objects.filter(
        a_usuario  = request.user,
        accion__in = [Accion.LIKE, Accion.SUPERLIKE],
        estado     = EstadoLike.PENDIENTE,
        expira_en__gt = ahora,
    ).select_related('de_usuario__profile').order_by('-created_at')
    if modo:
        likes_qs = likes_qs.filter(modo=modo)

    resultados = []
    for like in likes_qs:
        u = like.de_usuario
        resultados.append({
            'like_id':    like.id,
            'modo':       like.modo,
            'superlike':  like.es_superlike,
            'expira_en':  like.expira_en,
            'created_at': like.created_at,
            'de_usuario': {
                'id':        u.id,
                'nombre':    u.nombre,
                'foto_url':  u.foto_url,
                'carrera':   u.carrera,
                'facultad':  u.facultad,
                'semestre':  u.semestre,
                'bio_corta': getattr(getattr(u, 'profile', None), 'bio_corta', ''),
                'reputacion': float(u.reputacion),
            },
        })
    return Response({'total': len(resultados), 'likes': resultados})


# ── POST /matching/responder/<like_id>/ ──────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def responder_like(request, like_id):
    s = ResponderLikeSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    respuesta = s.validated_data['respuesta']

    try:
        like = SwipeAction.objects.select_related('de_usuario').get(
            pk=like_id, a_usuario=request.user,
            accion__in=[Accion.LIKE, Accion.SUPERLIKE],
            estado=EstadoLike.PENDIENTE,
        )
    except SwipeAction.DoesNotExist:
        return Response({'error': 'Like no encontrado o ya expirado.'}, status=404)

    if like.esta_expirado:
        like.estado = EstadoLike.EXPIRADO
        like.save(update_fields=['estado'])
        return Response({'error': 'Este like ya expiró.'}, status=400)

    de_user = like.de_usuario

    if respuesta == 'aceptar':
        from .engine import calcular_score_completo, _crear_conversacion_match
        u1, u2 = Match.normalizar_usuarios(request.user, de_user)
        scores = calcular_score_completo(u1, u2, like.modo)
        match, created = Match.objects.get_or_create(
            usuario_1=u1, usuario_2=u2, modo=like.modo,
            defaults={'score': scores['score_total']},
        )
        if created:
            like.estado = EstadoLike.ACEPTADO
            like.save(update_fields=['estado'])
            _crear_conversacion_match(match)
            _publicar_match(match, like.modo)
        return Response({'resultado': 'match_creado',
                         'match': MatchSerializer(match, context={'request': request}).data})

    if respuesta == 'rechazar':
        like.estado = EstadoLike.RECHAZADO
        like.save(update_fields=['estado'])
        Bloqueo.objects.get_or_create(bloqueador=request.user, bloqueado=de_user,
                                      defaults={'motivo': 'rechazo'})
        Bloqueo.objects.get_or_create(bloqueador=de_user, bloqueado=request.user,
                                      defaults={'motivo': 'rechazo'})
        return Response({'resultado': 'rechazado'})

    if respuesta == 'contrapropuesta':
        if like.modo != Modo.PAREJA:
            return Response({'error': 'Contrapropuesta solo disponible para likes de pareja.'}, status=400)
        if Contrapropuesta.objects.filter(like_original=like).exists():
            return Response({'error': 'Ya enviaste una contrapropuesta.'}, status=400)
        contra = Contrapropuesta.objects.create(
            like_original=like, de_usuario=request.user,
            a_usuario=de_user, modo_propuesto=Modo.AMISTAD,
        )
        like.estado = EstadoLike.CONTRAPROPUESTA
        like.save(update_fields=['estado'])
        enviar_notificacion_ws(de_user.id, '🤝 Contrapropuesta de amistad',
            f'{request.user.nombre} prefiere conectar como amigos/as.',
            {'tipo': 'contrapropuesta', 'contrapropuesta_id': contra.id,
             'de_usuario_id': request.user.id})
        return Response({'resultado': 'contrapropuesta_enviada', 'contrapropuesta_id': contra.id})


# ── POST /matching/contrapropuesta/<id>/responder/ ────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def responder_contrapropuesta(request, contra_id):
    respuesta = request.data.get('respuesta')
    if respuesta not in ('aceptar', 'rechazar'):
        return Response({'error': 'Respuesta: aceptar o rechazar'}, status=400)

    try:
        contra = Contrapropuesta.objects.select_related(
            'de_usuario', 'a_usuario', 'like_original'
        ).get(pk=contra_id, a_usuario=request.user, estado=EstadoContrapropuesta.PENDIENTE)
    except Contrapropuesta.DoesNotExist:
        return Response({'error': 'Contrapropuesta no encontrada.'}, status=404)

    if timezone.now() > contra.expira_en:
        contra.estado = EstadoContrapropuesta.EXPIRADA
        contra.save(update_fields=['estado'])
        return Response({'error': 'La contrapropuesta expiró.'}, status=400)

    if respuesta == 'aceptar':
        contra.estado = EstadoContrapropuesta.ACEPTADA
        contra.save(update_fields=['estado'])
        from .engine import calcular_score_completo, _crear_conversacion_match
        u1, u2 = Match.normalizar_usuarios(contra.de_usuario, contra.a_usuario)
        scores = calcular_score_completo(u1, u2, Modo.AMISTAD)
        match, created = Match.objects.get_or_create(
            usuario_1=u1, usuario_2=u2, modo=Modo.AMISTAD,
            defaults={'score': scores['score_total']},
        )
        if created:
            _crear_conversacion_match(match)
            _publicar_match(match, Modo.AMISTAD)
        return Response({'resultado': 'match_amistad_creado',
                         'match': MatchSerializer(match, context={'request': request}).data})
    else:
        contra.estado = EstadoContrapropuesta.RECHAZADA
        contra.save(update_fields=['estado'])
        Bloqueo.objects.get_or_create(bloqueador=contra.de_usuario,
            bloqueado=contra.a_usuario, defaults={'motivo': 'rechazo'})
        Bloqueo.objects.get_or_create(bloqueador=contra.a_usuario,
            bloqueado=contra.de_usuario, defaults={'motivo': 'rechazo'})
        return Response({'resultado': 'rechazado'})


# ── GET /matching/matches/ ────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def mis_matches(request):
    modo = request.query_params.get('modo')
    qs = Match.objects.filter(
        Q(usuario_1=request.user) | Q(usuario_2=request.user),
        estado=EstadoMatch.ACTIVO,
    ).select_related('usuario_1__profile', 'usuario_2__profile').order_by('-created_at')
    if modo:
        qs = qs.filter(modo=modo)
    return Response(MatchSerializer(qs, many=True, context={'request': request}).data)


# ── POST /matching/bloquear/<user_id>/ ───────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def bloquear(request, user_id):
    if user_id == request.user.id:
        return Response({'error': 'No puedes bloquearte a ti mismo.'}, status=400)
    try:
        target = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({'error': 'Usuario no encontrado.'}, status=404)
    Bloqueo.objects.get_or_create(bloqueador=request.user, bloqueado=target,
                                  defaults={'motivo': 'manual'})
    Bloqueo.objects.get_or_create(bloqueador=target, bloqueado=request.user,
                                  defaults={'motivo': 'manual'})
    Match.objects.filter(
        Q(usuario_1=request.user, usuario_2=target) |
        Q(usuario_1=target, usuario_2=request.user)
    ).update(estado=EstadoMatch.BLOQUEADO)
    return Response({'mensaje': 'Usuario bloqueado.'})


# ── GET /matching/likes-restantes/ ───────────────────────────────
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def likes_restantes(request):
    return Response({
        modo: get_likes_restantes(request.user, modo)
        for modo in [Modo.PAREJA, Modo.AMISTAD, Modo.ESTUDIO]
    })


# ═══════════════════════════════════════════════════════
# MODO 2PA2
# ═══════════════════════════════════════════════════════

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def crear_dupla(request):
    s = CrearDuplaSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    data = s.validated_data
    amigo_id       = data['amigo_id']
    mi_preferencia = data.get('mi_preferencia', '')
    if amigo_id == request.user.id:
        return Response({'error': 'No puedes invitarte a ti mismo.'}, status=400)
    try:
        amigo = User.objects.get(pk=amigo_id, is_active=True, perfil_completo=True)
    except User.DoesNotExist:
        return Response({'error': 'Usuario no encontrado.'}, status=404)
    dupla_existente = DuplaDos.objects.filter(
        Q(user_1=request.user, user_2=amigo) | Q(user_1=amigo, user_2=request.user),
        estado__in=[EstadoDupla.PENDIENTE_INVITACION, EstadoDupla.ACTIVA, EstadoDupla.BUSCANDO]
    ).exists()
    if dupla_existente:
        return Response({'error': 'Ya tienes una dupla activa con este usuario.'}, status=400)
    dupla = DuplaDos.objects.create(user_1=request.user, user_2=amigo,
                                     estado=EstadoDupla.PENDIENTE_INVITACION,
                                     pref_user_1=mi_preferencia)
    enviar_notificacion_ws(amigo.id, '👫 Invitación 2pa2',
        f'{request.user.nombre} te invita a hacer un 2pa2!',
        {'tipo': 'invitacion_2pa2', 'dupla_id': dupla.id,
         'de_usuario_id': request.user.id})
    return Response(DuplaDosSerializer(dupla).data, status=201)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def aceptar_dupla(request, dupla_id):
    aceptar        = request.data.get('aceptar', True)
    mi_preferencia = request.data.get('mi_preferencia', '')
    try:
        dupla = DuplaDos.objects.get(pk=dupla_id, user_2=request.user,
                                      estado=EstadoDupla.PENDIENTE_INVITACION)
    except DuplaDos.DoesNotExist:
        return Response({'error': 'Invitación no encontrada.'}, status=404)
    if not aceptar:
        dupla.estado = EstadoDupla.CERRADA
        dupla.save(update_fields=['estado'])
        return Response({'resultado': 'invitacion_rechazada'})
    dupla.estado      = EstadoDupla.ACTIVA
    dupla.pref_user_2 = mi_preferencia
    dupla.save(update_fields=['estado', 'pref_user_2'])
    enviar_notificacion_ws(dupla.user_1_id, '✅ Dupla formada!',
        f'{request.user.nombre} aceptó tu invitación.',
        {'tipo': 'dupla_aceptada', 'dupla_id': dupla.id})
    return Response(DuplaDosSerializer(dupla).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def buscar_2pa2(request, dupla_id):
    try:
        dupla = DuplaDos.objects.get(pk=dupla_id, estado=EstadoDupla.ACTIVA)
    except DuplaDos.DoesNotExist:
        return Response({'error': 'Dupla no encontrada o no activa.'}, status=404)
    if request.user.id not in (dupla.user_1_id, dupla.user_2_id):
        return Response({'error': 'No eres parte de esta dupla.'}, status=403)
    dupla.estado = EstadoDupla.BUSCANDO
    dupla.save(update_fields=['estado'])
    dupla_b = buscar_dupla_compatible(dupla)
    if dupla_b:
        match = Match2pa2.objects.create(dupla_a=dupla, dupla_b=dupla_b)
        DuplaDos.objects.filter(pk__in=[dupla.pk, dupla_b.pk]).update(estado=EstadoDupla.EN_MATCH)
        for uid in [dupla.user_1_id, dupla.user_2_id, dupla_b.user_1_id, dupla_b.user_2_id]:
            enviar_notificacion_ws(uid, '👫 Propuesta 2pa2!',
                'Encontramos una dupla compatible. ¡Revísala!',
                {'tipo': 'match_2pa2_propuesta', 'match_2pa2_id': match.id})
        return Response({'buscando': False, 'match_encontrado': True, 'match_2pa2_id': match.id})
    return Response({'buscando': True, 'match_encontrado': False,
                     'mensaje': 'En cola. Te notificaremos cuando encontremos una dupla.'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def responder_2pa2(request, match_id):
    aceptar = request.data.get('aceptar', False)
    try:
        match2 = Match2pa2.objects.select_related('dupla_a', 'dupla_b').get(pk=match_id)
    except Match2pa2.DoesNotExist:
        return Response({'error': 'Match 2pa2 no encontrado.'}, status=404)
    es_dupla_a = request.user.id in (match2.dupla_a.user_1_id, match2.dupla_a.user_2_id)
    es_dupla_b = request.user.id in (match2.dupla_b.user_1_id, match2.dupla_b.user_2_id)
    if not es_dupla_a and not es_dupla_b:
        return Response({'error': 'No eres parte de este match.'}, status=403)
    if not aceptar:
        match2.estado = Match2pa2.Estado.RECHAZADO
        match2.save(update_fields=['estado'])
        DuplaDos.objects.filter(pk__in=[match2.dupla_a_id, match2.dupla_b_id]).update(
            estado=EstadoDupla.BUSCANDO)
        return Response({'resultado': 'rechazado'})
    if es_dupla_a: match2.acepto_a = True
    if es_dupla_b: match2.acepto_b = True
    if match2.acepto_a and match2.acepto_b:
        match2.estado = Match2pa2.Estado.ACTIVO
        try:
            from modules.chat.models import Conversacion
            room_id = f'2pa2_{match2.id}'
            conv, _ = Conversacion.objects.get_or_create(
                room_id=room_id,
                defaults={'usuario_1': match2.dupla_a.user_1, 'usuario_2': match2.dupla_b.user_1}
            )
            match2.conversacion_grupal_id = conv.id
        except Exception as exc:
            logger.error(f'[2pa2] Error chat grupal: {exc}')
        for uid in [match2.dupla_a.user_1_id, match2.dupla_a.user_2_id,
                    match2.dupla_b.user_1_id, match2.dupla_b.user_2_id]:
            enviar_notificacion_ws(uid, '🎉 Match 2pa2 confirmado!',
                'Las dos duplas aceptaron. ¡Ya tienen chat grupal!',
                {'tipo': 'match_2pa2_confirmado', 'match_2pa2_id': match2.id})
    match2.save(update_fields=['acepto_a', 'acepto_b', 'estado', 'conversacion_grupal_id'])
    return Response({
        'resultado': 'confirmado' if match2.estado == Match2pa2.Estado.ACTIVO else 'aceptado_esperando',
        'match_activo': match2.estado == Match2pa2.Estado.ACTIVO,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def mis_duplas(request):
    duplas = DuplaDos.objects.filter(
        Q(user_1=request.user) | Q(user_2=request.user)
    ).exclude(estado=EstadoDupla.CERRADA).select_related('user_1', 'user_2')
    return Response(DuplaDosSerializer(duplas, many=True, context={'request': request}).data)
