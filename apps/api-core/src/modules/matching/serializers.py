"""
modules/matching/serializers.py
================================
Serializers del motor de matching.
"""
from rest_framework import serializers
from django.contrib.auth import get_user_model

from .constants import Modo, Accion, EstadoMatch
from .models import Match, DuplaDos, SwipeAction

User = get_user_model()


# ── Candidato en el deck ──────────────────────────────────────────
class CandidatoSerializer(serializers.Serializer):
    """Perfil resumido de un candidato para el deck de swipe."""
    id          = serializers.IntegerField(source='usuario.id')
    nombre      = serializers.CharField(source='usuario.nombre')
    foto_url    = serializers.URLField(source='usuario.foto_url')
    carrera     = serializers.CharField(source='usuario.carrera')
    facultad    = serializers.CharField(source='usuario.facultad')
    semestre    = serializers.IntegerField(source='usuario.semestre')
    reputacion  = serializers.FloatField(source='usuario.reputacion')

    # Del perfil extendido
    bio_corta       = serializers.SerializerMethodField()
    gustos          = serializers.SerializerMethodField()
    edad            = serializers.SerializerMethodField()
    fotos           = serializers.SerializerMethodField()

    # Score de compatibilidad
    score_total         = serializers.FloatField()
    score_intenciones   = serializers.FloatField()
    score_intereses     = serializers.FloatField()
    score_estilo_vida   = serializers.FloatField()
    score_carrera       = serializers.FloatField()
    score_horarios      = serializers.FloatField()

    def get_bio_corta(self, obj):
        profile = getattr(obj['usuario'], 'profile', None)
        return getattr(profile, 'bio_corta', '') if profile else ''

    def get_gustos(self, obj):
        profile = getattr(obj['usuario'], 'profile', None)
        return getattr(profile, 'gustos', [])[:8] if profile else []

    def get_edad(self, obj):
        profile = getattr(obj['usuario'], 'profile', None)
        return getattr(profile, 'edad', None) if profile else None

    def get_fotos(self, obj):
        fotos = obj['usuario'].fotos.filter(estado='approved').order_by('orden')[:5]
        return [{'id': f.id, 'url': f.url_medium or f.url_original,
                 'thumb': f.url_thumb, 'es_principal': f.es_principal}
                for f in fotos]


class DeckSerializer(CandidatoSerializer):
    pass


# ── Swipe ─────────────────────────────────────────────────────────
class SwipeSerializer(serializers.Serializer):
    a_usuario_id = serializers.IntegerField()
    modo         = serializers.ChoiceField(choices=[m[0] for m in Modo.CHOICES
                                                    if m[0] != Modo.DOS_PA_DOS])
    accion       = serializers.ChoiceField(choices=[a[0] for a in Accion.CHOICES])
    es_superlike = serializers.BooleanField(required=False, default=False)

    def validate(self, data):
        if data.get('es_superlike') and data.get('accion') == Accion.PASS:
            raise serializers.ValidationError('No puedes hacer Super Like con un pass.')
        if data.get('es_superlike'):
            data['accion'] = Accion.SUPERLIKE
        return data


# ── Responder like ────────────────────────────────────────────────
class ResponderLikeSerializer(serializers.Serializer):
    respuesta = serializers.ChoiceField(choices=['aceptar', 'rechazar', 'contrapropuesta'])


# ── Match ─────────────────────────────────────────────────────────
class MatchSerializer(serializers.ModelSerializer):
    otro_usuario     = serializers.SerializerMethodField()
    conversacion_id  = serializers.IntegerField()
    score            = serializers.FloatField()

    class Meta:
        model  = Match
        fields = ['id', 'modo', 'score', 'estado', 'conversacion_id',
                  'otro_usuario', 'created_at']

    def get_otro_usuario(self, obj):
        request = self.context.get('request')
        if not request:
            return None
        otro = obj.get_otro_usuario(request.user)
        if not otro:
            # Sin request context — devolver ambos
            return {'usuario_1_id': obj.usuario_1_id, 'usuario_2_id': obj.usuario_2_id}
        profile = getattr(otro, 'profile', None)
        return {
            'id':       otro.id,
            'nombre':   otro.nombre,
            'foto_url': otro.foto_url,
            'carrera':  otro.carrera,
            'bio_corta': getattr(profile, 'bio_corta', '') if profile else '',
        }


# ── Dupla 2pa2 ────────────────────────────────────────────────────
class DuplaDosSerializer(serializers.ModelSerializer):
    user_1_info = serializers.SerializerMethodField()
    user_2_info = serializers.SerializerMethodField()

    class Meta:
        model  = DuplaDos
        fields = ['id', 'estado', 'pref_user_1', 'pref_user_2',
                  'user_1_info', 'user_2_info', 'created_at']

    def _user_info(self, user):
        if not user:
            return None
        return {
            'id': user.id, 'nombre': user.nombre,
            'foto_url': user.foto_url, 'carrera': user.carrera,
        }

    def get_user_1_info(self, obj):
        return self._user_info(obj.user_1)

    def get_user_2_info(self, obj):
        return self._user_info(obj.user_2)


# ── Crear dupla ───────────────────────────────────────────────────
class CrearDuplaSerializer(serializers.Serializer):
    amigo_id       = serializers.IntegerField()
    mi_preferencia = serializers.ChoiceField(
        choices=['hombres', 'mujeres', 'otros', 'todos', ''],
        required=False, default='', allow_blank=True,
    )


# ── Responder match 2pa2 ──────────────────────────────────────────
class ResponderMatch2pa2Serializer(serializers.Serializer):
    aceptar = serializers.BooleanField()
