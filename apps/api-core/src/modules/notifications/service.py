"""
modules/notifications/service.py
==================================
Servicio central de notificaciones WS.
"""
import logging
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

logger = logging.getLogger(__name__)


def enviar_notificacion_ws(usuario_id: int, titulo: str, cuerpo: str, data: dict = None) -> bool:
    channel_layer = get_channel_layer()
    group_name    = f'notif_{usuario_id}'
    try:
        async_to_sync(channel_layer.group_send)(
            group_name,
            {'type': 'push_notification', 'titulo': titulo, 'cuerpo': cuerpo, 'data': data or {}},
        )
        return True
    except Exception as exc:
        logger.error(f'[Notif] Error WS usuario {usuario_id}: {exc}')
        return False


def notificar_match_nuevo(match_id: int, usuario_1_id: int, usuario_2_id: int, score: float):
    from django.contrib.auth import get_user_model
    User = get_user_model()
    try:
        u1 = User.objects.get(pk=usuario_1_id)
        u2 = User.objects.get(pk=usuario_2_id)
    except User.DoesNotExist:
        return
    enviar_notificacion_ws(u1.id, '¡Nuevo match! 💘', f'Hiciste match con {u2.nombre}',
                           {'tipo': 'match_nuevo', 'match_id': str(match_id), 'usuario_id': str(u2.id)})
    enviar_notificacion_ws(u2.id, '¡Nuevo match! 💘', f'Hiciste match con {u1.nombre}',
                           {'tipo': 'match_nuevo', 'match_id': str(match_id), 'usuario_id': str(u1.id)})


def notificar_plan_nuevo(plan_id: int, titulo_plan: str, zona: str, tags: list, creador_id: int):
    from django.contrib.auth import get_user_model
    User = get_user_model()
    candidatos = User.objects.filter(disponible=True, is_active=True).exclude(id=creador_id)
    if zona:
        candidatos = candidatos.filter(campus_zona__icontains=zona)
    tags_set = set(tags)
    for usuario in candidatos[:100]:
        if tags_set & set(usuario.intereses) or not tags_set:
            enviar_notificacion_ws(
                usuario.id, '¡Nuevo plan cerca! 🎯',
                f'{titulo_plan} — {zona or "Campus"}',
                {'tipo': 'plan_nuevo', 'plan_id': str(plan_id)},
            )


def notificar_resultado_ai(usuario_id: int, tipo: str, request_id: str, resultado: str):
    titulos = {'icebreaker': '🧊 Tu icebreaker está listo', 'date_coach': '💬 Consejo de tu Date Coach'}
    enviar_notificacion_ws(
        usuario_id,
        titulos.get(tipo, 'Resultado AI'),
        resultado[:100] + ('…' if len(resultado) > 100 else ''),
        {'tipo': f'ai_{tipo}', 'request_id': request_id, 'resultado': resultado},
    )
