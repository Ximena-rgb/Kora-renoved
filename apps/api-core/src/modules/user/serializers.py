from rest_framework import serializers
from .models import User


class UserPublicSerializer(serializers.ModelSerializer):
    class Meta:
        model  = User
        fields = [
            'id', 'nombre', 'foto_url', 'carrera', 'facultad',
            'semestre', 'bio', 'intereses', 'campus_zona',
            'disponible', 'reputacion', 'total_ratings',
        ]
        read_only_fields = fields


class UserPrivateSerializer(serializers.ModelSerializer):
    class Meta:
        model  = User
        fields = [
            'id', 'email', 'nombre', 'foto_url',
            'carrera', 'facultad', 'semestre', 'bio', 'intereses',
            'campus_zona', 'disponible', 'horarios',
            'reputacion', 'total_ratings',
            'mfa_activo', 'perfil_completo',
            'created_at',
        ]
        read_only_fields = [
            'id', 'email', 'reputacion', 'total_ratings',
            'mfa_activo', 'created_at',
        ]


class UpdateProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model  = User
        fields = ['nombre', 'bio', 'intereses', 'carrera', 'facultad', 'semestre', 'campus_zona', 'horarios']


class UpdateDisponibilidadSerializer(serializers.Serializer):
    disponible  = serializers.BooleanField()
    campus_zona = serializers.CharField(max_length=80, required=False, default='')


class NearbyUsersQuerySerializer(serializers.Serializer):
    zona     = serializers.CharField(max_length=80,  required=False)
    facultad = serializers.CharField(max_length=120, required=False)
    carrera  = serializers.CharField(max_length=120, required=False)
