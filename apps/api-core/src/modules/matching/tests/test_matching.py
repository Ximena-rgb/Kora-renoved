"""
modules/matching/tests/test_matching.py
========================================
Tests del motor de matching Kora.
"""
import pytest
from unittest.mock import patch
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from modules.matching.models import SwipeAction, Match, Bloqueo, LikeDiario, Contrapropuesta
from modules.matching.constants import Modo, Accion, EstadoLike, LIKES_DIARIOS
from modules.matching.engine import (
    calcular_score_completo, score_intereses, score_estilo_vida,
    get_likes_restantes, registrar_like, expirar_likes_vencidos,
)

User = get_user_model()


# ── Fixtures ──────────────────────────────────────────────────────
def make_user(db, email, uid, nombre='Test', carrera='Sistemas', facultad='Ingeniería'):
    u = User.objects.create_user_from_google(
        email=email, firebase_uid=uid, nombre=nombre
    )
    u.carrera         = carrera
    u.facultad        = facultad
    u.intereses       = ['python', 'música', 'café']
    u.perfil_completo = True
    u.save()
    return u


@pytest.fixture
def user_a(db):
    return make_user(db, 'a@uni.edu.co', 'uid-a', nombre='Ana')


@pytest.fixture
def user_b(db):
    return make_user(db, 'b@uni.edu.co', 'uid-b', nombre='Bruno')


@pytest.fixture
def user_c(db):
    return make_user(db, 'c@uni.edu.co', 'uid-c', nombre='Carlos')


@pytest.fixture
def client_a(user_a):
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f'Bearer {str(RefreshToken.for_user(user_a).access_token)}')
    return c


@pytest.fixture
def client_b(user_b):
    c = APIClient()
    c.credentials(HTTP_AUTHORIZATION=f'Bearer {str(RefreshToken.for_user(user_b).access_token)}')
    return c


# ── Tests: Engine — Scores ────────────────────────────────────────
class TestScores:
    def test_score_intereses_identicos(self):
        assert score_intereses(['python', 'música'], ['python', 'música']) == 1.0

    def test_score_intereses_sin_comun(self):
        assert score_intereses(['python'], ['fútbol']) == 0.0

    def test_score_intereses_parcial(self):
        s = score_intereses(['python', 'música', 'café'], ['python', 'fútbol'])
        assert 0.0 < s < 1.0

    def test_score_intereses_vacio(self):
        assert score_intereses([], ['python']) == 0.0

    def test_calcular_score_completo(self, user_a, user_b, db):
        scores = calcular_score_completo(user_a, user_b, Modo.PAREJA)
        assert 'score_total' in scores
        assert 0.0 <= scores['score_total'] <= 100.0
        assert all(k in scores for k in [
            'score_intenciones', 'score_intereses',
            'score_estilo_vida', 'score_carrera', 'score_horarios'
        ])

    def test_misma_carrera_aumenta_score(self, user_a, user_b, db):
        user_a.carrera = user_b.carrera = 'Ingeniería de Sistemas'
        user_a.save(); user_b.save()
        scores_igual = calcular_score_completo(user_a, user_b, Modo.PAREJA)

        user_b.carrera = 'Medicina'
        user_b.save()
        scores_diff = calcular_score_completo(user_a, user_b, Modo.PAREJA)

        assert scores_igual['score_carrera'] > scores_diff['score_carrera']


