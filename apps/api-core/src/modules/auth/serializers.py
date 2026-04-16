from rest_framework import serializers


class GoogleLoginSerializer(serializers.Serializer):
    id_token = serializers.CharField(
        help_text='Firebase ID Token obtenido después del Google Sign-In en el cliente'
    )


class MFAVerifySerializer(serializers.Serializer):
    mfa_token = serializers.CharField()
    codigo    = serializers.CharField(min_length=6, max_length=8)


class MFAActivateSerializer(serializers.Serializer):
    codigo = serializers.CharField(min_length=6, max_length=6)


class CompletarPerfilSerializer(serializers.Serializer):
    nombre    = serializers.CharField(max_length=120, required=False)
    carrera   = serializers.CharField(max_length=120)
    facultad  = serializers.CharField(max_length=120, required=False, default='')
    semestre  = serializers.IntegerField(min_value=1, max_value=12)
    bio       = serializers.CharField(max_length=300, required=False, default='', allow_blank=True)
    intereses = serializers.ListField(
        child=serializers.CharField(max_length=60),
        required=False, default=list, max_length=20,
    )
