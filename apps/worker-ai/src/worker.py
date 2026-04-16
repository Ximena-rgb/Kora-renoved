"""
apps/worker-ai/src/worker.py
=============================
Worker AI — Asistente del Amor + Modo Desparche.

Streams escuchados:
  - AI_COACH_REQUEST  → icebreaker, date_coach
  - AI_GAME_REQUEST   → verdad_o_reto, quien_mas_probable
"""

import json
import logging
import os
import sys
import time

import requests
import redis
from prometheus_client import Counter, Histogram, start_http_server

from ollama_client import (
    generar_icebreaker, generar_consejo_coach,
    generar_verdad_o_reto, generar_quien_es_mas_probable,
)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(name)s %(message)s',
)
logger = logging.getLogger('worker-ai')

REDIS_URL         = os.getenv('REDIS_URL',    'redis://redis:6379/0')
API_CORE_URL      = os.getenv('API_CORE_INTERNAL_URL', 'http://api-core:8000')
SERVICE_TOKEN     = os.getenv('SERVICE_TOKEN', '')
PROMETHEUS_PORT   = int(os.getenv('PROMETHEUS_PORT', '9104'))
CONSUMER_GROUP    = 'grp-worker-ai'
CONSUMER_NAME     = f'ai-worker-{os.getpid()}'

STREAMS = {
    'AI_COACH_REQUEST': 'stream:ai.coach_request',
    'AI_GAME_REQUEST':  'stream:ai.game_request',
}

ai_requests   = Counter('ai_requests_total', 'Total requests procesados', ['tipo', 'status'])
ai_latency    = Histogram('ai_request_seconds', 'Latencia de respuesta AI', ['tipo'])


def get_redis() -> redis.Redis:
    while True:
        try:
            r = redis.from_url(REDIS_URL, decode_responses=True, socket_connect_timeout=5)
            r.ping()
            logger.info('[Worker-AI] ✅ Conectado a Redis')
            return r
        except Exception as e:
            logger.warning(f'[Worker-AI] Redis no disponible: {e} — reintentando en 3s')
            time.sleep(3)


def ensure_groups(r: redis.Redis):
    for name, stream in STREAMS.items():
        try:
            r.xgroup_create(stream, CONSUMER_GROUP, id='0', mkstream=True)
        except redis.exceptions.ResponseError as e:
            if 'BUSYGROUP' not in str(e):
                raise


def notificar_resultado(user_id: int, resultado: str, tipo: str, extra: dict = None):
    """Envía el resultado al api-core para que lo reenvíe por WebSocket al usuario."""
    try:
        requests.post(
            f'{API_CORE_URL}/api/v1/internal/ai/resultado/',
            json={
                'user_id':   user_id,
                'tipo':      tipo,
                'resultado': resultado,
                'extra':     extra or {},
            },
            headers={'X-Service-Token': SERVICE_TOKEN},
            timeout=10,
        )
    except Exception as exc:
        logger.error(f'[Worker-AI] Error notificando resultado: {exc}')


def inyectar_en_chat(room_id: str, mensaje: str, tipo: str = 'ai_icebreaker'):
    """Inyecta un mensaje del asistente directamente en una conversación."""
    try:
        requests.post(
            f'{API_CORE_URL}/api/v1/internal/chat/inyectar/',
            json={
                'room_id':  room_id,
                'mensaje':  mensaje,
                'tipo':     tipo,
            },
            headers={'X-Service-Token': SERVICE_TOKEN},
            timeout=10,
        )
        logger.info(f'[Worker-AI] Icebreaker inyectado en room={room_id}')
    except Exception as exc:
        logger.error(f'[Worker-AI] Error inyectando en chat: {exc}')


def procesar_coach_request(payload: dict):
    tipo     = payload.get('tipo', 'icebreaker')
    user_id  = payload.get('user_id')
    contexto = payload.get('contexto', {})
    room_id  = payload.get('room_id')

    with ai_latency.labels(tipo).time():
        if tipo == 'icebreaker':
            resultado = generar_icebreaker(contexto)
            # Inyectar como primer mensaje en el chat si hay room_id
            if room_id:
                inyectar_en_chat(room_id, resultado, tipo='ai_icebreaker')
            else:
                notificar_resultado(user_id, resultado, tipo)
        elif tipo == 'date_coach':
            resultado = generar_consejo_coach(contexto)
            notificar_resultado(user_id, resultado, tipo)
        else:
            logger.warning(f'[Worker-AI] Tipo desconocido: {tipo}')
            return

    ai_requests.labels(tipo=tipo, status='ok').inc()
    logger.info(f'[Worker-AI] ✅ {tipo} user={user_id}')


def procesar_game_request(payload: dict):
    tipo_juego = payload.get('tipo_juego', 'verdad')
    room_id    = payload.get('room_id')
    tema       = payload.get('tema', '')

    with ai_latency.labels(tipo_juego).time():
        if tipo_juego in ('verdad', 'reto'):
            resultado = generar_verdad_o_reto(tipo_juego, tema)
            contenido = resultado['contenido']
        elif tipo_juego == 'quien_mas_probable':
            contenido = generar_quien_es_mas_probable(tema)
        else:
            logger.warning(f'[Worker-AI] Juego desconocido: {tipo_juego}')
            return

    if room_id:
        inyectar_en_chat(room_id, contenido, tipo=f'game_{tipo_juego}')

    ai_requests.labels(tipo=tipo_juego, status='ok').inc()
    logger.info(f'[Worker-AI] ✅ juego={tipo_juego} room={room_id}')


def main():
    logger.info('🤖 worker-ai arrancando con Ollama...')

    try:
        start_http_server(PROMETHEUS_PORT)
    except Exception:
        pass

    r = get_redis()
    ensure_groups(r)

    streams_map = {v: '>' for v in STREAMS.values()}
    logger.info(f'[Worker-AI] Escuchando: {list(STREAMS.values())}')

    while True:
        try:
            results = r.xreadgroup(
                CONSUMER_GROUP, CONSUMER_NAME,
                streams_map,
                count=3, block=2000,
            )
            if not results:
                continue

            for stream_name, messages in results:
                for msg_id, data in messages:
                    try:
                        payload = json.loads(data.get('payload', '{}'))

                        if stream_name == STREAMS['AI_COACH_REQUEST']:
                            procesar_coach_request(payload)
                        elif stream_name == STREAMS['AI_GAME_REQUEST']:
                            procesar_game_request(payload)

                        r.xack(stream_name, CONSUMER_GROUP, msg_id)
                    except Exception as exc:
                        logger.error(f'[Worker-AI] Error {msg_id}: {exc}', exc_info=True)
                        ai_requests.labels(tipo='unknown', status='error').inc()

        except redis.exceptions.ConnectionError:
            logger.warning('[Worker-AI] Reconectando Redis…')
            r = get_redis()
        except KeyboardInterrupt:
            logger.info('[Worker-AI] Deteniendo…')
            sys.exit(0)


if __name__ == '__main__':
    main()
