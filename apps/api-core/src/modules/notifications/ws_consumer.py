import json
import logging
from channels.generic.websocket import AsyncWebsocketConsumer

logger = logging.getLogger(__name__)


class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope['user']
        if not self.user or not self.user.is_authenticated:
            await self.close(code=4001)
            return
        self.group_name = f'notif_{self.user.id}'
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        logger.info(f'[Notif WS] {self.user.nombre} conectado')

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def push_notification(self, event):
        await self.send(text_data=json.dumps({
            'tipo':   'notificacion',
            'titulo': event['titulo'],
            'cuerpo': event['cuerpo'],
            'data':   event.get('data', {}),
        }))
