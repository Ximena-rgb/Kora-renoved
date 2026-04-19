from rest_framework import serializers
from .models import Facultad, Programa


class ProgramaSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Programa
        fields = ('id', 'nombre', 'nivel')


class FacultadSerializer(serializers.ModelSerializer):
    programas = ProgramaSerializer(many=True, read_only=True,
                                   source='programas.filter')

    class Meta:
        model  = Facultad
        fields = ('id', 'nombre', 'slug', 'programas')

    def to_representation(self, instance):
        data = super().to_representation(instance)
        # filtrar solo programas activos
        data['programas'] = ProgramaSerializer(
            instance.programas.filter(activo=True), many=True).data
        return data
