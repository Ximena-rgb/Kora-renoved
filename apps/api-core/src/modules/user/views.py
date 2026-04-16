import logging
import os
import uuid
from django.conf import settings as django_settings
from django.core.cache import cache
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from shared.audit import audit
from shared.broker import broker
from .models import User
from .serializers import (
    UserPublicSerializer, UserPrivateSerializer,
    UpdateProfileSerializer, UpdateDisponibilidadSerializer,
    NearbyUsersQuerySerializer,
)

logger = logging.getLogger(__name__)
DISPONIBILIDAD_TTL = 600


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def me(request):
    return Response(UserPrivateSerializer(request.user).data)


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def update_profile(request):
    s = UpdateProfileSerializer(request.user, data=request.data, partial=True)
    s.is_valid(raise_exception=True)
    s.save()
    broker.publish('USER_PARSE_SCORING', {
        'user_id':   request.user.id,
        'intereses': request.user.intereses,
        'carrera':   request.user.carrera,
        'horarios':  request.user.horarios,
    })
    return Response(UserPrivateSerializer(request.user).data)


@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def update_disponibilidad(request):
    s = UpdateDisponibilidadSerializer(data=request.data)
    s.is_valid(raise_exception=True)
    data = s.validated_data
    user = request.user
    user.disponible  = data['disponible']
    user.campus_zona = data.get('campus_zona', user.campus_zona)
    user.save(update_fields=['disponible', 'campus_zona', 'updated_at'])
    cache_key = f'disponible:{user.id}'
    if data['disponible']:
        cache.set(cache_key, {
            'zona':      user.campus_zona,
            'intereses': user.intereses,
            'horarios':  user.horarios,
        }, timeout=DISPONIBILIDAD_TTL)
    else:
        cache.delete(cache_key)
    return Response({'disponible': user.disponible, 'campus_zona': user.campus_zona})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def upload_foto(request):
    archivo = request.FILES.get('foto')
    if not archivo:
        return Response({'error': 'No se recibió ningún archivo.'}, status=status.HTTP_400_BAD_REQUEST)
    ext      = os.path.splitext(archivo.name)[1].lower() or '.jpg'
    filename = f'{uuid.uuid4()}{ext}'
    tmp_path = os.path.join(django_settings.MEDIA_ROOT, 'profiles', 'tmp', filename)
    os.makedirs(os.path.dirname(tmp_path), exist_ok=True)
    with open(tmp_path, 'wb') as f:
        for chunk in archivo.chunks():
            f.write(chunk)
    broker.publish('IMAGE_PROCESS_TASK', {
        'user_id':  request.user.id,
        'tipo':     'profile',
        'tmp_path': tmp_path,
        'filename': filename,
    })
    audit.log(request, audit.IMAGE_UPLOADED, {'filename': filename})
    return Response({'mensaje': 'Foto recibida.', 'filename': filename}, status=status.HTTP_202_ACCEPTED)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def user_detail(request, pk):
    try:
        user = User.objects.get(pk=int(pk), is_active=True)
    except (ValueError, User.DoesNotExist):
        return Response({'error': 'Usuario no encontrado.'}, status=status.HTTP_404_NOT_FOUND)
    return Response(UserPublicSerializer(user).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def nearby_users(request):
    q = NearbyUsersQuerySerializer(data=request.query_params)
    q.is_valid(raise_exception=True)
    params = q.validated_data
    qs = User.objects.filter(disponible=True, is_active=True).exclude(pk=request.user.pk)
    if params.get('zona'):
        qs = qs.filter(campus_zona__icontains=params['zona'])
    if params.get('facultad'):
        qs = qs.filter(facultad__icontains=params['facultad'])
    if params.get('carrera'):
        qs = qs.filter(carrera__icontains=params['carrera'])
    page      = max(int(request.query_params.get('page', 1)), 1)
    page_size = 20
    start     = (page - 1) * page_size
    mis       = set(request.user.intereses)
    candidatos = list(qs[start: start + page_size * 2])
    candidatos.sort(key=lambda u: len(mis & set(u.intereses)), reverse=True)
    return Response({'page': page, 'results': UserPublicSerializer(candidatos[:page_size], many=True).data})
