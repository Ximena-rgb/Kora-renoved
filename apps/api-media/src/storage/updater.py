import logging
import os
import requests

logger = logging.getLogger(__name__)

API_CORE_URL  = os.getenv('API_CORE_INTERNAL_URL', 'http://api-core:8000')
SERVICE_TOKEN = os.getenv('SERVICE_TOKEN', '')


def notificar_foto_procesada(foto_id: int, estado: str, urls: dict = None, motivo: str = '') -> bool:
    try:
        resp = requests.patch(
            f'{API_CORE_URL}/api/v1/onboarding/interno/fotos/{foto_id}/procesada/',
            json={
                'estado': estado,
                'urls':   urls or {},
                'motivo': motivo,
            },
            headers={'X-Service-Token': SERVICE_TOKEN},
            timeout=10,
        )
        resp.raise_for_status()
        logger.info(f'[Updater] Foto {foto_id} -> {estado}')
        return True
    except Exception as exc:
        logger.error(f'[Updater] Error foto {foto_id}: {exc}')
        return False
