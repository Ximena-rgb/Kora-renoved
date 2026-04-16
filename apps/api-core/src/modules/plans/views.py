"""
modules/plans/views.py — Planes y eventos con asistencia + check-in
"""
import logging
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from shared.audit import audit
from shared.broker import broker
from modules.notifications.service import enviar_notificacion_ws

from .models import Plan, Participante
from .serializers import (
    PlanListSerializer, PlanDetailSerializer,
    CreatePlanSerializer,
)

logger = logging.getLogger(__name__)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def planes_feed(request):
    """Feed de planes activos filtrable por tipo, zona, tag."""
    tipo = request.query_params.get('tipo')
    zona = request.query_params.get('zona')
    tag  = request.query_params.get('tag')

    qs = Plan.objects.filter(
        estado__in=[Plan.Estado.ACTIVO, Plan.Estado.EN_CURSO],
        hora_inicio__gte=timezone.now(),
        es_publico=True,
    ).select_related('creador__profile').prefetch_related('participantes')

    if tipo:  qs = qs.filter(tipo=tipo)
    if zona:  qs = qs.filter(campus_zona__icontains=zona)
    if tag:   qs = qs.filter(tags__contains=[tag])

    return Response(PlanListSerializer(qs[:40], many=True, context={'request': request}).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def crear_plan(request):
    s = CreatePlanSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    plan = s.save(creador=request.user)
    Participante.objects.create(plan=plan, usuario=request.user)
    audit.log(request, audit.PLAN_CREATED, {'plan_id': plan.id, 'tipo': plan.tipo})
    broker.publish('SYSTEM_ALERT', {
        'evento': 'plan_nuevo', 'plan_id': plan.id,
        'tipo': plan.tipo, 'titulo': plan.titulo,
        'zona': plan.campus_zona, 'tags': plan.tags,
        'creador_id': plan.creador.id,
    })
    return Response(PlanDetailSerializer(plan, context={'request': request}).data,
                    status=status.HTTP_201_CREATED)


@api_view(['GET', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def plan_detail(request, pk):
    try:
        plan = Plan.objects.select_related('creador').prefetch_related('participantes').get(pk=pk)
    except Plan.DoesNotExist:
        return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response(PlanDetailSerializer(plan, context={'request': request}).data)

    if plan.creador != request.user:
        return Response({'error': 'Solo el creador puede modificar este plan.'},
                        status=status.HTTP_403_FORBIDDEN)

    if request.method == 'PATCH':
        s = CreatePlanSerializer(plan, data=request.data, partial=True)
        s.is_valid(raise_exception=True)
        s.save()
        return Response(PlanDetailSerializer(plan, context={'request': request}).data)

    plan.estado = Plan.Estado.CANCELADO
    plan.save(update_fields=['estado'])
    return Response({'mensaje': 'Plan cancelado.'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def asistir(request, pk):
    """Confirmar asistencia a un plan."""
    try:
        plan = Plan.objects.get(pk=pk)
    except Plan.DoesNotExist:
        return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)

    puede, motivo = plan.puede_unirse(request.user)
    if not puede:
        return Response({'error': motivo}, status=status.HTTP_400_BAD_REQUEST)

    p, created = Participante.objects.get_or_create(
        plan=plan, usuario=request.user,
        defaults={'estado': Participante.Estado.CONFIRMADO},
    )
    if not created and p.estado == 'cancelado':
        p.estado = Participante.Estado.CONFIRMADO
        p.save(update_fields=['estado'])

    # Notificar al creador
    if plan.creador != request.user:
        enviar_notificacion_ws(
            plan.creador.id,
            '🎉 Nuevo asistente',
            f'{request.user.nombre} confirmó asistencia a "{plan.titulo}"',
            {'tipo': 'nuevo_asistente', 'plan_id': plan.id},
        )

    audit.log(request, audit.PLAN_JOINED, {'plan_id': plan.id})
    return Response(PlanDetailSerializer(plan, context={'request': request}).data)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cancelar_asistencia(request, pk):
    """Cancelar asistencia confirmada."""
    try:
        p = Participante.objects.get(plan_id=pk, usuario=request.user)
    except Participante.DoesNotExist:
        return Response({'error': 'No estás asistiendo a este plan.'}, status=status.HTTP_400_BAD_REQUEST)

    if p.plan.creador == request.user:
        return Response({'error': 'El creador no puede cancelar su asistencia. Cancela el plan.'}, status=status.HTTP_400_BAD_REQUEST)

    p.estado = Participante.Estado.CANCELADO
    p.save(update_fields=['estado'])
    audit.log(request, audit.PLAN_LEFT, {'plan_id': pk})
    return Response({'mensaje': 'Asistencia cancelada.'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def checkin(request, pk):
    """
    Check-in al plan. Ventana: 15 min antes hasta 30 min después.
    Registra puntualidad y actualiza score de reputación.
    """
    try:
        plan = Plan.objects.get(pk=pk)
    except Plan.DoesNotExist:
        return Response({'error': 'Plan no encontrado.'}, status=status.HTTP_404_NOT_FOUND)

    if not plan.puede_checkin:
        return Response({
            'error': 'El check-in solo está disponible 15 minutos antes y hasta 30 minutos después del inicio.',
            'hora_inicio': plan.hora_inicio,
        }, status=status.HTTP_400_BAD_REQUEST)

    try:
        p = Participante.objects.get(plan=plan, usuario=request.user)
    except Participante.DoesNotExist:
        return Response({'error': 'No confirmaste asistencia a este plan.'}, status=status.HTTP_400_BAD_REQUEST)

    if p.estado == Participante.Estado.ASISTIO:
        return Response({'error': 'Ya hiciste check-in en este plan.'}, status=status.HTTP_400_BAD_REQUEST)

    from modules.reputation.models import registrar_checkin
    registrar_checkin(p)

    return Response({
        'mensaje':    '✅ Check-in registrado!',
        'puntual':    p.fue_puntual,
        'delta_min':  p.delta_puntualidad,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def mis_planes(request):
    """Planes creados y a los que asisto."""
    creados = Plan.objects.filter(creador=request.user).prefetch_related('participantes')
    asistiendo = Plan.objects.filter(
        participantes__usuario=request.user,
        participantes__estado__in=['confirmado', 'asistio'],
    ).exclude(creador=request.user).prefetch_related('participantes')

    return Response({
        'creados':    PlanListSerializer(creados, many=True, context={'request': request}).data,
        'asistiendo': PlanListSerializer(asistiendo, many=True, context={'request': request}).data,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def pendientes_calificar(request):
    """Planes pasados donde no has calificado a todos los asistentes."""
    from modules.reputation.models import Calificacion
    ahora = timezone.now()

    mis_planes_pasados = Plan.objects.filter(
        participantes__usuario=request.user,
        participantes__estado='asistio',
        hora_inicio__lt=ahora,
    ).prefetch_related('participantes__usuario')

    pendientes = []
    for plan in mis_planes_pasados:
        ya_califique = set(
            Calificacion.objects.filter(de_usuario=request.user, plan=plan)
            .values_list('a_usuario_id', flat=True)
        )
        sin_calificar = [
            p.usuario for p in plan.participantes.filter(estado='asistio')
            if p.usuario != request.user and p.usuario_id not in ya_califique
        ]
        if sin_calificar:
            pendientes.append({
                'plan_id':    plan.id,
                'plan_titulo': plan.titulo,
                'plan_hora':  plan.hora_inicio,
                'sin_calificar': [
                    {'id': u.id, 'nombre': u.nombre, 'foto_url': u.foto_url}
                    for u in sin_calificar
                ],
            })
    return Response(pendientes)
