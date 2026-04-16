import json
import logging
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.utils import timezone

logger = logging.getLogger(__name__)


class ChatConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        self.room_id    = self.scope['url_route']['kwargs']['room_id']
        self.room_group = f'chat_{self.room_id}'
        self.user       = self.scope['user']

        if not self.user or not self.user.is_authenticated:
            await self.close(code=4001)
            return
        if not await self._user_in_room():
            await self.close(code=4003)
            return

        await self.channel_layer.group_add(self.room_group, self.channel_name)
        await self.accept()
        await self._marcar_leidos()

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group'):
            await self.channel_layer.group_discard(self.room_group, self.channel_name)

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            return

        tipo = data.get('tipo', 'mensaje')

        if tipo == 'mensaje':
            contenido = data.get('contenido', '').strip()
            if not contenido or len(contenido) > 1000:
                return
            mensaje = await self._guardar_mensaje(contenido)
            await self.channel_layer.group_send(self.room_group, {
                'type':             'chat_message',
                'id':               mensaje.id,
                'contenido':        contenido,
                'remitente_id':     self.user.id,
                'remitente_nombre': self.user.nombre,
                'created_at':       mensaje.created_at.isoformat(),
            })
        elif tipo == 'typing':
            await self.channel_layer.group_send(self.room_group, {
                'type':           'user_typing',
                'usuario_id':     self.user.id,
                'usuario_nombre': self.user.nombre,
            })
        elif tipo == 'leido':
            await self._marcar_leidos()

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({
            'tipo':      'mensaje',
            'id':        event['id'],
            'contenido': event['contenido'],
            'remitente': {
                'id':     event['remitente_id'],
                'nombre': event['remitente_nombre'],
            },
            'created_at': event['created_at'],
        }))

    async def user_typing(self, event):
        if event['usuario_id'] != self.user.id:
            await self.send(text_data=json.dumps({
                'tipo':    'typing',
                'usuario': {
                    'id':     event['usuario_id'],
                    'nombre': event['usuario_nombre'],
                },
            }))

    @database_sync_to_async
    def _user_in_room(self) -> bool:
        from .models import Conversacion
        from django.db.models import Q
        return Conversacion.objects.filter(
            room_id=self.room_id
        ).filter(
            Q(usuario_1_id=self.user.id) | Q(usuario_2_id=self.user.id)
        ).exists()

    @database_sync_to_async
    def _guardar_mensaje(self, contenido: str):
        from .models import Conversacion, Mensaje
        conv = Conversacion.objects.get(room_id=self.room_id)
        msg  = Mensaje.objects.create(
            conversacion=conv,
            remitente=self.user,
            contenido=contenido,
        )
        Conversacion.objects.filter(pk=conv.pk).update(updated_at=timezone.now())
        return msg

    @database_sync_to_async
    def _marcar_leidos(self):
        from .models import Conversacion, Mensaje
        try:
            conv = Conversacion.objects.get(room_id=self.room_id)
            Mensaje.objects.filter(
                conversacion=conv, leido=False
            ).exclude(remitente=self.user).update(leido=True)
        except Conversacion.DoesNotExist:
            pass
