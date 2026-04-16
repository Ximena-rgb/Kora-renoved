"""
modules/auth/mfa_service.py
============================
Servicio TOTP (Google Authenticator / Authy).

Flujo de activación:
  1. GET  /auth/mfa/setup/    → genera secret + QR URI
  2. POST /auth/mfa/activate/ → verifica código → activa MFA + genera backup codes

Flujo de login con MFA:
  1. POST /auth/google/       → si mfa_activo → devuelve mfa_token temporal (Redis)
  2. POST /auth/mfa/verify/   → verifica código TOTP + mfa_token → devuelve JWT

Backup codes:
  - 8 códigos de un solo uso, hasheados en DB
  - Permiten acceso si se pierde el dispositivo
"""

import hashlib
import io
import logging
import secrets
import uuid

import pyotp
import qrcode
import base64

from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger(__name__)


# ── Generar secret y URI para QR ─────────────────────────────────
def generar_totp_secret(email: str) -> dict:
    """
    Genera un nuevo secret TOTP y la URI para el QR.

    Retorna:
        {
            'secret':  str,   # Base32 — guardar en user.mfa_secret
            'qr_uri':  str,   # otpauth://totp/...
            'qr_b64':  str,   # QR code como imagen PNG en base64
        }
    """
    secret  = pyotp.random_base32()
    issuer  = settings.MFA_ISSUER_NAME
    totp    = pyotp.TOTP(secret)
    qr_uri  = totp.provisioning_uri(name=email, issuer_name=issuer)

    # Generar imagen QR como base64 para enviar al cliente
    qr_img  = qrcode.make(qr_uri)
    buffer  = io.BytesIO()
    qr_img.save(buffer, format='PNG')
    qr_b64  = base64.b64encode(buffer.getvalue()).decode('utf-8')

    return {
        'secret':  secret,
        'qr_uri':  qr_uri,
        'qr_b64':  f'data:image/png;base64,{qr_b64}',
    }


# ── Verificar código TOTP ────────────────────────────────────────
def verificar_totp(secret: str, codigo: str, ventana: int = 1) -> bool:
    """
    Verifica un código TOTP de 6 dígitos.
    ventana=1 permite 30s de tolerancia en cada lado.
    """
    if not secret or not codigo:
        return False
    totp = pyotp.TOTP(secret)
    return totp.verify(codigo, valid_window=ventana)


# ── Generar backup codes ─────────────────────────────────────────
def generar_backup_codes() -> tuple[list[str], list[str]]:
    """
    Genera 8 códigos de respaldo únicos.

    Retorna:
        (codigos_planos, codigos_hasheados)
        - codigos_planos   → mostrar al usuario UNA sola vez
        - codigos_hasheados → guardar en user.mfa_backup_codes
    """
    codigos_planos    = [secrets.token_hex(4).upper() for _ in range(8)]
    codigos_hasheados = [_hash_backup_code(c) for c in codigos_planos]
    return codigos_planos, codigos_hasheados


def _hash_backup_code(codigo: str) -> str:
    return hashlib.sha256(codigo.encode()).hexdigest()


def verificar_backup_code(usuario, codigo: str) -> bool:
    """
    Verifica y consume un backup code (un solo uso).
    Si es válido lo elimina de la lista.
    """
    codigo_hash = _hash_backup_code(codigo.upper().strip())
    backup_codes = list(usuario.mfa_backup_codes)

    if codigo_hash in backup_codes:
        backup_codes.remove(codigo_hash)
        usuario.mfa_backup_codes = backup_codes
        usuario.save(update_fields=['mfa_backup_codes'])
        return True
    return False


# ── Token MFA temporal (Redis) ───────────────────────────────────
def crear_mfa_token(user_id: int) -> str:
    """
    Crea un token temporal en Redis que representa un login
    pendiente de verificación MFA.
    TTL: MFA_TOKEN_TTL segundos (default 5 min).
    """
    token = str(uuid.uuid4())
    key   = f"{settings.MFA_REDIS_PREFIX}{token}"
    cache.set(key, str(user_id), timeout=settings.MFA_TOKEN_TTL)
    logger.debug(f'[MFA] Token temporal creado para user={user_id}')
    return token


def consumir_mfa_token(token: str) -> int | None:
    """
    Valida y consume el token MFA temporal.
    Retorna user_id si es válido, None si expiró/no existe.
    """
    key     = f"{settings.MFA_REDIS_PREFIX}{token}"
    user_id = cache.get(key)
    if user_id:
        cache.delete(key)  # Un solo uso
        return int(user_id)
    return None


# ── Clase wrapper para compatibilidad con views.py ───────────────
class MFAService:
    """Wrapper estático sobre las funciones TOTP del módulo."""

    @staticmethod
    def generar_token_pendiente(user_id: int) -> str:
        return crear_mfa_token(user_id)

    @staticmethod
    def verificar_token_pendiente(token: str) -> int | None:
        return consumir_mfa_token(token)

    @staticmethod
    def verificar_codigo_totp(usuario, codigo: str) -> bool:
        # Primero intenta TOTP normal
        if verificar_totp(usuario.mfa_secret, codigo.strip()):
            return True
        # Luego backup codes
        return verificar_backup_code(usuario, codigo.strip())
