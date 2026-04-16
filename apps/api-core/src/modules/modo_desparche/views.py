"""
modules/modo_desparche/views.py
================================
Endpoints del Modo Desparche.

POST /desparche/sesiones/crear/            → crear sesión de juego
POST /desparche/sesiones/<id>/unirse/      → unirse como jugador
POST /desparche/sesiones/<id>/iniciar/     → empezar el juego
POST /desparche/sesiones/<id>/siguiente/   → siguiente ronda (genera con IA)
POST /desparche/rondas/<id>/completar/     → marcar ronda como completada
POST /desparche/rondas/<id>/votar/         → votar en ¿Quién es más probable?
GET  /desparche/sesiones/<id>/             → estado de la sesión
GET  /desparche/sesiones/<id>/resultados/  → resultados finales
"""
import logging
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from shared.broker import broker
from django.db import models as djmodels
from .models import SesionJuego, JugadorSesion, RondaJuego, VotoJuego

logger = logging.getLogger(__name__)


def _sesion_dict(sesion: SesionJuego, user=None) -> dict:
    jugadores = sesion.jugadores.filter(activo=True).select_related('usuario')
    ronda_act = sesion.rondas.filter(numero=sesion.ronda_actual).first() if sesion.ronda_actual > 0 else None
    soy_jugador = jugadores.filter(usuario=user).exists() if user else False

    return {
        'id':            sesion.id,
        'tipo_juego':    sesion.tipo_juego,
        'tipo_display':  sesion.get_tipo_juego_display(),
        'estado':        sesion.estado,
        'ronda_actual':  sesion.ronda_actual,
        'max_rondas':    sesion.max_rondas,
        'hay_mas':       sesion.hay_mas_rondas,
        'creador_id':    sesion.creador_id,
        'soy_jugador':   soy_jugador,
        'jugadores': [
            {
                'id':     j.usuario_id,
                'nombre': j.usuario.nombre,
                'foto':   j.usuario.foto_url,
                'puntos': j.puntos,
            }
            for j in jugadores
        ],
        'ronda_actual_data': _ronda_dict(ronda_act) if ronda_act else None,
    }