# ── Tests: Límites diarios ────────────────────────────────────────
class TestLikesDiarios:
    def test_likes_iniciales_disponibles(self, user_a, db):
        info = get_likes_restantes(user_a, Modo.PAREJA)
        assert info['restantes'] == LIKES_DIARIOS[Modo.PAREJA]
        assert info['puede_likear'] is True

    def test_registrar_like_descuenta(self, user_a, db):
        registrar_like(user_a, Modo.PAREJA)
        info = get_likes_restantes(user_a, Modo.PAREJA)
        assert info['usados'] == 1
        assert info['restantes'] == LIKES_DIARIOS[Modo.PAREJA] - 1

    def test_limite_agotado(self, user_a, db):
        limite = LIKES_DIARIOS[Modo.PAREJA]
        for _ in range(limite):
            registrar_like(user_a, Modo.PAREJA)
        assert registrar_like(user_a, Modo.PAREJA) is False
        info = get_likes_restantes(user_a, Modo.PAREJA)
        assert info['puede_likear'] is False

    def test_superlike_solo_uno_por_dia(self, user_a, db):
        assert registrar_like(user_a, Modo.PAREJA, es_superlike=True) is True
        assert registrar_like(user_a, Modo.PAREJA, es_superlike=True) is False

    def test_modos_independientes(self, user_a, db):
        """Agotar pareja no afecta amistad."""
        limite = LIKES_DIARIOS[Modo.PAREJA]
        for _ in range(limite):
            registrar_like(user_a, Modo.PAREJA)
        assert get_likes_restantes(user_a, Modo.AMISTAD)['puede_likear'] is True


# ── Tests: Swipe ──────────────────────────────────────────────────
class TestSwipe:
    @patch('modules.matching.views.enviar_notificacion_ws')
    def test_like_crea_swipe(self, mock_notif, client_a, user_a, user_b, db):
        resp = client_a.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_b.id,
            'modo':         Modo.PAREJA,
            'accion':       Accion.LIKE,
        })
        assert resp.status_code == 200
        assert SwipeAction.objects.filter(
            de_usuario=user_a, a_usuario=user_b, modo=Modo.PAREJA
        ).exists()

    @patch('modules.matching.views.enviar_notificacion_ws')
    def test_match_mutuo_crea_match(self, mock_notif, client_a, client_b, user_a, user_b, db):
        # A le da like a B
        client_a.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_b.id, 'modo': Modo.PAREJA, 'accion': Accion.LIKE,
        })
        # B le da like a A → match
        resp = client_b.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_a.id, 'modo': Modo.PAREJA, 'accion': Accion.LIKE,
        })
        assert resp.status_code == 200
        assert resp.data['match_creado'] is True
        assert Match.objects.filter(modo=Modo.PAREJA).exists()

    @patch('modules.matching.views.enviar_notificacion_ws')
    def test_pass_crea_bloqueo(self, mock_notif, client_a, user_a, user_b, db):
        resp = client_a.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_b.id, 'modo': Modo.PAREJA, 'accion': Accion.PASS,
        })
        assert resp.status_code == 200
        assert Bloqueo.objects.filter(bloqueador=user_a, bloqueado=user_b).exists()

    @patch('modules.matching.views.enviar_notificacion_ws')
    def test_swipe_duplicado_da_400(self, mock_notif, client_a, user_a, user_b, db):
        client_a.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_b.id, 'modo': Modo.PAREJA, 'accion': Accion.LIKE,
        })
        resp = client_a.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_b.id, 'modo': Modo.PAREJA, 'accion': Accion.LIKE,
        })
        assert resp.status_code == 400

    def test_no_puede_swipearse_a_si_mismo(self, client_a, user_a, db):
        resp = client_a.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_a.id, 'modo': Modo.PAREJA, 'accion': Accion.LIKE,
        })
        assert resp.status_code == 400

    @patch('modules.matching.views.enviar_notificacion_ws')
    def test_limite_likes_da_429(self, mock_notif, client_a, user_a, user_b, user_c, db):
        # Agotar likes manualmente
        from django.utils import timezone
        LikeDiario.objects.create(
            usuario=user_a, modo=Modo.PAREJA,
            fecha=timezone.localdate(), cantidad=LIKES_DIARIOS[Modo.PAREJA]
        )
        resp = client_a.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_b.id, 'modo': Modo.PAREJA, 'accion': Accion.LIKE,
        })
        assert resp.status_code == 429


