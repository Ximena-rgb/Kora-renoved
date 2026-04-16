"""
apps/api-media/src/worker.py
Worker de imágenes — consume IMAGE_PROCESS_TASK del broker.
"""
import json
import logging
import os
import sys
import time

import redis
from prometheus_client import Counter, Histogram, start_http_server

from processors.image_processor import ImageProcessor, ValidationError
from storage.updater import notificar_foto_procesada

logging.basicConfig(level=logging.INFO,
    format='%(asctime)s %(levelname)s %(name)s %(message)s')
logger = logging.getLogger('api-media')

REDIS_URL      = os.getenv('REDIS_URL',   'redis://redis:6379/0')
STORAGE_ROOT   = os.getenv('MEDIA_ROOT',  '/storage/uploads')
STREAM_NAME    = 'stream:image.process_task'
CONSUMER_GROUP = 'grp-api-media'
CONSUMER_NAME  = f'media-{os.getpid()}'
PROM_PORT      = int(os.getenv('PROMETHEUS_PORT', '9102'))

images_ok       = Counter('media_ok_total',       'Imágenes procesadas OK')
images_rejected = Counter('media_rejected_total',  'Imágenes rechazadas')
images_error    = Counter('media_error_total',     'Errores de procesamiento')
proc_time       = Histogram('media_seconds',       'Tiempo de procesamiento')


def get_redis():
    while True:
        try:
            r = redis.from_url(REDIS_URL, decode_responses=True,
                               socket_connect_timeout=5)
            r.ping()
            logger.info('[Worker] ✅ Redis conectado')
            return r
        except Exception as e:
            logger.warning(f'[Worker] Redis no disponible: {e}')
            time.sleep(3)


def ensure_group(r):
    try:
        r.xgroup_create(STREAM_NAME, CONSUMER_GROUP, id='0', mkstream=True)
    except redis.exceptions.ResponseError as e:
        if 'BUSYGROUP' not in str(e):
            raise


def process_message(processor: ImageProcessor, payload: dict):
    foto_id        = payload.get('foto_id')
    user_id        = payload.get('user_id')
    tipo           = payload.get('tipo', 'profile')
    tmp_path       = payload.get('tmp_path', '')
    filename       = payload.get('filename', '')
    # Género del usuario para validar coincidencia
    genero_usuario = payload.get('genero_usuario', '')

    if not tmp_path or not filename:
        raise ValueError('Payload incompleto')

    with proc_time.time():
        result = processor.process(
            tmp_path, user_id, tipo, filename,
            genero_usuario=genero_usuario,
        )

    if foto_id:
        notificar_foto_procesada(foto_id, 'approved', result['urls'])

    images_ok.inc()
    logger.info(f'[Worker] ✅ foto={foto_id} user={user_id}')


def main():
    logger.info('🚀 api-media worker con validación de imagen completa')
    try:
        start_http_server(PROM_PORT)
    except Exception:
        pass

    r         = get_redis()
    processor = ImageProcessor(storage_root=STORAGE_ROOT)
    ensure_group(r)

    logger.info(f'[Worker] Escuchando {STREAM_NAME}…')

    while True:
        try:
            results = r.xreadgroup(CONSUMER_GROUP, CONSUMER_NAME,
                                   {STREAM_NAME: '>'}, count=5, block=2000)
            if not results:
                continue

            for _stream, messages in results:
                for msg_id, data in messages:
                    raw = data.get('payload', '{}')
                    try:
                        payload = json.loads(raw)
                        process_message(processor, payload)
                        r.xack(STREAM_NAME, CONSUMER_GROUP, msg_id)

                    except ValidationError as exc:
                        foto_id = json.loads(raw).get('foto_id')
                        logger.warning(f'[Worker] ⚠️ Rechazada foto={foto_id}: {exc}')
                        if foto_id:
                            notificar_foto_procesada(foto_id, 'rejected',
                                                     motivo=str(exc))
                        images_rejected.inc()
                        r.xack(STREAM_NAME, CONSUMER_GROUP, msg_id)

                    except Exception as exc:
                        logger.error(f'[Worker] Error {msg_id}: {exc}', exc_info=True)
                        images_error.inc()
                        # No ACK → reintentará

        except redis.exceptions.ConnectionError:
            logger.warning('[Worker] Reconectando Redis…')
            r = get_redis()
        except KeyboardInterrupt:
            sys.exit(0)


if __name__ == '__main__':
    main()