def _ronda_dict(ronda: RondaJuego) -> dict:
    votos = []
    if ronda.tipo_contenido == 'pregunta':
        from django.db.models import Count
        votos = list(
            ronda.votos.values('votado__nombre', 'votado_id')
            .annotate(total=Count('id'))
            .order_by('-total')
        )
    return {
        'id':            ronda.id,
        'numero':        ronda.numero,
        'tipo':          ronda.tipo_contenido,
        'contenido':     ronda.contenido,
        'destinatario':  {
            'id': ronda.destinatario_id,
            'nombre': ronda.destinatario.nombre if ronda.destinatario else '',
        } if ronda.destinatario else None,
        'foto_url':      ronda.foto_url,
        'completada':    ronda.completada,
        'votos':         votos,
    }


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def crear_sesion(request):
    """Crea una nueva sesión de juego en una room de chat."""
    tipo_juego = request.data.get('tipo_juego')
    room_id    = request.data.get('room_id')
    max_rondas = int(request.data.get('max_rondas', 10))

    if not tipo_juego or not room_id:
        return Response({'error': 'tipo_juego y room_id son requeridos.'}, status=400)

    tipos_validos = [c[0] for c in SesionJuego.TipoJuego.choices]
    if tipo_juego not in tipos_validos:
        return Response({'error': f'Tipo inválido. Opciones: {tipos_validos}'}, status=400)

    # Solo una sesión activa por room
    activa = SesionJuego.objects.filter(
        room_id=room_id,
        estado__in=[SesionJuego.Estado.ESPERANDO, SesionJuego.Estado.EN_CURSO]
    ).first()
    if activa:
        return Response({'error': 'Ya hay un juego activo en este chat.',
                         'sesion_id': activa.id}, status=400)

    sesion = SesionJuego.objects.create(
        tipo_juego   = tipo_juego,
        room_id      = room_id,
        creador      = request.user,
        max_rondas   = min(max(max_rondas, 3), 30),
    )
    JugadorSesion.objects.create(sesion=sesion, usuario=request.user)

    return Response(_sesion_dict(sesion, request.user), status=201)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def unirse_sesion(request, sesion_id):
    try:
        sesion = SesionJuego.objects.get(pk=sesion_id, estado=SesionJuego.Estado.ESPERANDO)
    except SesionJuego.DoesNotExist:
        return Response({'error': 'Sesión no encontrada o ya iniciada.'}, status=404)

    JugadorSesion.objects.get_or_create(sesion=sesion, usuario=request.user)
    return Response(_sesion_dict(sesion, request.user))


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def iniciar_sesion(request, sesion_id):
    try:
        sesion = SesionJuego.objects.get(pk=sesion_id, creador=request.user,
                                          estado=SesionJuego.Estado.ESPERANDO)
    except SesionJuego.DoesNotExist:
        return Response({'error': 'Sesión no encontrada o no eres el creador.'}, status=404)

    if sesion.jugadores.filter(activo=True).count() < 2:
        return Response({'error': 'Necesitas al menos 2 jugadores para iniciar.'}, status=400)

    sesion.estado = SesionJuego.Estado.EN_CURSO
    sesion.save(update_fields=['estado'])

    # Generar primera ronda
    _generar_siguiente_ronda(sesion)

    return Response(_sesion_dict(sesion, request.user))


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def siguiente_ronda(request, sesion_id):
    try:
        sesion = SesionJuego.objects.get(pk=sesion_id, estado=SesionJuego.Estado.EN_CURSO)
    except SesionJuego.DoesNotExist:
        return Response({'error': 'Sesión no encontrada.'}, status=404)

    if not sesion.jugadores.filter(usuario=request.user, activo=True).exists():
        return Response({'error': 'No eres jugador de esta sesión.'}, status=403)

    # Marcar ronda actual como completada si no lo está
    ronda_act = sesion.rondas.filter(numero=sesion.ronda_actual).first()
    if ronda_act and not ronda_act.completada:
        ronda_act.completada = True
        ronda_act.save(update_fields=['completada'])

    if not sesion.hay_mas_rondas:
        sesion.estado = SesionJuego.Estado.TERMINADA
        sesion.save(update_fields=['estado'])
        return Response({'terminado': True, 'mensaje': '¡Juego terminado! 🎉',
                         'sesion': _sesion_dict(sesion, request.user)})

    _generar_siguiente_ronda(sesion)
    return Response(_sesion_dict(sesion, request.user))


