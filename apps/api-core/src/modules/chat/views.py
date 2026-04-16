from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.contrib.auth import get_user_model
from .models import Conversacion, Mensaje

User = get_user_model()


def _serialize_mensaje(msg):
    return {
        'id':        msg.id,
        'contenido': msg.contenido,
        'leido':     msg.leido,
        'created_at': msg.created_at.isoformat(),
        'remitente': {
            'id':     msg.remitente_id,
            'nombre': msg.remitente.nombre,
        },
    }


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def conversaciones(request):
    if request.method == 'GET':
        from django.db.models import Q
        convs = Conversacion.objects.filter(
            Q(usuario_1=request.user) | Q(usuario_2=request.user)
        ).select_related('usuario_1', 'usuario_2').order_by('-updated_at')

        resultados = []
        for c in convs:
            otro   = c.usuario_2 if c.usuario_1 == request.user else c.usuario_1
            ultimo = c.mensajes.order_by('-created_at').first()
            resultados.append({
                'room_id':        c.room_id,
                'otro_usuario':   {
                    'id':       otro.id,
                    'nombre':   otro.nombre,
                    'foto_url': otro.foto_url,
                },
                'ultimo_mensaje': _serialize_mensaje(ultimo) if ultimo else None,
                'updated_at':     c.updated_at.isoformat(),
            })
        return Response(resultados)

    # POST — crear/obtener conversación
    otro_id = request.data.get('usuario_id')
    if not otro_id:
        return Response({'error': 'usuario_id requerido.'}, status=status.HTTP_400_BAD_REQUEST)

    try:
        otro = User.objects.get(pk=otro_id, is_active=True)
    except User.DoesNotExist:
        return Response({'error': 'Usuario no encontrado.'}, status=status.HTTP_404_NOT_FOUND)

    if otro == request.user:
        return Response({'error': 'No puedes chatear contigo mismo.'}, status=status.HTTP_400_BAD_REQUEST)

    room_id = Conversacion.get_or_create_room_id(request.user.id, otro.id)
    u1, u2  = (request.user, otro) if request.user.id < otro.id else (otro, request.user)
    conv, _ = Conversacion.objects.get_or_create(
        room_id=room_id,
        defaults={'usuario_1': u1, 'usuario_2': u2},
    )
    return Response({
        'room_id':      conv.room_id,
        'otro_usuario': {'id': otro.id, 'nombre': otro.nombre, 'foto_url': otro.foto_url},
        'created_at':   conv.created_at.isoformat(),
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def historial_mensajes(request, room_id):
    try:
        conv = Conversacion.objects.get(room_id=room_id)
    except Conversacion.DoesNotExist:
        return Response({'error': 'Conversación no encontrada.'}, status=status.HTTP_404_NOT_FOUND)

    if request.user not in (conv.usuario_1, conv.usuario_2):
        return Response({'error': 'Sin acceso.'}, status=status.HTTP_403_FORBIDDEN)

    mensajes = conv.mensajes.select_related('remitente').order_by('-created_at')[:50]
    return Response([_serialize_mensaje(m) for m in reversed(list(mensajes))])
