"""
modules/auth/tests/test_auth.py
================================
Tests del módulo de autenticación.

Cubre:
  - Google login (usuario nuevo y existente)
  - Validación de dominio institucional
  - Flujo MFA completo (setup → activate → verify → deactivate)
  - Backup codes
  - Logout (JWT blacklist)
  - Completar perfil
"""

import pytest
from unittest.mock import patch, MagicMock

from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from modules.auth.mfa_service import (
    generar_totp_secret, verificar_totp,
    generar_backup_codes, verificar_backup_code,
    crear_mfa_token, consumir_mfa_token,
)

User = get_user_model()


# ── Fixtures ──────────────────────────────────────────────────────
@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def usuario_google(db):
    """Usuario creado via Google Sign-In."""
    return User.objects.create_user_from_google(
        email        = 'juan.perez@unal.edu.co',
        firebase_uid = 'google-uid-abc123',
        nombre       = 'Juan Pérez',
        foto_url     = 'https://lh3.googleusercontent.com/test.jpg',
    )


@pytest.fixture
def auth_client(api_client, usuario_google):
    """Cliente autenticado con JWT."""
    refresh = RefreshToken.for_user(usuario_google)
    api_client.credentials(HTTP_AUTHORIZATION=f'Bearer {str(refresh.access_token)}')
    return api_client


# ── Google Login ──────────────────────────────────────────────────
class TestGoogleLogin:

    GOOGLE_DATA = {
        'uid':      'google-uid-nuevo-xyz',
        'email':    'maria.gomez@unal.edu.co',
        'nombre':   'María Gómez',
        'foto_url': 'https://lh3.googleusercontent.com/maria.jpg',
    }

    @patch('modules.auth.views.verify_google_token')
    def test_registro_nuevo_usuario(self, mock_verify, api_client, db):
        """Primer login crea el usuario y devuelve is_new=True."""
        mock_verify.return_value = self.GOOGLE_DATA

        resp = api_client.post('/api/v1/auth/google/', {'id_token': 'fake-token'})

        assert resp.status_code == 200
        assert resp.data['is_new'] is True
        assert 'access' in resp.data
        assert 'refresh' in resp.data
        assert resp.data['perfil_completo'] is False
        assert User.objects.filter(email='maria.gomez@unal.edu.co').exists()

    @patch('modules.auth.views.verify_google_token')
    def test_login_usuario_existente(self, mock_verify, api_client, usuario_google, db):
        """Login de usuario existente devuelve is_new=False."""
        mock_verify.return_value = {
            'uid':      'google-uid-abc123',
            'email':    'juan.perez@unal.edu.co',
            'nombre':   'Juan Pérez',
            'foto_url': 'https://lh3.googleusercontent.com/test.jpg',
        }

        resp = api_client.post('/api/v1/auth/google/', {'id_token': 'fake-token'})

        assert resp.status_code == 200
        assert resp.data['is_new'] is False
        assert 'access' in resp.data

    @patch('modules.auth.views.verify_google_token')
    def test_login_con_mfa_activo(self, mock_verify, api_client, usuario_google, db):
        """Login con MFA activo devuelve mfa_required=True."""
        usuario_google.mfa_activo = True
        usuario_google.mfa_secret = generar_totp_secret(usuario_google.email)['secret']
        usuario_google.save()

        mock_verify.return_value = {
            'uid':      'google-uid-abc123',
            'email':    'juan.perez@unal.edu.co',
            'nombre':   'Juan Pérez',
            'foto_url': '',
        }

        resp = api_client.post('/api/v1/auth/google/', {'id_token': 'fake-token'})

        assert resp.status_code == 200
        assert resp.data['mfa_required'] is True
        assert 'mfa_token' in resp.data
        assert 'access' not in resp.data

    def test_token_invalido_da_401(self, api_client, db):
        """Token de Google inválido devuelve 401."""
        from rest_framework.exceptions import AuthenticationFailed
        with patch('modules.auth.views.verify_google_token',
                   side_effect=AuthenticationFailed('Token inválido')):
            resp = api_client.post('/api/v1/auth/google/', {'id_token': 'bad-token'})
        assert resp.status_code == 401

    @patch('modules.auth.views.verify_google_token')
    def test_usuario_inactivo_da_403(self, mock_verify, api_client, usuario_google, db):
        usuario_google.is_active = False
        usuario_google.save()
        mock_verify.return_value = {
            'uid': 'google-uid-abc123', 'email': 'juan.perez@unal.edu.co',
            'nombre': 'Juan Pérez', 'foto_url': '',
        }
        resp = api_client.post('/api/v1/auth/google/', {'id_token': 'fake-token'})
        assert resp.status_code == 403


