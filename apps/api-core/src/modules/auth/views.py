"""
modules/auth/views.py
======================
Autenticación con Google/Firebase + JWT + MFA opcional.
"""
import logging
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError

from django.contrib.auth import get_user_model
from django.conf import settings

from shared.audit import audit
from shared.broker import broker
from .firebase_service import verify_google_token
from .mfa_service import MFAService
from .serializers import GoogleLoginSerializer

logger = logging.getLogger(__name__)
User = get_user_model()


def _parse_nombre_google(display_name: str) -> tuple[str, str]:
    """
    Separa el displayName de Google en nombre + apellido.
    Aplica title() para capitalización correcta (no todo mayúsculas).

    Ejemplos:
      "JUAN PABLO GARCIA LOPEZ" → ("Juan Pablo", "Garcia Lopez")
      "María"                   → ("María", "")
      "john doe"                → ("John", "Doe")
    """
    if not display_name:
        return ('', '')

    partes = display_name.title().split()

    if len(partes) == 0:
        return ('', '')
    elif len(partes) == 1:
        return (partes[0], '')
    elif len(partes) == 2:
        return (partes[0], partes[1])
    elif len(partes) == 3:
        # Ej: "Juan Garcia Lopez" → nombre="Juan", apellido="Garcia Lopez"
        return (partes[0], ' '.join(partes[1:]))
    else:
        # Ej: "Juan Pablo Garcia Lopez" → nombre="Juan Pablo", apellido="Garcia Lopez"
        mitad = len(partes) // 2
        return (' '.join(partes[:mitad]), ' '.join(partes[mitad:]))


def _tokens_para(user) -> dict:
    refresh = RefreshToken.for_user(user)
    return {
        'access':  str(refresh.access_token),
        'refresh': str(refresh),
    }


def _serializar_user(user) -> dict:
    return {
        'id':              user.id,
        'email':           user.email,
        'nombre':          user.nombre,
        'foto_url':        user.foto_url or '',
        'carrera':         user.carrera or '',
        'facultad':        user.facultad or '',
        'semestre':        user.semestre or 1,
        'bio':             user.bio or '',
        'intereses':       user.intereses or [],
        'disponible':      user.disponible,
        'campus_zona':     user.campus_zona or '',
        'reputacion':      float(user.reputacion),
        'perfil_completo': user.perfil_completo,
        'mfa_activo':      user.mfa_activo,
    }


# ── POST /api/v1/auth/google/ ─────────────────────────────────────
@api_view(['POST'])
@permission_classes([AllowAny])
def google_login(request):
    """
    Recibe el ID Token de Firebase (Google Sign-In).
    Crea o actualiza el usuario y devuelve JWT.
    """
    logger.info(f'[google_login] IP: {request.META.get("REMOTE_ADDR")} | keys: {list(request.data.keys())}')

    s = GoogleLoginSerializer(data=request.data)
    if not s.is_valid():
        return Response(s.errors, status=status.HTTP_400_BAD_REQUEST)

    id_token = s.validated_data['id_token']

    try:
        google_data = verify_google_token(id_token)
    except Exception as exc:
        logger.error(f'[google_login] verify falló: {exc}')
        return Response({'error': str(exc)}, status=status.HTTP_401_UNAUTHORIZED)

    uid      = google_data['uid']
    email    = google_data['email']
    foto_url = google_data.get('foto_url', '')

    # ── Separar y capitalizar el nombre de Google ────────────────
    nombre_raw = google_data.get('nombre', email.split('@')[0])
    nombre, apellido = _parse_nombre_google(nombre_raw)

    logger.info(f'[google_login] email={email} nombre="{nombre}" apellido="{apellido}"')

    # ── Crear o actualizar usuario ───────────────────────────────
    user, created = User.objects.get_or_create(
        firebase_uid=uid,
        defaults={
            'email':    email,
            'nombre':   nombre,
            'foto_url': foto_url,
        },
    )

    if created:
        user.set_unusable_password()
        # Guardar apellido en el perfil si el modelo lo tiene directamente
        # (sino se guarda en onboarding/UserProfile.apellido)
        user.save()

        # Crear perfil de onboarding con datos pre-llenados
        try:
            from modules.onboarding.models import UserProfile
            profile, _ = UserProfile.objects.get_or_create(user=user)
            profile.apellido = apellido
            profile.save(update_fields=['apellido'])
        except Exception as e:
            logger.warning(f'[google_login] No se pudo crear perfil: {e}')

        broker.publish('USER_REGISTERED', {
            'user_id': user.id,
            'email':   email,
        })
        audit.log(request, audit.USER_REGISTERED, {'user_id': user.id, 'email': email})
        logger.info(f'[google_login] ✅ Usuario creado: {email}')
    else:
        # Actualizar foto si cambió
        if foto_url and user.foto_url != foto_url and not user.perfil_completo:
            user.foto_url = foto_url
            user.save(update_fields=['foto_url'])

    # ── MFA ──────────────────────────────────────────────────────
    if user.mfa_activo:
        mfa_token = MFAService.generar_token_pendiente(user.id)
        return Response({
            'mfa_required': True,
            'mfa_token':    mfa_token,
        })

    tokens = _tokens_para(user)
    audit.log(request, audit.USER_LOGIN, {'user_id': user.id})

    return Response({
        'access':  tokens['access'],
        'refresh': tokens['refresh'],
        'user':    _serializar_user(user),
    })


