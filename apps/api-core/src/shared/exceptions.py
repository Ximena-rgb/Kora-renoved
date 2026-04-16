import logging
from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status

logger = logging.getLogger(__name__)


def kora_exception_handler(exc, context):
    response = exception_handler(exc, context)
    if response is not None:
        data = response.data
        if isinstance(data, dict) and 'detail' in data:
            error_msg = str(data['detail'])
        elif isinstance(data, list):
            error_msg = str(data[0]) if data else 'Error desconocido'
        else:
            error_msg = str(data)
        response.data = {
            'error':  error_msg,
            'detail': data,
            'status': response.status_code,
        }
        return response
    logger.exception(f'[Kora] Excepción no manejada: {exc}')
    return Response(
        {'error': 'Error interno del servidor.', 'status': 500},
        status=status.HTTP_500_INTERNAL_SERVER_ERROR,
    )
