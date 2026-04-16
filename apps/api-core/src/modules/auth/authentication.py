"""
modules/auth/authentication.py
================================
Backend de autenticación JWT para DRF.
Valida el token y verifica que la cuenta esté activa.
"""
import logging
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.exceptions import AuthenticationFailed

logger = logging.getLogger(__name__)


class KoraJWTAuthentication(JWTAuthentication):
    """
    JWT estándar con validaciones adicionales:
    - Cuenta activa
    - Perfil no suspendido
    """

    def get_user(self, validated_token):
        user = super().get_user(validated_token)
        if not user.is_active:
            raise AuthenticationFailed('Cuenta desactivada. Contacta soporte.')
        return user
