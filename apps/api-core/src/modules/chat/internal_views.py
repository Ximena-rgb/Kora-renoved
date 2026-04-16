"""
chat/internal_views.py
=======================
Endpoints internos llamados por worker-ai para inyectar mensajes.
Requieren X-Service-Token.
"""
import logging
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from django.conf import settings

logger = logging.getLogger(__name__)


@api_view(['POST'])
@permission_classes([AllowAny])
def inyectar_mensaje(request):
    """Inyecta un mensaje del asistente IA en una conversación de chat."""
    if request.headers.get('X-Service-Token') != settings.SERVICE_TOKEN:
        return Response({'error': 'No autorizado.'}, status=403)

    room_id = request.data.get('room_id', '')
    mensaje = request.data.get('mensaje', '')
    tipo    = request.data.get('tipo', 'ai_icebreaker')

    if not room_id or not mensaje:
        return Response({'error': 'room_id y mensaje son requeridos.'}, status=400)

    try:
        from .models import Conversacion, Mensaje
        from django.contrib.auth import get_user_model

        conv = Conversacion.objects.get(room_id=room_id)
        User = get_user_model()

        # El mensaje lo "envía" el primer superusuario disponible (representa la IA)
        # En producción se usaría un usuario sistema dedicado
        sistema = User.objects.filter(is_superuser=True).first()
        if not sistema:
            sistema = conv.usuario_1  # fallback

        msg = Mensaje.objects.create(
            conversacion = conv,
            remitente    = sistema,
            contenido    = mensaje,
            tipo         = tipo,
        )

        # Enviar por WebSocket al channel group
        from channels.layers import get_channel_layer
        from asgiref.sync import async_to_sync

        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(
            f'chat_{room_id}',
            {
                'type':             'chat_message',
                'id':               msg.id,
                'contenido':        mensaje,
                'remitente_id':     sistema.id,
                'remitente_nombre': '💜 Asistente Kora',
                'created_at':       msg.created_at.isoformat(),
                'es_ia':            True,
            },
        )
        logger.info(f'[Chat] ✅ Mensaje IA inyectado en room={room_id}')
        return Response({'ok': True, 'mensaje_id': msg.id})

    except Conversacion.DoesNotExist:
        return Response({'error': f'Conversación no encontrada: {room_id}'}, status=404)
    except Exception as exc:
        logger.error(f'[Chat] Error inyectando mensaje: {exc}')
        return Response({'error': str(exc)}, status=500)
