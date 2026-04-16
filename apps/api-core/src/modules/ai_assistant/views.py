"""
modules/ai_assistant/views.py
==============================
AI Love Assistant Module — Endpoints

POST /api/v1/ai/icebreaker/   → Genera un icebreaker para un match
POST /api/v1/ai/coach/        → Solicita consejo de Date Coach

Ambos endpoints publican AI_COACH_REQUEST al Redis Stream.
El worker-ai lo consume, llama a Gemini/GPT y devuelve el resultado
vía notificación WebSocket al usuario.
"""

import logging
import uuid
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from shared.audit import audit
from shared.broker import broker

logger = logging.getLogger(__name__)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def generar_icebreaker(request):
    """
    Genera un icebreaker personalizado para un match.

    Body: { "match_id": 42 }

    Flujo:
      1. Valida que el match pertenezca al usuario
      2. Publica AI_COACH_REQUEST → worker-ai
      3. worker-ai llama Gemini y devuelve resultado por WS
    """
    match_id = request.data.get('match_id')
    if not match_id:
        return Response({'error': 'match_id requerido.'}, status=status.HTTP_400_BAD_REQUEST)

    # Validar que el match pertenece al usuario
    from modules.matching.models import Match
    from django.db.models import Q
    try:
        match = Match.objects.select_related('usuario_1', 'usuario_2').get(
            Q(usuario_1=request.user) | Q(usuario_2=request.user),
            pk=match_id,
        )
    except Match.DoesNotExist:
        return Response({'error': 'Match no encontrado.'}, status=status.HTTP_404_NOT_FOUND)

    otro = match.usuario_2 if match.usuario_1 == request.user else match.usuario_1

    request_id = str(uuid.uuid4())

    broker.publish('AI_COACH_REQUEST', {
        'request_id':    request_id,
        'tipo':          'icebreaker',
        'solicitante_id': request.user.id,
        'contexto': {
            'match_id':            match.id,
            'intereses_mios':      request.user.intereses,
            'intereses_otro':      otro.intereses,
            'carrera_mia':         request.user.carrera,
            'carrera_otro':        otro.carrera,
            'score':               match.score,
        },
    })

    audit.log(request, audit.AI_COACH_REQUEST, {'tipo': 'icebreaker', 'match_id': match_id})

    return Response({
        'mensaje':    'Generando icebreaker… recibirás el resultado por notificación.',
        'request_id': request_id,
    }, status=status.HTTP_202_ACCEPTED)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def date_coach(request):
    """
    Solicita un consejo del Date Coach.

    Body: {
        "match_id": 42,
        "pregunta": "¿Qué plan le puedo proponer?"
    }
    """
    match_id  = request.data.get('match_id')
    pregunta  = request.data.get('pregunta', '').strip()

    if not match_id or not pregunta:
        return Response({'error': 'match_id y pregunta son requeridos.'}, status=status.HTTP_400_BAD_REQUEST)

    if len(pregunta) > 300:
        return Response({'error': 'La pregunta no puede superar 300 caracteres.'}, status=status.HTTP_400_BAD_REQUEST)

    from modules.matching.models import Match
    from django.db.models import Q
    try:
        match = Match.objects.get(
            Q(usuario_1=request.user) | Q(usuario_2=request.user),
            pk=match_id,
        )
    except Match.DoesNotExist:
        return Response({'error': 'Match no encontrado.'}, status=status.HTTP_404_NOT_FOUND)

    otro = match.usuario_2 if match.usuario_1 == request.user else match.usuario_1

    request_id = str(uuid.uuid4())

    broker.publish('AI_COACH_REQUEST', {
        'request_id':    request_id,
        'tipo':          'date_coach',
        'solicitante_id': request.user.id,
        'contexto': {
            'match_id':       match.id,
            'pregunta':       pregunta,
            'intereses_mios': request.user.intereses,
            'intereses_otro': otro.intereses,
            'carrera_mia':    request.user.carrera,
            'carrera_otro':   otro.carrera,
        },
    })

    audit.log(request, audit.AI_COACH_REQUEST, {'tipo': 'date_coach', 'match_id': match_id})

    return Response({
        'mensaje':    'Consultando al Date Coach… recibirás el consejo por notificación.',
        'request_id': request_id,
    }, status=status.HTTP_202_ACCEPTED)
