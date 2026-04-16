from rest_framework import serializers
from modules.user.serializers import UserPublicSerializer
from .models import Plan, Participante


class ParticipanteSerializer(serializers.ModelSerializer):
    usuario = UserPublicSerializer(read_only=True)

    class Meta:
        model  = Participante
        fields = ['id', 'usuario', 'estado', 'hora_checkin', 'fue_puntual', 'joined_at']


class PlanListSerializer(serializers.ModelSerializer):
    creador             = UserPublicSerializer(read_only=True)
    participantes_count = serializers.SerializerMethodField()
    esta_lleno          = serializers.SerializerMethodField()
    ya_asisto           = serializers.SerializerMethodField()
    puede_checkin       = serializers.BooleanField(read_only=True)
    hora_fin            = serializers.DateTimeField(read_only=True)
    tipo_display        = serializers.CharField(source='get_tipo_display', read_only=True)

    class Meta:
        model  = Plan
        fields = [
            'id', 'tipo', 'tipo_display', 'titulo', 'descripcion',
            'ubicacion', 'campus_zona', 'foto_url',
            'hora_inicio', 'hora_fin', 'duracion_min',
            'max_personas', 'participantes_count', 'esta_lleno',
            'estado', 'tags', 'es_publico',
            'creador', 'ya_asisto', 'puede_checkin', 'created_at',
        ]

    def get_participantes_count(self, obj):
        return obj.participantes.filter(estado__in=['confirmado', 'asistio']).count()

    def get_esta_lleno(self, obj):
        return obj.esta_lleno

    def get_ya_asisto(self, obj):
        request = self.context.get('request')
        if not request:
            return False
        return obj.participantes.filter(
            usuario=request.user, estado__in=['confirmado', 'asistio']
        ).exists()


class PlanDetailSerializer(PlanListSerializer):
    participantes = serializers.SerializerMethodField()

    class Meta(PlanListSerializer.Meta):
        fields = PlanListSerializer.Meta.fields + ['participantes']

    def get_participantes(self, obj):
        qs = obj.participantes.filter(
            estado__in=['confirmado', 'asistio']
        ).select_related('usuario')
        return ParticipanteSerializer(qs, many=True).data


class CreatePlanSerializer(serializers.ModelSerializer):
    class Meta:
        model  = Plan
        fields = [
            'tipo', 'titulo', 'descripcion', 'ubicacion', 'campus_zona',
            'hora_inicio', 'duracion_min', 'max_personas', 'tags',
            'es_publico', 'match_origen',
        ]

    def validate_max_personas(self, value):
        if value < 2:
            raise serializers.ValidationError('Minimo 2 personas.')
        if value > 50:
            raise serializers.ValidationError('Maximo 50 personas.')
        return value

    def validate(self, data):
        from django.utils import timezone
        if data.get('hora_inicio') and data['hora_inicio'] <= timezone.now():
            raise serializers.ValidationError(
                {'hora_inicio': 'El plan debe ser en el futuro.'})
        return data