# ── GET /api/v1/auth/me/ ─────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def me(request):
    return Response(_serializar_user(request.user))


# ── POST /api/v1/auth/mfa/verify/ ────────────────────────────────
@api_view(['POST'])
@permission_classes([AllowAny])
def mfa_verify(request):
    mfa_token = request.data.get('mfa_token')
    codigo    = request.data.get('codigo', '').strip()

    if not mfa_token or not codigo:
        return Response({'error': 'mfa_token y codigo son requeridos.'}, status=400)

    user_id = MFAService.verificar_token_pendiente(mfa_token)
    if not user_id:
        return Response({'error': 'Token MFA inválido o expirado.'}, status=401)

    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({'error': 'Usuario no encontrado.'}, status=404)

    if not MFAService.verificar_codigo_totp(user, codigo):
        return Response({'error': 'Código incorrecto.'}, status=401)

    tokens = _tokens_para(user)
    return Response({
        'access':  tokens['access'],
        'refresh': tokens['refresh'],
        'user':    _serializar_user(user),
    })


# ── POST /api/v1/auth/logout/ ────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout(request):
    try:
        refresh = request.data.get('refresh')
        if refresh:
            token = RefreshToken(refresh)
            token.blacklist()
    except TokenError:
        pass
    return Response({'mensaje': 'Sesión cerrada.'})


# ── POST /api/v1/auth/token/refresh/ ────────────────────────────
@api_view(['POST'])
@permission_classes([AllowAny])
def token_refresh(request):
    from rest_framework_simplejwt.views import TokenRefreshView
    return TokenRefreshView.as_view()(request._request)


# ── POST /api/v1/auth/mfa/setup/ ─────────────────────────────────
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def mfa_setup(request):
    """Genera el QR para configurar Google Authenticator."""
    from .mfa_service import generar_totp_secret
    if request.user.mfa_activo:
        return Response({'error': 'MFA ya está activo.'}, status=400)
    data = generar_totp_secret(request.user.email)
    # Guardar secret temporalmente en session/cache hasta que active
    from django.core.cache import cache
    cache.set(f'mfa_setup_{request.user.id}', data['secret'], timeout=600)
    return Response({'qr_b64': data['qr_b64'], 'qr_uri': data['qr_uri']})


# ── POST /api/v1/auth/mfa/activate/ ─────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mfa_activate(request):
    """Activa MFA verificando el primer código."""
    from .mfa_service import verificar_totp, generar_backup_codes
    from django.core.cache import cache
    codigo = request.data.get('codigo', '').strip()
    secret = cache.get(f'mfa_setup_{request.user.id}')
    if not secret:
        return Response({'error': 'Sesión de setup expirada. Reinicia el proceso.'}, status=400)
    if not verificar_totp(secret, codigo):
        return Response({'error': 'Código incorrecto.'}, status=401)
    codigos_planos, codigos_hash = generar_backup_codes()
    request.user.mfa_secret        = secret
    request.user.mfa_activo        = True
    request.user.mfa_backup_codes  = codigos_hash
    request.user.save(update_fields=['mfa_secret', 'mfa_activo', 'mfa_backup_codes'])
    cache.delete(f'mfa_setup_{request.user.id}')
    return Response({'mensaje': 'MFA activado.', 'backup_codes': codigos_planos})


# ── POST /api/v1/auth/mfa/deactivate/ ───────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mfa_deactivate(request):
    """Desactiva MFA verificando el código actual."""
    from .mfa_service import verificar_totp
    codigo = request.data.get('codigo', '').strip()
    if not request.user.mfa_activo:
        return Response({'error': 'MFA no está activo.'}, status=400)
    if not verificar_totp(request.user.mfa_secret, codigo):
        return Response({'error': 'Código incorrecto.'}, status=401)
    request.user.mfa_activo       = False
    request.user.mfa_secret       = ''
    request.user.mfa_backup_codes = []
    request.user.save(update_fields=['mfa_activo', 'mfa_secret', 'mfa_backup_codes'])
    return Response({'mensaje': 'MFA desactivado.'})


# ── POST /api/v1/auth/perfil/completar/ ──────────────────────────
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def completar_perfil(request):
    """Estado del perfil y onboarding."""
    return Response({
        'perfil_completo': request.user.perfil_completo,
        'user': _serializar_user(request.user),
    })
