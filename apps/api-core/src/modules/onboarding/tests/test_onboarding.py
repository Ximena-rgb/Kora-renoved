"""
modules/onboarding/tests/test_onboarding.py
=============================================
Tests del flujo completo de onboarding.
"""
import io
import pytest
from datetime import date, timedelta
from unittest.mock import patch, MagicMock

from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from modules.onboarding.models import UserProfile, UserPhoto
from modules.onboarding.constants import PasoOnboarding

User = get_user_model()


# ── Fixtures ──────────────────────────────────────────────────────
@pytest.fixture
def usuario(db):
    return User.objects.create_user_from_google(
        email='test@unal.edu.co', firebase_uid='uid-test-123', nombre='Test User'
    )


@pytest.fixture
def client_auth(usuario):
    client = APIClient()
    refresh = RefreshToken.for_user(usuario)
    client.credentials(HTTP_AUTHORIZATION=f'Bearer {str(refresh.access_token)}')
    return client


@pytest.fixture
def profile(usuario, db):
    profile, _ = UserProfile.objects.get_or_create(user=usuario)
    return profile


# ── Helper: avanzar hasta un paso ────────────────────────────────
def avanzar_hasta(profile, paso):
    """Fuerza el paso del onboarding sin pasar por cada endpoint."""
    profile.onboarding_paso = paso
    profile.save(update_fields=['onboarding_paso'])


# ── Tests: Estado ─────────────────────────────────────────────────
class TestEstado:
    def test_estado_inicial(self, client_auth, usuario, db):
        resp = client_auth.get('/api/v1/onboarding/estado/')
        assert resp.status_code == 200
        assert resp.data['onboarding_paso'] == PasoOnboarding.TERMINOS
        assert resp.data['terminos_aceptados'] is False

    def test_requiere_autenticacion(self, db):
        client = APIClient()
        resp = client.get('/api/v1/onboarding/estado/')
        assert resp.status_code == 401


# ── Tests: Términos ───────────────────────────────────────────────
class TestTerminos:
    def test_aceptar_terminos_avanza(self, client_auth, profile, db):
        resp = client_auth.post('/api/v1/onboarding/terminos/', {
            'acepto_terminos': True,
            'acepto_datos': True,
        })
        assert resp.status_code == 200
        profile.refresh_from_db()
        assert profile.terminos_aceptados is True
        assert profile.onboarding_paso == PasoOnboarding.BASICO

    def test_no_aceptar_da_400(self, client_auth, profile, db):
        resp = client_auth.post('/api/v1/onboarding/terminos/', {
            'acepto_terminos': False,
            'acepto_datos': True,
        })
        assert resp.status_code == 400

    def test_no_aceptar_datos_da_400(self, client_auth, profile, db):
        resp = client_auth.post('/api/v1/onboarding/terminos/', {
            'acepto_terminos': True,
            'acepto_datos': False,
        })
        assert resp.status_code == 400

    def test_paso_incorrecto_da_400(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.BASICO)
        resp = client_auth.post('/api/v1/onboarding/terminos/', {
            'acepto_terminos': True,
            'acepto_datos': True,
        })
        assert resp.status_code == 400
        assert 'paso_actual' in resp.data


# ── Tests: Básico (verificación de edad) ─────────────────────────
class TestBasico:
    def setup_method(self):
        self.datos_validos = {
            'nombre':           'Juan',
            'apellido':         'Pérez',
            'fecha_nacimiento': '1999-06-15',
            'genero':           'masculino',
        }

    def test_mayor_de_edad_avanza(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.BASICO)
        resp = client_auth.post('/api/v1/onboarding/basico/', self.datos_validos)
        assert resp.status_code == 200
        assert resp.data['edad'] >= 18
        profile.refresh_from_db()
        assert profile.onboarding_paso == PasoOnboarding.INTENCIONES

    def test_menor_de_edad_da_400(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.BASICO)
        hoy = date.today()
        menor = date(hoy.year - 17, hoy.month, hoy.day)
        resp = client_auth.post('/api/v1/onboarding/basico/', {
            **self.datos_validos,
            'fecha_nacimiento': menor.strftime('%Y-%m-%d'),
        })
        assert resp.status_code == 400
        assert '18' in str(resp.data)

    def test_exactamente_18_avanza(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.BASICO)
        hoy = date.today()
        exacto_18 = date(hoy.year - 18, hoy.month, hoy.day)
        resp = client_auth.post('/api/v1/onboarding/basico/', {
            **self.datos_validos,
            'fecha_nacimiento': exacto_18.strftime('%Y-%m-%d'),
        })
        assert resp.status_code == 200

    def test_genero_otro_requiere_personalizado(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.BASICO)
        resp = client_auth.post('/api/v1/onboarding/basico/', {
            **self.datos_validos,
            'genero': 'otro',
        })
        assert resp.status_code == 400

    def test_genero_otro_con_personalizado_avanza(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.BASICO)
        resp = client_auth.post('/api/v1/onboarding/basico/', {
            **self.datos_validos,
            'genero': 'otro',
            'genero_personalizado': 'No binario fluido',
        })
        assert resp.status_code == 200

    def test_fecha_futura_da_400(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.BASICO)
        futuro = date.today() + timedelta(days=365)
        resp = client_auth.post('/api/v1/onboarding/basico/', {
            **self.datos_validos,
            'fecha_nacimiento': futuro.strftime('%Y-%m-%d'),
        })
        assert resp.status_code == 400


