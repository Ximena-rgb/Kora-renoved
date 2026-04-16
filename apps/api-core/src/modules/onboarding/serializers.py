from datetime import date
from django.utils import timezone
from rest_framework import serializers
from .constants import (
    EDAD_MINIMA, MAX_FOTOS, MIN_FOTOS, MAX_GUSTOS,
    MAX_HABILIDADES, MAX_DEBILIDADES, MAX_IDIOMAS,
    GENERO_CHOICES, ORIENTACION_CHOICES, INTERESADO_EN_CHOICES,
    HABITO_CHOICES, FIESTA_CHOICES, HIJOS_CHOICES,
    ACTIVIDAD_CHOICES, GUSTA_CARRERA_CHOICES, TRABAJO_PREF_CHOICES,
    INTENCION_CHOICES,
)
from .models import UserProfile, UserPhoto


class OnboardingEstadoSerializer(serializers.ModelSerializer):
    edad             = serializers.IntegerField(read_only=True)
    fotos_aprobadas  = serializers.SerializerMethodField()
    fotos_pendientes = serializers.SerializerMethodField()

    class Meta:
        model  = UserProfile
        fields = ['onboarding_paso', 'terminos_aceptados', 'edad',
                  'fotos_aprobadas', 'fotos_pendientes']

    def get_fotos_aprobadas(self, obj):
        return obj.user.fotos.filter(estado='approved').count()

    def get_fotos_pendientes(self, obj):
        return obj.user.fotos.filter(estado='pending').count()


class TerminosSerializer(serializers.Serializer):
    acepto_terminos = serializers.BooleanField()
    acepto_datos    = serializers.BooleanField()

    def validate(self, data):
        if not data['acepto_terminos']:
            raise serializers.ValidationError(
                'Debes aceptar los términos y condiciones para continuar.')
        if not data['acepto_datos']:
            raise serializers.ValidationError(
                'Debes aceptar el tratamiento de datos personales para continuar.')
        return data


class BasicoSerializer(serializers.Serializer):
    nombre           = serializers.CharField(max_length=120)
    apellido         = serializers.CharField(max_length=120)
    fecha_nacimiento = serializers.DateField(input_formats=['%Y-%m-%d', '%d/%m/%Y'])
    genero               = serializers.ChoiceField(choices=[c[0] for c in GENERO_CHOICES])
    genero_personalizado = serializers.CharField(max_length=60, required=False, default='', allow_blank=True)

    def validate_fecha_nacimiento(self, value):
        hoy   = timezone.now().date()
        years = hoy.year - value.year
        if (hoy.month, hoy.day) < (value.month, value.day):
            years -= 1
        if years < EDAD_MINIMA:
            raise serializers.ValidationError(
                f'Debes tener al menos {EDAD_MINIMA} años. Actualmente tienes {years} años.')
        if value > hoy:
            raise serializers.ValidationError('La fecha no puede ser en el futuro.')
        if years > 100:
            raise serializers.ValidationError('Por favor verifica tu fecha de nacimiento.')
        return value

    def validate(self, data):
        if data.get('genero') == 'otro' and not data.get('genero_personalizado'):
            raise serializers.ValidationError(
                {'genero_personalizado': 'Por favor especifica tu género.'})
        return data


class IntencionesSerializer(serializers.Serializer):
    intenciones = serializers.ListField(
        child=serializers.ChoiceField(choices=[c[0] for c in INTENCION_CHOICES]),
        min_length=1,
        max_length=3,
    )

    def validate_intenciones(self, value):
        validas = {'pareja', 'amistad', 'estudio'}
        invalidas = set(value) - validas
        if invalidas:
            raise serializers.ValidationError(f'Inválidas: {invalidas}')
        return list(dict.fromkeys(value))


class PreferenciasSerializer(serializers.Serializer):
    orientacion_sexual = serializers.ChoiceField(
        choices=[c[0] for c in ORIENTACION_CHOICES],
        required=False, allow_blank=True, default='',
    )
    interesado_en_pareja = serializers.ListField(
        child=serializers.ChoiceField(choices=[c[0] for c in INTERESADO_EN_CHOICES]),
        required=False, default=list,
    )
    interesado_en_amistad = serializers.ListField(
        child=serializers.ChoiceField(choices=[c[0] for c in INTERESADO_EN_CHOICES]),
        required=False, default=list,
    )

    def validate(self, data):
        request = self.context.get('request')
        if not request:
            return data
        try:
            profile = request.user.profile
        except Exception:
            return data
        intenciones = profile.intenciones
        if 'pareja' in intenciones:
            if not data.get('orientacion_sexual'):
                raise serializers.ValidationError(
                    {'orientacion_sexual': 'Requerido cuando buscas pareja.'})
            if not data.get('interesado_en_pareja'):
                raise serializers.ValidationError(
                    {'interesado_en_pareja': 'Indica qué género te interesa.'})
        if 'amistad' in intenciones and not data.get('interesado_en_amistad'):
            data['interesado_en_amistad'] = ['todos']
        return data


