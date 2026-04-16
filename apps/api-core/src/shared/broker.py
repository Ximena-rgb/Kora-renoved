"""
shared/broker.py
================
Cliente centralizado para Redis Streams (Message Broker).

Uso desde cualquier módulo:
    from shared.broker import broker
    broker.publish('USER_REGISTERED', {'user_id': 42, 'email': 'x@uni.edu.co'})

Para workers consumidores (api-media, worker-ai):
    for event in broker.consume('IMAGE_PROCESS_TASK', 'grp-api-media', 'worker-1'):
        process(event)
"""

import json
import logging
import time
import redis

from django.conf import settings

logger = logging.getLogger(__name__)


class RedisStreamsBroker:
    """
    Publicador / consumidor sobre Redis Streams.
    - publish()  → XADD (fire-and-forget desde api-core)
    - consume()  → XREADGROUP (workers en api-media / worker-ai)
    - ack()      → XACK (confirmar procesamiento)
    """

    def __init__(self):
        self._client: redis.Redis | None = None

    @property
    def client(self) -> redis.Redis:
        if self._client is None:
            self._client = redis.from_url(
                settings.REDIS_URL,
                decode_responses=True,
                socket_connect_timeout=5,
                socket_timeout=5,
                retry_on_timeout=True,
            )
        return self._client

    # ── Publicar evento ───────────────────────────────────────────
    def publish(self, event_name: str, payload: dict, maxlen: int = 5000) -> str | None:
        """
        Publica un evento en el stream correspondiente.
        Devuelve el message-id de Redis o None si falla.

        event_name: clave de REDIS_STREAMS en settings.py
                    ej: 'USER_REGISTERED', 'IMAGE_PROCESS_TASK'
        """
        stream = settings.REDIS_STREAMS.get(event_name)
        if not stream:
            logger.error(f'[Broker] Stream desconocido: {event_name}')
            return None

        try:
            msg_id = self.client.xadd(
                stream,
                {'payload': json.dumps(payload, default=str)},
                maxlen=maxlen,
                approximate=True,
            )
            logger.debug(f'[Broker] Publicado {event_name} → {stream} id={msg_id}')
            return msg_id
        except Exception as exc:
            logger.error(f'[Broker] Error publicando {event_name}: {exc}')
            return None

    # ── Asegurar consumer group ───────────────────────────────────
    def ensure_group(self, stream: str, group: str) -> None:
        """Crea el consumer group si no existe."""
        try:
            self.client.xgroup_create(stream, group, id='0', mkstream=True)
        except redis.exceptions.ResponseError as e:
            if 'BUSYGROUP' not in str(e):
                raise

    # ── Consumir eventos (bloqueante) ─────────────────────────────
    def consume(
        self,
        event_name: str,
        group: str,
        consumer: str,
        block_ms: int = 2000,
        count: int = 10,
    ):
        """
        Generador bloqueante. Itera mensajes nuevos del stream.
        Uso típico en un management command o worker loop:

            for msg_id, data in broker.consume('IMAGE_PROCESS_TASK', 'grp-api-media', 'w-1'):
                process(json.loads(data['payload']))
                broker.ack('IMAGE_PROCESS_TASK', 'grp-api-media', msg_id)
        """
        stream = settings.REDIS_STREAMS.get(event_name)
        if not stream:
            raise ValueError(f'Stream desconocido: {event_name}')

        self.ensure_group(stream, group)

        while True:
            try:
                results = self.client.xreadgroup(
                    group, consumer,
                    {stream: '>'},
                    count=count,
                    block=block_ms,
                )
                if not results:
                    continue
                for _stream, messages in results:
                    for msg_id, data in messages:
                        yield msg_id, data
            except redis.exceptions.ConnectionError:
                logger.warning('[Broker] Conexión perdida, reintentando en 3s…')
                time.sleep(3)
            except Exception as exc:
                logger.error(f'[Broker] Error consumiendo {event_name}: {exc}')
                time.sleep(1)

    # ── Acknowledge ───────────────────────────────────────────────
    def ack(self, event_name: str, group: str, msg_id: str) -> None:
        stream = settings.REDIS_STREAMS.get(event_name)
        if stream:
            try:
                self.client.xack(stream, group, msg_id)
            except Exception as exc:
                logger.error(f'[Broker] Error en ACK {msg_id}: {exc}')

    # ── Health check ──────────────────────────────────────────────
    def ping(self) -> bool:
        try:
            return self.client.ping()
        except Exception:
            return False


# Singleton — importar esto desde los módulos
broker = RedisStreamsBroker()
