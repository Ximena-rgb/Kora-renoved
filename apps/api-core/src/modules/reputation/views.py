"""
modules/reputation/views.py — Sistema de confianza
"""
from rest_framework import serializers, status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.contrib.auth import get_user_model

from .models import (Calificacion, ScoreConfianza,
                     EventoReputacion, Insignia)

User = get_user_model()


class CalificacionInputSerializer(serializers.Serializer):
    a_usuario_id = serializers.IntegerField()
    plan_id      = serializers.IntegerField()
    nota         = serializers.IntegerField(min_value=1, max_value=5)
    comentario   = serializers.CharField(max_length=200, required=False, default='')


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def calificar(request):
    s = CalificacionInputSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    data = s.validated_data

    if data['a_usuario_id'] == request.user.id:
        return Response({'error': 'No puedes calificarte a ti mismo.'}, status=400)

    try:
        a_usuario = User.objects.get(pk=data['a_usuario_id'])
    except User.DoesNotExist:
        return Response({'error': 'Usuario no encontrado.'}, status=404)

    from modules.plans.models import Plan, Participante
    try:
        plan = Plan.objects.get(pk=data['plan_id'])
    except Plan.DoesNotExist:
        return Response({'error': 'Plan no encontrado.'}, status=404)

    # Verificar que ambos asistieron
    ids_asistentes = set(
        Participante.objects.filter(plan=plan, estado='asistio')
        .values_list('usuario_id', flat=True)
    )
    if request.user.id not in ids_asistentes:
        return Response({'error': 'Solo puedes calificar si asististe al plan.'}, status=403)
    if a_usuario.id not in ids_asistentes:
        return Response({'error': 'Este usuario no asistió al plan.'}, status=400)

    if Calificacion.objects.filter(de_usuario=request.user, a_usuario=a_usuario, plan=plan).exists():
        return Response({'error': 'Ya calificaste a este usuario en este plan.'}, status=400)

    Calificacion.objects.create(
        de_usuario=request.user, a_usuario=a_usuario,
        plan=plan, nota=data['nota'], comentario=data.get('comentario', ''),
    )

    # Bono al calificador por participar
    EventoReputacion.objects.create(
        usuario=request.user,
        tipo=EventoReputacion.TipoEvento.CALIFICO_OTROS,
        descripcion=f'Calificó a {a_usuario.nombre}',
        delta=1.0, plan=plan,
    )

    score = ScoreConfianza.objects.filter(user=a_usuario).first()
    return Response({
        'mensaje':    f'Calificaste a {a_usuario.nombre} con {data["nota"]}★',
        'score_actual': round(score.score_total, 1) if score else None,
    }, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def mi_score(request):
    """Score de confianza y desglose del usuario autenticado."""
    score, _ = ScoreConfianza.objects.get_or_create(user=request.user)
    insignias = Insignia.objects.filter(usuario=request.user)
    historial = EventoReputacion.objects.filter(usuario=request.user)[:20]

    return Response({
        'score_total':        round(score.score_total, 1),
        'score_calificacion': round(score.score_calificacion, 1),
        'score_puntualidad':  round(score.score_puntualidad, 1),
        'score_asistencia':   round(score.score_asistencia, 1),
        'planes_asistidos':   score.planes_asistidos,
        'checkins_puntuales': score.checkins_puntuales,
        'calificacion_promedio': (
            round(score.suma_calificaciones / score.calificaciones_recibidas, 2)
            if score.calificaciones_recibidas > 0 else None
        ),
        'insignias': [
            {'codigo': i.codigo, **i.info, 'obtenida_en': i.obtenida_en}
            for i in insignias
        ],
        'historial': [
            {'tipo': e.tipo, 'descripcion': e.descripcion,
             'delta': e.delta, 'fecha': e.created_at}
            for e in historial
        ],
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def score_usuario(request, user_id):
    """Score público de otro usuario."""
    try:
        usuario = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({'error': 'Usuario no encontrado.'}, status=404)

    score = ScoreConfianza.objects.filter(user=usuario).first()
    insignias = Insignia.objects.filter(usuario=usuario)

    return Response({
        'usuario_id':   usuario.id,
        'nombre':       usuario.nombre,
        'score_total':  round(score.score_total, 1) if score else 50.0,
        'insignias':    [{'codigo': i.codigo, **i.info} for i in insignias],
        'calificacion_promedio': (
            round(score.suma_calificaciones / score.calificaciones_recibidas, 2)
            if score and score.calificaciones_recibidas > 0 else None
        ),
    })