def _generar_siguiente_ronda(sesion: SesionJuego):
    """Genera la siguiente ronda vía IA (asíncrono por broker)."""
    import random
    sesion.ronda_actual += 1
    sesion.save(update_fields=['ronda_actual'])

    jugadores = list(sesion.jugadores.filter(activo=True).select_related('usuario'))

    # Determinar tipo de contenido
    if sesion.tipo_juego == SesionJuego.TipoJuego.VERDAD_O_RETO:
        tipo_contenido = 'verdad' if sesion.ronda_actual % 2 == 1 else 'reto'
        destinatario   = jugadores[(sesion.ronda_actual - 1) % len(jugadores)].usuario
    elif sesion.tipo_juego == SesionJuego.TipoJuego.QUIEN_MAS_PROBABLE:
        tipo_contenido = 'pregunta'
        destinatario   = None
    else:
        tipo_contenido = 'foto'
        destinatario   = None

    # Crear ronda con contenido placeholder (se actualiza cuando llega la IA)
    ronda = RondaJuego.objects.create(
        sesion         = sesion,
        numero         = sesion.ronda_actual,
        tipo_contenido = tipo_contenido,
        contenido      = '⏳ Generando con IA...',
        destinatario   = destinatario,
        generada_por_ia = True,
    )

    # Publicar al broker para que worker-ai genere el contenido
    broker.publish('AI_GAME_REQUEST', {
        'tipo_juego':    sesion.tipo_juego,
        'tipo_ronda':    tipo_contenido,
        'sesion_id':     sesion.id,
        'ronda_id':      ronda.id,
        'room_id':       sesion.room_id,
        'destinatario':  destinatario.nombre if destinatario else '',
        'jugadores':     [j.usuario.nombre for j in jugadores],
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def completar_ronda(request, ronda_id):
    try:
        ronda = RondaJuego.objects.select_related('sesion').get(pk=ronda_id)
    except RondaJuego.DoesNotExist:
        return Response({'error': 'Ronda no encontrada.'}, status=404)

    if not ronda.sesion.jugadores.filter(usuario=request.user, activo=True).exists():
        return Response({'error': 'No eres jugador.'}, status=403)

    ronda.completada = True
    ronda.save(update_fields=['completada'])

    # Dar puntos al destinatario si completó su verdad/reto
    if ronda.destinatario:
        JugadorSesion.objects.filter(
            sesion=ronda.sesion, usuario=ronda.destinatario
        ).update(puntos=djmodels.F('puntos') + 1)

    return Response({'ok': True})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def votar_ronda(request, ronda_id):
    """Votar en ¿Quién es más probable?"""
    try:
        ronda = RondaJuego.objects.get(pk=ronda_id, tipo_contenido='pregunta', completada=False)
    except RondaJuego.DoesNotExist:
        return Response({'error': 'Ronda no encontrada o ya completada.'}, status=404)

    votado_id = request.data.get('votado_id')
    if not votado_id:
        return Response({'error': 'votado_id es requerido.'}, status=400)

    if VotoJuego.objects.filter(ronda=ronda, votante=request.user).exists():
        return Response({'error': 'Ya votaste en esta ronda.'}, status=400)

    VotoJuego.objects.create(ronda=ronda, votante=request.user, votado_id=votado_id)

    # Dar punto al más votado al completar
    total_jugadores = ronda.sesion.jugadores.filter(activo=True).count()
    total_votos     = ronda.votos.count()

    if total_votos >= total_jugadores:
        # Todos votaron → dar punto al más votado
        from django.db.models import Count
        mas_votado = ronda.votos.values('votado').annotate(
            total=Count('id')).order_by('-total').first()
        if mas_votado:
            JugadorSesion.objects.filter(
                sesion=ronda.sesion, usuario_id=mas_votado['votado']
            ).update(puntos=djmodels.F('puntos') + 1)
        ronda.completada = True
        ronda.save(update_fields=['completada'])

    return Response({'ok': True, 'total_votos': total_votos})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def estado_sesion(request, sesion_id):
    try:
        sesion = SesionJuego.objects.get(pk=sesion_id)
    except SesionJuego.DoesNotExist:
        return Response({'error': 'Sesión no encontrada.'}, status=404)
    return Response(_sesion_dict(sesion, request.user))


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def resultados_sesion(request, sesion_id):
    try:
        sesion = SesionJuego.objects.get(pk=sesion_id)
    except SesionJuego.DoesNotExist:
        return Response({'error': 'Sesión no encontrada.'}, status=404)

    jugadores = sesion.jugadores.filter(activo=True).select_related('usuario').order_by('-puntos')
    return Response({
        'sesion_id':  sesion.id,
        'tipo_juego': sesion.get_tipo_juego_display(),
        'terminado':  sesion.estado == SesionJuego.Estado.TERMINADA,
        'ranking': [
            {
                'posicion': i + 1,
                'usuario':  {'id': j.usuario_id, 'nombre': j.usuario.nombre, 'foto': j.usuario.foto_url},
                'puntos':   j.puntos,
            }
            for i, j in enumerate(jugadores)
        ],
    })


# Endpoint interno: worker-ai actualiza contenido de ronda
@api_view(['PATCH'])
@permission_classes([])
def actualizar_ronda_ia(request, ronda_id):
    from django.conf import settings as conf
    if request.headers.get('X-Service-Token') != conf.SERVICE_TOKEN:
        return Response({'error': 'No autorizado.'}, status=403)

    try:
        ronda = RondaJuego.objects.get(pk=ronda_id)
    except RondaJuego.DoesNotExist:
        return Response({'error': 'Ronda no encontrada.'}, status=404)

    contenido = request.data.get('contenido', '')
    if contenido:
        ronda.contenido = contenido
        ronda.save(update_fields=['contenido'])

    return Response({'ok': True})
