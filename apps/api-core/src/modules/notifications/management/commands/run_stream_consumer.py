"""
run_stream_consumer.py
========================
Consume Redis Streams y despacha notificaciones WS + actualiza rondas de juego.
"""
import json
import logging
import threading
from django.core.management.base import BaseCommand
from shared.broker import broker
from modules.notifications import service as notif_service

logger = logging.getLogger(__name__)

STREAMS = [
    ('MATCH_CREATED',   'grp-notifications', 'notif-w-1'),
    ('SYSTEM_ALERT',    'grp-notifications', 'notif-w-1'),
    ('AI_GAME_REQUEST', 'grp-notifications', 'notif-w-1'),
]


class Command(BaseCommand):
    help = 'Consume Redis Streams y despacha notificaciones WebSocket'

    def handle(self, *args, **options):
        self.stdout.write('[StreamConsumer] Iniciando...')
        threads = []
        for event_name, group, consumer in STREAMS:
            t = threading.Thread(
                target=self._consume,
                args=(event_name, group, consumer),
                daemon=True,
            )
            t.start()
            threads.append(t)
        for t in threads:
            t.join()

    def _consume(self, event_name, group, consumer):
        self.stdout.write(f'[StreamConsumer] Escuchando {event_name}...')
        for msg_id, raw in broker.consume(event_name, group, consumer):
            try:
                payload = json.loads(raw.get('payload', '{}'))
                self._dispatch(event_name, payload)
                broker.ack(event_name, group, msg_id)
            except Exception as exc:
                logger.error(f'[StreamConsumer] Error {event_name} {msg_id}: {exc}')

    def _dispatch(self, event_name, payload):
        if event_name == 'MATCH_CREATED':
            notif_service.notificar_match_nuevo(
                match_id     = payload.get('match_id'),
                usuario_1_id = payload.get('usuario_1'),
                usuario_2_id = payload.get('usuario_2'),
                score        = payload.get('score', 0),
            )
        elif event_name == 'SYSTEM_ALERT':
            if payload.get('evento') == 'plan_nuevo':
                notif_service.notificar_plan_nuevo(
                    plan_id     = payload.get('plan_id'),
                    titulo_plan = payload.get('titulo', ''),
                    zona        = payload.get('zona', ''),
                    tags        = payload.get('tags', []),
                    creador_id  = payload.get('creador_id'),
                )
        elif event_name == 'AI_GAME_REQUEST':
            # El worker-ai maneja esto directamente
            # Aquí solo lo loguemos como confirmación
            logger.debug(f'[StreamConsumer] AI_GAME_REQUEST recibido (lo procesa worker-ai)')