# ── Tests: Intenciones ────────────────────────────────────────────
class TestIntenciones:
    def test_seleccionar_pareja(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.INTENCIONES)
        resp = client_auth.post('/api/v1/onboarding/intenciones/', {
            'intenciones': ['pareja']
        })
        assert resp.status_code == 200
        profile.refresh_from_db()
        assert 'pareja' in profile.intenciones

    def test_seleccionar_las_tres(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.INTENCIONES)
        resp = client_auth.post('/api/v1/onboarding/intenciones/', {
            'intenciones': ['pareja', 'amistad', 'estudio']
        })
        assert resp.status_code == 200
        profile.refresh_from_db()
        assert len(profile.intenciones) == 3

    def test_sin_intenciones_da_400(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.INTENCIONES)
        resp = client_auth.post('/api/v1/onboarding/intenciones/', {
            'intenciones': []
        })
        assert resp.status_code == 400

    def test_intencion_invalida_da_400(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.INTENCIONES)
        resp = client_auth.post('/api/v1/onboarding/intenciones/', {
            'intenciones': ['citas_en_secreto']
        })
        assert resp.status_code == 400


# ── Tests: Preferencias ───────────────────────────────────────────
class TestPreferencias:
    def test_preferencias_pareja_completas(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.PREFERENCIAS)
        profile.intenciones = ['pareja']
        profile.save()

        resp = client_auth.post('/api/v1/onboarding/preferencias/', {
            'orientacion_sexual':   'heterosexual',
            'interesado_en_pareja': ['mujeres'],
        })
        assert resp.status_code == 200

    def test_pareja_sin_orientacion_da_400(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.PREFERENCIAS)
        profile.intenciones = ['pareja']
        profile.save()

        resp = client_auth.post('/api/v1/onboarding/preferencias/', {
            'interesado_en_pareja': ['mujeres'],
        })
        assert resp.status_code == 400

    def test_solo_estudio_body_vacio_avanza(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.PREFERENCIAS)
        profile.intenciones = ['estudio']
        profile.save()

        resp = client_auth.post('/api/v1/onboarding/preferencias/', {})
        assert resp.status_code == 200


# ── Tests: Personal ───────────────────────────────────────────────
class TestPersonal:
    def test_bio_corta_max_100(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.PERSONAL)
        resp = client_auth.post('/api/v1/onboarding/personal/', {
            'bio_corta': 'x' * 101,
        })
        assert resp.status_code == 400

    def test_tiene_animales_requiere_cuales(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.PERSONAL)
        resp = client_auth.post('/api/v1/onboarding/personal/', {
            'tiene_animales': True,
            'cuales_animales': '',
        })
        assert resp.status_code == 400

    def test_datos_completos_avanzan(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.PERSONAL)
        resp = client_auth.post('/api/v1/onboarding/personal/', {
            'bio_larga':        'Soy estudiante de sistemas apasionado por la IA.',
            'bio_corta':        'Dev apasionado 🚀',
            'gustos':           ['programar', 'música', 'café'],
            'fuma':             'no',
            'bebe':             'ocasional',
            'sale_fiesta':      'a_veces',
            'animales_gustan':  True,
            'tiene_animales':   True,
            'cuales_animales':  'Un perro llamado Bits',
            'nivel_actividad':  'moderado',
        })
        assert resp.status_code == 200


