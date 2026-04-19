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
    Separa el displayName de Google en nombres + apellidos.
    Convención colombiana: primero los nombres, luego los apellidos.

    Reglas:
      1 parte  → todo es nombre, apellido vacío
      2 partes → 1 nombre + 1 apellido
      3 partes → 1 nombre + 2 apellidos  (lo más común: "Juan García López")
      4 partes → 2 nombres + 2 apellidos (ej: "Juan Pablo García López")
      5 partes → 2 nombres + 3 apellidos (ej: "Ana María García López Martínez")
      6+ partes → 3 nombres + resto apellidos

    Se aplica title() para corregir todo-mayúsculas que a veces devuelve Google.
    """
    if not display_name:
        return ('', '')

    partes = display_name.strip().title().split()
    n = len(partes)

    if n == 0:
        return ('', '')
    elif n == 1:
        return (partes[0], '')
    elif n == 2:
        # Juan García
        return (partes[0], partes[1])
    elif n == 3:
        # Juan García López → 1 nombre, 2 apellidos
        return (partes[0], ' '.join(partes[1:]))
    elif n == 4:
        # Juan Pablo García López → 2 nombres, 2 apellidos
        return (' '.join(partes[:2]), ' '.join(partes[2:]))
    elif n == 5:
        # Ana María García López Martínez → 2 nombres, 3 apellidos
        return (' '.join(partes[:2]), ' '.join(partes[2:]))
    else:
        # 6+ partes → 3 nombres + resto apellidos
        return (' '.join(partes[:3]), ' '.join(partes[3:]))


def _tokens_para(user) -> dict:
    refresh = RefreshToken.for_user(user)
    return {
        'access':  str(refresh.access_token),
        'refresh': str(refresh),
    }


def _serializar_user(user) -> dict:
    # Intentar obtener el apellido del perfil (UserProfile)
    apellido = ''
    try:
        apellido = user.profile.apellido or ''
    except Exception:
        pass

    return {
        'id':              user.id,
        'email':           user.email,
        'nombre':          user.nombre,
        'apellido':        apellido,        # ← siempre incluido
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
        user.save()

        # Crear perfil de onboarding con datos pre-llenados
        # IMPORTANTE: envuelto en try/except amplio para que una migración
        # pendiente nunca rompa el login (el perfil se puede crear después)
        try:
            from modules.onboarding.models import UserProfile
            profile, _ = UserProfile.objects.get_or_create(user=user)
            if apellido:
                profile.apellido = apellido
                profile.save(update_fields=['apellido'])
        except Exception as e:
            logger.warning(f'[google_login] Perfil no creado ahora (se creará en onboarding): {e}')

        try:
            broker.publish('USER_REGISTERED', {
                'user_id': user.id,
                'email':   email,
            })
        except Exception as e:
            logger.warning(f'[google_login] Broker publish falló: {e}')

        try:
            audit.log(request, audit.USER_REGISTERED, {'user_id': user.id, 'email': email})
        except Exception as e:
            logger.warning(f'[google_login] Audit log falló: {e}')

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
    try:
        audit.log(request, audit.USER_LOGIN, {'user_id': user.id})
    except Exception as e:
        logger.warning(f'[google_login] Audit login falló: {e}')

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



# ── POST /api/v1/auth/debug/login/ ───────────────────────────────
# Solo disponible con DEBUG=True. Permite login con email/password
# de cuentas Firebase para pruebas sin dominio institucional.
@api_view(['POST'])
@permission_classes([AllowAny])
def debug_login(request):
    """
    Endpoint de debug — autenticación con email+password de Firebase.
    SOLO activo cuando DEBUG=True. En producción devuelve 404.
    """
    from django.conf import settings as django_settings
    if not django_settings.DEBUG:
        from django.http import Http404
        raise Http404

    email    = request.data.get('email', '').strip().lower()
    password = request.data.get('password', '')
    nombre   = request.data.get('nombre', '').strip() or email.split('@')[0]

    if not email or not password:
        return Response({'error': 'email y password son requeridos.'}, status=400)

    # Autenticar contra Firebase con email+password via REST API
    import requests as req_lib
    import json

    try:
        firebase_api_key = _get_firebase_web_api_key()
        if not firebase_api_key:
            return Response(
                {'error': 'FIREBASE_WEB_API_KEY no configurada en .env (debug).'},
                status=500)

        resp = req_lib.post(
            f'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword'
            f'?key={firebase_api_key}',
            json={'email': email, 'password': password, 'returnSecureToken': True},
            timeout=10,
        )
        firebase_data = resp.json()

        if resp.status_code != 200:
            msg = firebase_data.get('error', {}).get('message', 'Credenciales incorrectas.')
            return Response({'error': f'Firebase: {msg}'}, status=401)

        id_token = firebase_data.get('idToken')
        uid      = firebase_data.get('localId')
        if not id_token or not uid:
            return Response({'error': 'Firebase no devolvió token.'}, status=500)

    except Exception as exc:
        logger.error(f'[debug_login] Firebase REST error: {exc}')
        return Response({'error': f'Error autenticando: {exc}'}, status=500)

    # Crear o recuperar usuario (sin validar dominio en debug)
    user, created = User.objects.get_or_create(
        firebase_uid=uid,
        defaults={
            'email':  email,
            'nombre': nombre,
        },
    )
    if created:
        user.set_unusable_password()
        user.save()
        try:
            from modules.onboarding.models import UserProfile
            UserProfile.objects.get_or_create(user=user)
        except Exception:
            pass
        logger.info(f'[debug_login] ✅ Usuario debug creado: {email}')
    else:
        logger.info(f'[debug_login] ✅ Login debug: {email}')

    tokens = _tokens_para(user)
    return Response({
        'access':  tokens['access'],
        'refresh': tokens['refresh'],
        'user':    _serializar_user(user),
    })


# ── POST /api/v1/auth/debug/register/ ───────────────────────────
@api_view(['POST'])
@permission_classes([AllowAny])
def debug_register(request):
    """
    Crea usuario en Firebase con email+password y lo registra en Kora.
    SOLO activo cuando DEBUG=True.
    """
    from django.conf import settings as django_settings
    if not django_settings.DEBUG:
        from django.http import Http404
        raise Http404

    email    = request.data.get('email', '').strip().lower()
    password = request.data.get('password', '')
    nombre   = request.data.get('nombre', '').strip() or email.split('@')[0]

    if not email or not password:
        return Response({'error': 'email y password son requeridos.'}, status=400)
    if len(password) < 6:
        return Response({'error': 'La contraseña debe tener al menos 6 caracteres.'}, status=400)

    import requests as req_lib

    try:
        firebase_api_key = _get_firebase_web_api_key()
        if not firebase_api_key:
            return Response(
                {'error': 'FIREBASE_WEB_API_KEY no configurada en .env (debug).'},
                status=500)

        resp = req_lib.post(
            f'https://identitytoolkit.googleapis.com/v1/accounts:signUp'
            f'?key={firebase_api_key}',
            json={'email': email, 'password': password, 'returnSecureToken': True},
            timeout=10,
        )
        firebase_data = resp.json()

        if resp.status_code != 200:
            msg = firebase_data.get('error', {}).get('message', 'Error al registrar.')
            # EMAIL_EXISTS → devolver mensaje claro
            if 'EMAIL_EXISTS' in msg:
                return Response({'error': 'Este email ya está registrado en Firebase. Usa el login.'}, status=400)
            return Response({'error': f'Firebase: {msg}'}, status=400)

        id_token = firebase_data.get('idToken')
        uid      = firebase_data.get('localId')

    except Exception as exc:
        logger.error(f'[debug_register] Firebase REST error: {exc}')
        return Response({'error': f'Error registrando: {exc}'}, status=500)

    user, created = User.objects.get_or_create(
        firebase_uid=uid,
        defaults={'email': email, 'nombre': nombre},
    )
    if created:
        user.set_unusable_password()
        user.save()
        try:
            from modules.onboarding.models import UserProfile
            UserProfile.objects.get_or_create(user=user)
        except Exception:
            pass

    tokens = _tokens_para(user)
    return Response({
        'access':  tokens['access'],
        'refresh': tokens['refresh'],
        'user':    _serializar_user(user),
        'created': created,
    }, status=201 if created else 200)


def _get_firebase_web_api_key() -> str:
    """Lee la Web API Key de Firebase desde .env."""
    from django.conf import settings as s
    return getattr(s, 'FIREBASE_WEB_API_KEY', '') or ''

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def completar_perfil(request):
    """Estado del perfil y onboarding."""
    return Response({
        'perfil_completo': request.user.perfil_completo,
        'user': _serializar_user(request.user),
    })