class PersonalSerializer(serializers.Serializer):
    bio_larga       = serializers.CharField(required=False, default='', allow_blank=True)
    bio_corta       = serializers.CharField(max_length=100, required=False, default='', allow_blank=True)
    gustos          = serializers.ListField(
        child=serializers.CharField(max_length=60),
        required=False, default=list, max_length=MAX_GUSTOS)
    tiempo_libre    = serializers.CharField(max_length=300, required=False, default='', allow_blank=True)
    fuma            = serializers.ChoiceField(choices=[c[0] for c in HABITO_CHOICES], required=False, default='no')
    bebe            = serializers.ChoiceField(choices=[c[0] for c in HABITO_CHOICES], required=False, default='no')
    sale_fiesta     = serializers.ChoiceField(choices=[c[0] for c in FIESTA_CHOICES], required=False, default='no')
    animales_gustan = serializers.BooleanField(required=False, default=False)
    tiene_animales  = serializers.BooleanField(required=False, default=False)
    cuales_animales = serializers.CharField(max_length=200, required=False, default='', allow_blank=True)
    idiomas         = serializers.ListField(
        child=serializers.CharField(max_length=60), required=False, default=list, max_length=MAX_IDIOMAS)
    hijos           = serializers.ChoiceField(
        choices=[c[0] for c in HIJOS_CHOICES], required=False, default='prefiero_no_decir')
    signo_zodiacal  = serializers.CharField(max_length=12, required=False, default='', allow_blank=True)
    nivel_actividad = serializers.ChoiceField(
        choices=[c[0] for c in ACTIVIDAD_CHOICES], required=False, default='moderado')

    def validate(self, data):
        if data.get('tiene_animales') and not data.get('cuales_animales'):
            raise serializers.ValidationError(
                {'cuales_animales': '¿Cuáles animales tienes?'})
        return data


class InstitucionalSerializer(serializers.Serializer):
    facultad            = serializers.CharField(max_length=120)
    carrera             = serializers.CharField(max_length=120)
    semestre            = serializers.IntegerField(min_value=1, max_value=12)
    gusta_carrera       = serializers.ChoiceField(
        choices=[c[0] for c in GUSTA_CARRERA_CHOICES], required=False, default='esta_ok')
    proyeccion          = serializers.CharField(max_length=300, required=False, default='', allow_blank=True)
    habilidades         = serializers.ListField(
        child=serializers.CharField(max_length=60), required=False, default=list, max_length=MAX_HABILIDADES)
    debilidades         = serializers.ListField(
        child=serializers.CharField(max_length=60), required=False, default=list, max_length=MAX_DEBILIDADES)
    busca_tesis         = serializers.BooleanField(required=False, default=False)
    trabajo_preferencia = serializers.ChoiceField(
        choices=[c[0] for c in TRABAJO_PREF_CHOICES], required=False, default='ambos')
    disponibilidad      = serializers.ListField(
        child=serializers.DictField(), required=False, default=list)

    def validate_disponibilidad(self, value):
        dias_validos = {'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo'}
        for bloque in value:
            if not isinstance(bloque, dict):
                raise serializers.ValidationError('Cada bloque debe ser un objeto.')
            if bloque.get('dia', '').lower() not in dias_validos:
                raise serializers.ValidationError(f'Día inválido: {bloque.get("dia")}')
            for campo in ('inicio', 'fin'):
                val = bloque.get(campo, '')
                try:
                    h, m = val.split(':')
                    assert 0 <= int(h) <= 23 and 0 <= int(m) <= 59
                except Exception:
                    raise serializers.ValidationError(f'Formato inválido en {campo}: usa HH:MM')
        return value


class FotoUploadSerializer(serializers.Serializer):
    foto         = serializers.ImageField()
    es_principal = serializers.BooleanField(required=False, default=False)


class FotoResponseSerializer(serializers.ModelSerializer):
    class Meta:
        model  = UserPhoto
        fields = ['id', 'url_original', 'url_medium', 'url_thumb',
                  'es_principal', 'orden', 'estado', 'rechazo_motivo', 'created_at']