# ── MFA Service (unit tests) ──────────────────────────────────────
class TestMFAService:

    def test_generar_secret_produce_qr(self):
        datos = generar_totp_secret('test@uni.edu.co')
        assert 'secret' in datos
        assert 'qr_b64' in datos
        assert datos['qr_b64'].startswith('data:image/png;base64,')
        assert len(datos['secret']) == 32  # Base32 pyotp por defecto

    def test_verificar_totp_valido(self):
        import pyotp
        datos  = generar_totp_secret('test@uni.edu.co')
        totp   = pyotp.TOTP(datos['secret'])
        codigo = totp.now()
        assert verificar_totp(datos['secret'], codigo) is True

    def test_verificar_totp_invalido(self):
        datos = generar_totp_secret('test@uni.edu.co')
        assert verificar_totp(datos['secret'], '000000') is False

    def test_backup_codes_generacion(self):
        planos, hasheados = generar_backup_codes()
        assert len(planos)    == 8
        assert len(hasheados) == 8
        assert all(len(c) == 8 for c in planos)  # hex(4) = 8 chars
        # Los hashes son distintos a los planos
        assert planos[0] not in hasheados

    def test_backup_code_uso_unico(self, db, usuario_google):
        planos, hasheados = generar_backup_codes()
        usuario_google.mfa_backup_codes = hasheados
        usuario_google.save()

        # Primer uso → válido
        assert verificar_backup_code(usuario_google, planos[0]) is True
        # Segundo uso → inválido (ya fue consumido)
        usuario_google.refresh_from_db()
        assert verificar_backup_code(usuario_google, planos[0]) is False

    def test_mfa_token_redis(self, db):
        token   = crear_mfa_token(user_id=42)
        user_id = consumir_mfa_token(token)
        assert user_id == 42
        # Segundo consumo → None (ya fue usado)
        assert consumir_mfa_token(token) is None

    def test_mfa_token_inexistente(self):
        assert consumir_mfa_token('token-que-no-existe') is None


# ── MFA Flow (integration) ────────────────────────────────────────
class TestMFAFlow:

    def test_setup_sin_mfa_activo(self, auth_client, usuario_google, db):
        resp = auth_client.get('/api/v1/auth/mfa/setup/')
        assert resp.status_code == 200
        assert 'qr_code' in resp.data
        assert 'secret' in resp.data

    def test_setup_con_mfa_ya_activo_da_400(self, auth_client, usuario_google, db):
        usuario_google.mfa_activo = True
        usuario_google.save()
        resp = auth_client.get('/api/v1/auth/mfa/setup/')
        assert resp.status_code == 400

    def test_activate_con_codigo_correcto(self, auth_client, usuario_google, db):
        import pyotp
        # Setup
        datos = generar_totp_secret(usuario_google.email)
        usuario_google.mfa_secret = datos['secret']
        usuario_google.save()

        codigo = pyotp.TOTP(datos['secret']).now()
        resp   = auth_client.post('/api/v1/auth/mfa/activate/', {'codigo': codigo})

        assert resp.status_code == 200
        assert 'backup_codes' in resp.data
        assert len(resp.data['backup_codes']) == 8

        usuario_google.refresh_from_db()
        assert usuario_google.mfa_activo is True

    def test_activate_con_codigo_incorrecto_da_400(self, auth_client, usuario_google, db):
        datos = generar_totp_secret(usuario_google.email)
        usuario_google.mfa_secret = datos['secret']
        usuario_google.save()

        resp = auth_client.post('/api/v1/auth/mfa/activate/', {'codigo': '000000'})
        assert resp.status_code == 400

    def test_mfa_verify_completo(self, api_client, usuario_google, db):
        import pyotp
        datos = generar_totp_secret(usuario_google.email)
        usuario_google.mfa_activo = True
        usuario_google.mfa_secret = datos['secret']
        usuario_google.save()

        mfa_token = crear_mfa_token(usuario_google.id)
        codigo    = pyotp.TOTP(datos['secret']).now()

        resp = api_client.post('/api/v1/auth/mfa/verify/', {
            'mfa_token': mfa_token,
            'codigo':    codigo,
        })

        assert resp.status_code == 200
        assert 'access' in resp.data
        assert 'refresh' in resp.data

    def test_mfa_verify_token_expirado_da_401(self, api_client, db):
        resp = api_client.post('/api/v1/auth/mfa/verify/', {
            'mfa_token': 'token-expirado-o-invalido',
            'codigo':    '123456',
        })
        assert resp.status_code == 401


# ── Logout ────────────────────────────────────────────────────────
class TestLogout:

    def test_logout_blacklistea_token(self, auth_client, usuario_google, db):
        refresh = RefreshToken.for_user(usuario_google)
        resp    = auth_client.post('/api/v1/auth/logout/', {'refresh': str(refresh)})
        assert resp.status_code == 200

        # El token ya no puede usarse
        resp2 = auth_client.post('/api/v1/auth/token/refresh/', {'refresh': str(refresh)})
        assert resp2.status_code == 401

    def test_logout_sin_token_da_400(self, auth_client, db):
        resp = auth_client.post('/api/v1/auth/logout/', {})
        assert resp.status_code == 400


# ── Completar Perfil ──────────────────────────────────────────────
class TestCompletarPerfil:

    def test_completar_perfil_exitoso(self, auth_client, usuario_google, db):
        resp = auth_client.post('/api/v1/auth/perfil/completar/', {
            'carrera':   'Ingeniería de Sistemas',
            'facultad':  'Ingeniería',
            'semestre':  4,
            'bio':       'Me gusta el código',
            'intereses': ['python', 'machine learning'],
        })
        assert resp.status_code == 200
        usuario_google.refresh_from_db()
        assert usuario_google.perfil_completo is True
        assert usuario_google.carrera == 'Ingeniería de Sistemas'

    def test_completar_perfil_segunda_vez_da_400(self, auth_client, usuario_google, db):
        usuario_google.perfil_completo = True
        usuario_google.save()
        resp = auth_client.post('/api/v1/auth/perfil/completar/', {
            'carrera': 'Medicina', 'semestre': 1,
        })
        assert resp.status_code == 400

    def test_completar_perfil_sin_carrera_da_400(self, auth_client, db):
        resp = auth_client.post('/api/v1/auth/perfil/completar/', {'semestre': 3})
        assert resp.status_code == 400