# ── Tests: Institucional ──────────────────────────────────────────
class TestInstitucional:
    def test_institucional_completo(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.INSTITUCIONAL)
        resp = client_auth.post('/api/v1/onboarding/institucional/', {
            'facultad':   'Ingeniería',
            'carrera':    'Ingeniería de Sistemas',
            'semestre':   5,
            'gusta_carrera': 'la_amo',
            'habilidades':   ['Python', 'Django', 'SQL'],
            'debilidades':   ['Frontend'],
            'busca_tesis':   False,
            'trabajo_preferencia': 'ambos',
        })
        assert resp.status_code == 200
        profile.refresh_from_db()
        assert profile.onboarding_paso == PasoOnboarding.FOTOS

    def test_semestre_invalido_da_400(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.INSTITUCIONAL)
        resp = client_auth.post('/api/v1/onboarding/institucional/', {
            'facultad': 'Ingeniería', 'carrera': 'Sistemas', 'semestre': 15,
        })
        assert resp.status_code == 400

    def test_sin_carrera_da_400(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.INSTITUCIONAL)
        resp = client_auth.post('/api/v1/onboarding/institucional/', {
            'facultad': 'Ingeniería', 'semestre': 3,
        })
        assert resp.status_code == 400


# ── Tests: Fotos ──────────────────────────────────────────────────
class TestFotos:
    def _make_image(self):
        """Genera una imagen PNG mínima válida para tests."""
        from PIL import Image
        img    = Image.new('RGB', (100, 100), color=(100, 150, 200))
        buffer = io.BytesIO()
        img.save(buffer, format='JPEG')
        buffer.seek(0)
        buffer.name = 'test.jpg'
        return buffer

    @patch('modules.onboarding.views.broker')
    def test_subir_foto_crea_registro_pending(self, mock_broker, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.FOTOS)
        img  = self._make_image()
        resp = client_auth.post('/api/v1/onboarding/fotos/',
                                {'foto': img}, format='multipart')
        assert resp.status_code == 202
        assert resp.data['estado'] == 'pending'
        assert UserPhoto.objects.filter(user=profile.user).count() == 1

    @patch('modules.onboarding.views.broker')
    def test_primera_foto_es_principal(self, mock_broker, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.FOTOS)
        img  = self._make_image()
        resp = client_auth.post('/api/v1/onboarding/fotos/',
                                {'foto': img}, format='multipart')
        assert resp.data['es_principal'] is True

    @patch('modules.onboarding.views.broker')
    def test_max_5_fotos(self, mock_broker, client_auth, profile, usuario, db):
        avanzar_hasta(profile, PasoOnboarding.FOTOS)
        # Crear 5 fotos directamente en DB
        for i in range(5):
            UserPhoto.objects.create(user=usuario, orden=i, estado='approved')

        img  = self._make_image()
        resp = client_auth.post('/api/v1/onboarding/fotos/',
                                {'foto': img}, format='multipart')
        assert resp.status_code == 400
        assert '5' in str(resp.data)

    def test_eliminar_foto(self, client_auth, usuario, profile, db):
        foto = UserPhoto.objects.create(user=usuario, orden=0, estado='approved')
        avanzar_hasta(profile, PasoOnboarding.FOTOS)
        resp = client_auth.delete(f'/api/v1/onboarding/fotos/{foto.id}/')
        assert resp.status_code == 200
        assert not UserPhoto.objects.filter(pk=foto.id).exists()


# ── Tests: Completar ──────────────────────────────────────────────
class TestCompletar:
    def test_completar_sin_fotos_da_400(self, client_auth, profile, db):
        avanzar_hasta(profile, PasoOnboarding.FOTOS)
        resp = client_auth.post('/api/v1/onboarding/completar/')
        assert resp.status_code == 400
        assert 'fotos' in str(resp.data).lower()

    def test_completar_con_fotos_aprobadas(self, client_auth, profile, usuario, db):
        avanzar_hasta(profile, PasoOnboarding.FOTOS)
        # Crear 2 fotos aprobadas
        for i in range(2):
            UserPhoto.objects.create(user=usuario, orden=i, estado='approved')

        resp = client_auth.post('/api/v1/onboarding/completar/')
        assert resp.status_code == 200
        assert resp.data['onboarding_paso'] == PasoOnboarding.COMPLETO

        usuario.refresh_from_db()
        assert usuario.perfil_completo is True

    def test_completar_dos_veces_da_400(self, client_auth, profile, usuario, db):
        avanzar_hasta(profile, PasoOnboarding.COMPLETO)
        resp = client_auth.post('/api/v1/onboarding/completar/')
        assert resp.status_code == 400
