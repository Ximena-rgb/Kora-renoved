"""
modules/onboarding/views.py
============================
Endpoints del onboarding secuencial.

Cada endpoint valida que el usuario esté en el paso correcto
antes de procesar. El estado avanza automáticamente al completar.
"""

import logging
import os
import uuid

from django.conf import settings as django_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from shared.audit import audit
from shared.broker import broker

from .constants import PasoOnboarding, MIN_FOTOS, MAX_FOTOS
from .models import UserProfile, UserPhoto
from .serializers import (
    OnboardingEstadoSerializer,
    TerminosSerializer, BasicoSerializer, IntencionesSerializer,
    PreferenciasSerializer, PersonalSerializer, InstitucionalSerializer,
    FotoUploadSerializer, FotoResponseSerializer,
)

logger = logging.getLogger(__name__)


# ── Helper: obtener o crear profile ──────────────────────────────
def _get_or_create_profile(user) -> UserProfile:
    profile, _ = UserProfile.objects.get_or_create(user=user)
    return profile


# ── Helper: verificar paso ────────────────────────────────────────
def _verificar_paso(profile: UserProfile, paso_esperado: str) -> Response | None:
    """
    Retorna un Response de error si el usuario no está en el paso correcto.
    Retorna None si puede continuar.
    """
    if profile.onboarding_completo:
        return Response(
            {'error': 'El onboarding ya fue completado.'},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if profile.onboarding_paso != paso_esperado:
        return Response(
            {
                'error': f'Paso incorrecto. Estás en: {profile.onboarding_paso}',
                'paso_actual': profile.onboarding_paso,
                'paso_esperado': paso_esperado,
            },
            status=status.HTTP_400_BAD_REQUEST,
        )
    return None


# ─────────────────────────────────────────────────────────────────
# GET /onboarding/estado/
# ─────────────────────────────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def estado(request):
    """Devuelve el paso actual del onboarding y datos de progreso."""
    profile = _get_or_create_profile(request.user)
    return Response(OnboardingEstadoSerializer(profile).data)


# ─────────────────────────────────────────────────────────────────
# POST /onboarding/terminos/
# ─────────────────────────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def terminos(request):
    """
    Paso 1: Aceptar términos y condiciones + tratamiento de datos.
    Body: { "acepto_terminos": true, "acepto_datos": true }
    """
    profile = _get_or_create_profile(request.user)
    err = _verificar_paso(profile, PasoOnboarding.TERMINOS)
    if err:
        return err

    s = TerminosSerializer(data=request.data)
    s.is_valid(raise_exception=True)

    profile.terminos_aceptados = True
    profile.terminos_fecha     = timezone.now()
    profile.onboarding_paso    = PasoOnboarding.BASICO
    profile.save(update_fields=['terminos_aceptados', 'terminos_fecha', 'onboarding_paso'])

    audit.log(request, 'TERMINOS_ACEPTADOS', {'user_id': request.user.id})

    return Response({
        'mensaje':    'Términos aceptados ✅',
        'siguiente':  PasoOnboarding.BASICO,
    })


# ─────────────────────────────────────────────────────────────────
# POST /onboarding/basico/
# ─────────────────────────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def basico(request):
    """
    Paso 2: Información básica.
    Valida que el usuario sea mayor de 18 años.
    Body: { nombre, apellido, fecha_nacimiento, genero, genero_personalizado? }
    """
    profile = _get_or_create_profile(request.user)
    err = _verificar_paso(profile, PasoOnboarding.BASICO)
    if err:
        return err

    s = BasicoSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    data = s.validated_data

    # Actualizar User.nombre si viene
    user = request.user
    if data.get('nombre') and user.nombre != data['nombre']:
        user.nombre = data['nombre']
        user.save(update_fields=['nombre'])

    # Actualizar perfil
    profile.apellido             = data['apellido']
    profile.fecha_nacimiento     = data['fecha_nacimiento']
    profile.genero               = data['genero']
    profile.genero_personalizado = data.get('genero_personalizado', '')
    profile.onboarding_paso      = PasoOnboarding.INTENCIONES
    profile.save(update_fields=[
        'apellido', 'fecha_nacimiento', 'genero',
        'genero_personalizado', 'onboarding_paso',
    ])

    return Response({
        'mensaje':   'Información básica guardada ✅',
        'edad':      profile.edad,
        'siguiente': PasoOnboarding.INTENCIONES,
    })


# ─────────────────────────────────────────────────────────────────
# POST /onboarding/intenciones/
# ─────────────────────────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def intenciones(request):
    """
    Paso 3: Qué busca el usuario.
    Body: { "intenciones": ["pareja", "amistad", "estudio"] }
    Puede seleccionar de 1 a 3 opciones.
    """
    profile = _get_or_create_profile(request.user)
    err = _verificar_paso(profile, PasoOnboarding.INTENCIONES)
    if err:
        return err

    s = IntencionesSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    data = s.validated_data

    profile.intenciones     = data['intenciones']
    profile.onboarding_paso = PasoOnboarding.PREFERENCIAS
    profile.save(update_fields=['intenciones', 'onboarding_paso'])

    # Si solo busca estudio → saltar preferencias de pareja/amistad
    solo_estudio = profile.intenciones == ['estudio']

    return Response({
        'mensaje':         'Intenciones guardadas ✅',
        'intenciones':     profile.intenciones,
        'siguiente':       PasoOnboarding.PREFERENCIAS,
        'saltar_siguiente': solo_estudio,
        'nota': 'Si solo buscas grupos de estudio, puedes enviar preferencias vacías.' if solo_estudio else None,
    })


# ─────────────────────────────────────────────────────────────────
# POST /onboarding/preferencias/
# ─────────────────────────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def preferencias(request):
    """
    Paso 4: Preferencias de pareja y/o amistad.
    Si solo busca estudio → enviar body vacío {} para avanzar.
    """
    profile = _get_or_create_profile(request.user)
    err = _verificar_paso(profile, PasoOnboarding.PREFERENCIAS)
    if err:
        return err

    s = PreferenciasSerializer(data=request.data, context={'request': request})
    s.is_valid(raise_exception=True)
    data = s.validated_data

    profile.orientacion_sexual    = data.get('orientacion_sexual', '')
    profile.interesado_en_pareja  = data.get('interesado_en_pareja', [])
    profile.interesado_en_amistad = data.get('interesado_en_amistad', [])
    profile.onboarding_paso       = PasoOnboarding.PERSONAL
    profile.save(update_fields=[
        'orientacion_sexual', 'interesado_en_pareja',
        'interesado_en_amistad', 'onboarding_paso',
    ])

    return Response({
        'mensaje':   'Preferencias guardadas ✅',
        'siguiente': PasoOnboarding.PERSONAL,
    })


# ─────────────────────────────────────────────────────────────────
# POST /onboarding/personal/
# ─────────────────────────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def personal(request):
    """
    Paso 5: Preferencias personales (bio, gustos, hábitos).
    Todos los campos son opcionales pero se recomienda completar.
    """
    profile = _get_or_create_profile(request.user)
    err = _verificar_paso(profile, PasoOnboarding.PERSONAL)
    if err:
        return err

    s = PersonalSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    data = s.validated_data

    profile.bio_larga       = data.get('bio_larga', '')
    profile.bio_corta       = data.get('bio_corta', '')
    profile.gustos          = data.get('gustos', [])
    profile.tiempo_libre    = data.get('tiempo_libre', '')
    profile.fuma            = data.get('fuma', 'no')
    profile.bebe            = data.get('bebe', 'no')
    profile.sale_fiesta     = data.get('sale_fiesta', 'no')
    profile.animales_gustan = data.get('animales_gustan', False)
    profile.tiene_animales  = data.get('tiene_animales', False)
    profile.cuales_animales = data.get('cuales_animales', '')
    profile.idiomas         = data.get('idiomas', [])
    profile.hijos           = data.get('hijos', 'prefiero_no_decir')
    profile.signo_zodiacal  = data.get('signo_zodiacal', '')
    profile.nivel_actividad = data.get('nivel_actividad', 'moderado')
    profile.onboarding_paso = PasoOnboarding.INSTITUCIONAL
    profile.save()

    return Response({
        'mensaje':   'Preferencias personales guardadas ✅',
        'siguiente': PasoOnboarding.INSTITUCIONAL,
    })


# ─────────────────────────────────────────────────────────────────
# POST /onboarding/institucional/
# ─────────────────────────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def institucional(request):
    """
    Paso 6: Información académica e institucional.
    """
    profile = _get_or_create_profile(request.user)
    err = _verificar_paso(profile, PasoOnboarding.INSTITUCIONAL)
    if err:
        return err

    s = InstitucionalSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    data = s.validated_data

    profile.facultad            = data['facultad']
    profile.carrera             = data['carrera']
    profile.semestre            = data['semestre']
    profile.gusta_carrera       = data.get('gusta_carrera', 'esta_ok')
    profile.proyeccion          = data.get('proyeccion', '')
    profile.habilidades         = data.get('habilidades', [])
    profile.debilidades         = data.get('debilidades', [])
    profile.busca_tesis         = data.get('busca_tesis', False)
    profile.trabajo_preferencia = data.get('trabajo_preferencia', 'ambos')
    profile.disponibilidad      = data.get('disponibilidad', [])
    profile.onboarding_paso     = PasoOnboarding.FOTOS
    profile.save()

    # Sincronizar con User para el matching engine
    user = request.user
    user.carrera  = data['carrera']
    user.facultad = data['facultad']
    user.semestre = data['semestre']
    user.horarios = data.get('disponibilidad', [])
    user.save(update_fields=['carrera', 'facultad', 'semestre', 'horarios'])

    return Response({
        'mensaje':   'Información institucional guardada ✅',
        'siguiente': PasoOnboarding.FOTOS,
    })


# ─────────────────────────────────────────────────────────────────
# POST /onboarding/fotos/
# ─────────────────────────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def subir_foto(request):
    """
    Paso 7: Subir foto de perfil (una a la vez).
    - Mínimo 2 fotos aprobadas para completar
    - Máximo 5 fotos en total
    - La primera foto se marca automáticamente como principal
    - Publica IMAGE_PROCESS_TASK al broker → api-media la procesa
    """
    profile = _get_or_create_profile(request.user)

    # Permitir subir fotos en paso FOTOS o si ya está en COMPLETO (editar perfil)
    if profile.onboarding_paso not in (PasoOnboarding.FOTOS, PasoOnboarding.COMPLETO):
        return Response(
            {
                'error': f'Completa primero el paso: {profile.onboarding_paso}',
                'paso_actual': profile.onboarding_paso,
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Límite máximo de fotos
    total_fotos = request.user.fotos.exclude(estado='rejected').count()
    if total_fotos >= MAX_FOTOS:
        return Response(
            {'error': f'Máximo {MAX_FOTOS} fotos permitidas. Elimina una antes de subir otra.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    s = FotoUploadSerializer(data=request.data)
    s.is_valid(raise_exception=True)

    archivo = s.validated_data['foto']
    es_principal = s.validated_data.get('es_principal', False)

    # Si no tiene fotos aún, la primera es la principal automáticamente
    if not request.user.fotos.exists():
        es_principal = True

    # Guardar archivo temporal
    ext      = os.path.splitext(archivo.name)[1].lower() or '.jpg'
    filename = f'{uuid.uuid4()}{ext}'
    tmp_dir  = os.path.join(django_settings.MEDIA_ROOT, 'profiles', 'tmp')
    os.makedirs(tmp_dir, exist_ok=True)
    tmp_path = os.path.join(tmp_dir, filename)

    with open(tmp_path, 'wb') as f:
        for chunk in archivo.chunks():
            f.write(chunk)

    # Calcular orden
    orden = request.user.fotos.count()

    # Si esta va a ser principal, desmarcar las demás
    if es_principal:
        request.user.fotos.filter(es_principal=True).update(es_principal=False)

    # Crear registro de foto en estado 'pending'
    foto = UserPhoto.objects.create(
        user         = request.user,
        tmp_path     = tmp_path,
        es_principal = es_principal,
        orden        = orden,
        estado       = 'pending',
    )

    # Publicar al broker → api-media la procesa (Sharp + NSFW)
    # Obtener género del perfil para validación de coincidencia
    genero_usuario = ''
    try:
        profile_obj = _get_or_create_profile(request.user)
        genero_usuario = profile_obj.genero or ''
    except Exception:
        pass

    broker.publish('IMAGE_PROCESS_TASK', {
        'user_id':        request.user.id,
        'foto_id':        foto.id,
        'tipo':           'profile',
        'tmp_path':       tmp_path,
        'filename':       filename,
        'genero_usuario': genero_usuario,
    })

    audit.log(request, audit.IMAGE_UPLOADED, {'foto_id': foto.id, 'filename': filename})

    return Response(
        FotoResponseSerializer(foto).data,
        status=status.HTTP_202_ACCEPTED,
    )


# ─────────────────────────────────────────────────────────────────
# DELETE /onboarding/fotos/<foto_id>/
# ─────────────────────────────────────────────────────────────────
@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def eliminar_foto(request, foto_id):
    """Elimina una foto del perfil."""
    try:
        foto = UserPhoto.objects.get(pk=foto_id, user=request.user)
    except UserPhoto.DoesNotExist:
        return Response({'error': 'Foto no encontrada.'}, status=status.HTTP_404_NOT_FOUND)

    era_principal = foto.es_principal
    foto.delete()

    # Si era la principal, asignar la siguiente aprobada como principal
    if era_principal:
        primera = request.user.fotos.filter(estado='approved').first()
        if primera:
            primera.es_principal = True
            primera.save(update_fields=['es_principal'])

    # Reordenar
    for i, f in enumerate(request.user.fotos.order_by('orden')):
        if f.orden != i:
            f.orden = i
            f.save(update_fields=['orden'])

    return Response({'mensaje': 'Foto eliminada.'})


# ─────────────────────────────────────────────────────────────────
# GET /onboarding/fotos/
# ─────────────────────────────────────────────────────────────────
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def listar_fotos(request):
    """Lista todas las fotos del usuario con su estado."""
    fotos = request.user.fotos.all()
    return Response(FotoResponseSerializer(fotos, many=True).data)


# ─────────────────────────────────────────────────────────────────
# POST /onboarding/completar/
# ─────────────────────────────────────────────────────────────────
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def completar(request):
    """
    Paso final: valida que todo esté completo y finaliza el onboarding.
    Requiere mínimo 2 fotos aprobadas.
    """
    profile = _get_or_create_profile(request.user)

    if profile.onboarding_completo:
        return Response(
            {'error': 'El onboarding ya fue completado anteriormente.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if profile.onboarding_paso != PasoOnboarding.FOTOS:
        return Response(
            {
                'error': f'Aún no has completado todos los pasos. Paso actual: {profile.onboarding_paso}',
                'paso_actual': profile.onboarding_paso,
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Verificar fotos mínimas aprobadas
    fotos_aprobadas = request.user.fotos.filter(estado='approved').count()
    fotos_pendientes = request.user.fotos.filter(estado='pending').count()

    if fotos_aprobadas < MIN_FOTOS:
        if fotos_pendientes > 0:
            return Response(
                {
                    'error': f'Tus fotos aún están siendo procesadas. '
                             f'Aprobadas: {fotos_aprobadas}/{MIN_FOTOS}. '
                             f'Pendientes: {fotos_pendientes}.',
                    'fotos_aprobadas':  fotos_aprobadas,
                    'fotos_pendientes': fotos_pendientes,
                    'fotos_necesarias': MIN_FOTOS,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )
        return Response(
            {
                'error': f'Necesitas al menos {MIN_FOTOS} fotos aprobadas. '
                         f'Actualmente tienes {fotos_aprobadas}.',
                'fotos_aprobadas':  fotos_aprobadas,
                'fotos_necesarias': MIN_FOTOS,
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Marcar onboarding completo
    profile.onboarding_paso = PasoOnboarding.COMPLETO
    profile.save(update_fields=['onboarding_paso'])

    user = request.user
    user.perfil_completo = True
    user.intereses       = profile.gustos[:10]  # Sincronizar gustos → intereses para matching
    user.save(update_fields=['perfil_completo', 'intereses'])

    # Publicar al broker para scoring inicial del matching engine
    broker.publish('USER_PARSE_SCORING', {
        'user_id':   user.id,
        'intereses': user.intereses,
        'carrera':   user.carrera,
        'horarios':  user.horarios,
        'intenciones': profile.intenciones,
    })

    audit.log(request, audit.USER_REGISTERED, {
        'user_id':     user.id,
        'intenciones': profile.intenciones,
    })

    logger.info(f'[Onboarding] Completado para user={user.id}')

    return Response({
        'mensaje':         '¡Bienvenido a Kora! 🎓 Tu perfil está listo.',
        'onboarding_paso': PasoOnboarding.COMPLETO,
    })


# ─────────────────────────────────────────────────────────────────
# Endpoint interno: api-media notifica foto procesada
# ─────────────────────────────────────────────────────────────────
@api_view(['PATCH'])
@permission_classes([])
def foto_procesada(request, foto_id):
    """
    Llamado por api-media worker cuando termina de procesar una foto.
    Actualiza las URLs y el estado de la foto.
    """
    from django.conf import settings as conf
    token = request.headers.get('X-Service-Token', '')
    if token != conf.SERVICE_TOKEN:
        return Response({'error': 'No autorizado.'}, status=status.HTTP_403_FORBIDDEN)

    try:
        foto = UserPhoto.objects.get(pk=foto_id)
    except UserPhoto.DoesNotExist:
        return Response({'error': 'Foto no encontrada.'}, status=status.HTTP_404_NOT_FOUND)

    estado = request.data.get('estado', 'approved')
    foto.estado    = estado
    foto.tmp_path  = ''

    if estado == 'approved':
        urls = request.data.get('urls', {})
        foto.url_original = urls.get('original', '')
        foto.url_medium   = urls.get('medium', '')
        foto.url_thumb    = urls.get('thumb', '')

        # Actualizar foto_url del usuario con la foto principal
        if foto.es_principal:
            user = foto.user
            user.foto_url = foto.url_medium or foto.url_original
            user.save(update_fields=['foto_url'])

    elif estado == 'rejected':
        foto.rechazo_motivo = request.data.get('motivo', 'Contenido inapropiado.')

    foto.save()

    # Notificar al usuario via WS
    from modules.notifications.service import enviar_notificacion_ws
    if estado == 'approved':
        enviar_notificacion_ws(
            foto.user_id, '📸 Foto aprobada',
            'Tu foto fue procesada y aprobada exitosamente.',
            {'tipo': 'foto_aprobada', 'foto_id': foto.id},
        )
    else:
        enviar_notificacion_ws(
            foto.user_id, '⚠️ Foto rechazada',
            f'Una foto fue rechazada: {foto.rechazo_motivo}',
            {'tipo': 'foto_rechazada', 'foto_id': foto.id},
        )

    return Response({'ok': True, 'estado': estado})
