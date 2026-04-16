"""
Endpoint interno llamado por worker-ai y api-media.
Solo accesible con X-Service-Token (no JWT de usuario).
"""

import logging
from django.conf import settings
from rest_framework.decorators import api_view, permission_classes, authentication_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status

from modules.notifications.service import notificar_resultado_ai, enviar_notificacion_ws

logger = logging.getLogger(__name__)

SERVICE_TOKEN = getattr(settings, 'SERVICE_TOKEN', '')


def _verificar_service_token(request) -> bool:
    token = request.headers.get('X-Service-Token', '')
    return token == SERVICE_TOKEN and bool(SERVICE_TOKEN)


@api_view(['POST'])
@authentication_classes([])
@permission_classes([AllowAny])
def ai_resultado(request):
    """Recibe resultado de worker-ai y lo entrega por WebSocket al usuario."""
    if not _verificar_service_token(request):
        return Response({'error': 'No autorizado.'}, status=status.HTTP_403_FORBIDDEN)

    user_id    = request.data.get('user_id')
    tipo       = request.data.get('tipo')
    request_id = request.data.get('request_id', '')
    resultado  = request.data.get('resultado', '')

    if not all([user_id, tipo, resultado]):
        return Response({'error': 'Faltan campos requeridos.'}, status=status.HTTP_400_BAD_REQUEST)

    notificar_resultado_ai(user_id, tipo, request_id, resultado)
    return Response({'ok': True})


@api_view(['PATCH'])
@authentication_classes([])
@permission_classes([AllowAny])
def actualizar_foto_usuario(request, user_id):
    """Recibe URL procesada de api-media y actualiza foto_url del usuario."""
    if not _verificar_service_token(request):
        return Response({'error': 'No autorizado.'}, status=status.HTTP_403_FORBIDDEN)

    foto_url = request.data.get('foto_url', '')
    if not foto_url:
        return Response({'error': 'foto_url requerida.'}, status=status.HTTP_400_BAD_REQUEST)

    from modules.user.models import User
    try:
        user = User.objects.get(pk=user_id)
        user.foto_url = foto_url
        user.save(update_fields=['foto_url'])

        # Notificar al usuario que su foto fue procesada
        enviar_notificacion_ws(
            usuario_id = user_id,
            titulo     = '📸 Foto actualizada',
            cuerpo     = 'Tu foto de perfil fue procesada exitosamente.',
            data       = {'tipo': 'foto_actualizada', 'foto_url': foto_url},
        )
        return Response({'ok': True, 'foto_url': foto_url})
    except User.DoesNotExist:
        return Response({'error': 'Usuario no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
