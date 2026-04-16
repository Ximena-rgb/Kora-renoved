"""
modules/auth/firebase_service.py
=================================
Servicio Firebase Admin SDK con tolerancia a desincronización de reloj.

El error "Token used too early" ocurre cuando el reloj del servidor Docker
está ligeramente detrás del reloj del cliente. Se resuelve con clock_skew_seconds.
"""

import logging
from functools import lru_cache

from django.conf import settings
from rest_framework.exceptions import AuthenticationFailed, PermissionDenied

logger = logging.getLogger(__name__)

# Tolerancia de reloj: 60 segundos en cada dirección
# Cubre desincronizaciones típicas de Docker Desktop en Mac/Windows
CLOCK_SKEW_SECONDS = 60


@lru_cache(maxsize=1)
def _get_firebase_app():
    try:
        import firebase_admin
        from firebase_admin import credentials

        if firebase_admin._apps:
            logger.info('[Firebase] App ya inicializada, reutilizando.')
            return firebase_admin.get_app()

        cred_path = settings.FIREBASE_CREDENTIALS_PATH
        logger.info(f'[Firebase] Cargando credenciales: "{cred_path}"')

        if not cred_path:
            raise ValueError('FIREBASE_CREDENTIALS_PATH no configurado en .env')

        import os
        if not os.path.exists(cred_path):
            raise FileNotFoundError(f'Credenciales no encontradas en: {cred_path}')

        cred = credentials.Certificate(cred_path)
        app  = firebase_admin.initialize_app(cred)
        logger.info('[Firebase] App inicializada ✅')
        return app

    except Exception as exc:
        logger.error(f'[Firebase] Error inicializando: {exc}')
        raise


def verify_google_token(id_token: str) -> dict:
    """
    Verifica el ID Token de Google/Firebase.

    Usa clock_skew_seconds=60 para tolerar desincronización de reloj
    entre el cliente y el servidor Docker — causa del error:
    "Token used too early, X < Y. Check that your computer's clock is set correctly."
    """
    logger.info(f'[Firebase] Verificando token ({len(id_token)} chars)')

    try:
        from firebase_admin import auth as firebase_auth
        _get_firebase_app()

        # clock_skew_seconds=60 tolera hasta 60s de desincronización
        decoded = firebase_auth.verify_id_token(
            id_token,
            check_revoked=True,
            clock_skew_seconds=CLOCK_SKEW_SECONDS,
        )
        logger.info(f'[Firebase] ✅ Token válido — uid={decoded.get("uid")} email={decoded.get("email")}')

    except Exception as exc:
        exc_type = type(exc).__name__
        logger.error(f'[Firebase] Error: {exc_type}: {exc}')

        try:
            from firebase_admin import auth as firebase_auth
            if isinstance(exc, firebase_auth.RevokedIdTokenError):
                raise AuthenticationFailed('Token revocado. Vuelve a iniciar sesión.')
            if isinstance(exc, firebase_auth.ExpiredIdTokenError):
                raise AuthenticationFailed('Token expirado. Vuelve a iniciar sesión.')
            if isinstance(exc, firebase_auth.InvalidIdTokenError):
                raise AuthenticationFailed(f'Token de Google inválido: {exc}')
        except (ImportError, AttributeError):
            pass

        raise AuthenticationFailed(f'No se pudo verificar el token: {exc}')

    email          = decoded.get('email', '')
    email_verified = decoded.get('email_verified', False)

    # Validar dominio institucional
    allowed_domain = settings.ALLOWED_EMAIL_DOMAIN
    if allowed_domain and not email.endswith(f'@{allowed_domain}'):
        logger.warning(f'[Firebase] Dominio rechazado: {email}')
        raise PermissionDenied(f'Solo cuentas @{allowed_domain} pueden acceder a Kora.')

    if not email_verified:
        logger.warning(f'[Firebase] Email no verificado: {email}')
        raise PermissionDenied('Tu cuenta de Google no tiene el email verificado.')

    return {
        'uid':      decoded['uid'],
        'email':    email,
        'nombre':   decoded.get('name', email.split('@')[0]),
        'foto_url': decoded.get('picture', ''),
    }