# ── Tests: Bandeja y Respuestas ───────────────────────────────────
class TestBandejaRespuestas:
    @patch('modules.matching.views.enviar_notificacion_ws')
    def test_bandeja_muestra_likes_recibidos(self, mock_notif, client_a, client_b, user_a, user_b, db):
        # B le da like a A
        client_b.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_a.id, 'modo': Modo.PAREJA, 'accion': Accion.LIKE,
        })
        # A ve su bandeja
        resp = client_a.get('/api/v1/matching/bandeja/?modo=pareja')
        assert resp.status_code == 200
        assert resp.data['total'] == 1
        assert resp.data['likes'][0]['de_usuario']['id'] == user_b.id

    @patch('modules.matching.views.enviar_notificacion_ws')
    def test_aceptar_like_crea_match(self, mock_notif, client_a, client_b, user_a, user_b, db):
        client_b.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_a.id, 'modo': Modo.PAREJA, 'accion': Accion.LIKE,
        })
        like = SwipeAction.objects.get(de_usuario=user_b, a_usuario=user_a)
        resp = client_a.post(f'/api/v1/matching/responder/{like.id}/', {'respuesta': 'aceptar'})
        assert resp.status_code == 200
        assert resp.data['resultado'] == 'match_creado'
        assert Match.objects.filter(modo=Modo.PAREJA).exists()

    @patch('modules.matching.views.enviar_notificacion_ws')
    def test_rechazar_like_crea_bloqueo_bidireccional(self, mock_notif, client_a, client_b, user_a, user_b, db):
        client_b.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_a.id, 'modo': Modo.PAREJA, 'accion': Accion.LIKE,
        })
        like = SwipeAction.objects.get(de_usuario=user_b, a_usuario=user_a)
        resp = client_a.post(f'/api/v1/matching/responder/{like.id}/', {'respuesta': 'rechazar'})
        assert resp.status_code == 200
        assert Bloqueo.objects.filter(bloqueador=user_a, bloqueado=user_b).exists()
        assert Bloqueo.objects.filter(bloqueador=user_b, bloqueado=user_a).exists()

    @patch('modules.matching.views.enviar_notificacion_ws')
    def test_contrapropuesta_solo_para_pareja(self, mock_notif, client_a, client_b, user_a, user_b, db):
        # Like de amistad → no permite contrapropuesta
        client_b.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_a.id, 'modo': Modo.AMISTAD, 'accion': Accion.LIKE,
        })
        like = SwipeAction.objects.get(de_usuario=user_b, a_usuario=user_a, modo=Modo.AMISTAD)
        resp = client_a.post(f'/api/v1/matching/responder/{like.id}/',
                             {'respuesta': 'contrapropuesta'})
        assert resp.status_code == 400

    @patch('modules.matching.views.enviar_notificacion_ws')
    def test_contrapropuesta_pareja_a_amistad(self, mock_notif, client_a, client_b, user_a, user_b, db):
        client_b.post('/api/v1/matching/swipe/', {
            'a_usuario_id': user_a.id, 'modo': Modo.PAREJA, 'accion': Accion.LIKE,
        })
        like = SwipeAction.objects.get(de_usuario=user_b, a_usuario=user_a, modo=Modo.PAREJA)
        resp = client_a.post(f'/api/v1/matching/responder/{like.id}/',
                             {'respuesta': 'contrapropuesta'})
        assert resp.status_code == 200
        assert Contrapropuesta.objects.filter(
            like_original=like, modo_propuesto=Modo.AMISTAD
        ).exists()


# ── Tests: Expiración ─────────────────────────────────────────────
class TestExpiracion:
    def test_likes_expirados_se_marcan(self, user_a, user_b, db):
        from datetime import timedelta
        from django.utils import timezone

        # Crear like ya expirado
        like = SwipeAction.objects.create(
            de_usuario=user_a, a_usuario=user_b,
            modo=Modo.PAREJA, accion=Accion.LIKE,
            estado=EstadoLike.PENDIENTE,
            expira_en=timezone.now() - timedelta(hours=1),
        )
        n = expirar_likes_vencidos()
        assert n >= 1
        like.refresh_from_db()
        assert like.estado == EstadoLike.EXPIRADO
