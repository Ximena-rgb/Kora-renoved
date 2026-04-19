from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, IsAdminUser, AllowAny
from rest_framework.response import Response
from rest_framework import status
from .models import Facultad, Programa
from .serializers import FacultadSerializer


@api_view(['GET'])
@permission_classes([AllowAny])
def facultades_list(request):
    """Lista todas las facultades activas con sus programas."""
    facultades = Facultad.objects.filter(activa=True).prefetch_related('programas')
    return Response(FacultadSerializer(facultades, many=True).data)


@api_view(['GET'])
@permission_classes([AllowAny])
def programas_por_facultad(request, facultad_id):
    """Programas activos de una facultad específica."""
    try:
        facultad = Facultad.objects.get(pk=facultad_id, activa=True)
    except Facultad.DoesNotExist:
        return Response({'error': 'Facultad no encontrada.'}, status=404)
    programas = facultad.programas.filter(activo=True)
    from .serializers import ProgramaSerializer
    return Response(ProgramaSerializer(programas, many=True).data)


# ── Admin CRUD (solo superusuarios) ──────────────────────────────

@api_view(['POST'])
@permission_classes([IsAdminUser])
def crear_programa(request):
    """Crea un programa nuevo. Solo admins."""
    facultad_id = request.data.get('facultad_id')
    nombre      = request.data.get('nombre', '').strip()
    nivel       = request.data.get('nivel', 'profesional')

    if not facultad_id or not nombre:
        return Response({'error': 'facultad_id y nombre son requeridos.'}, status=400)

    try:
        facultad = Facultad.objects.get(pk=facultad_id)
    except Facultad.DoesNotExist:
        return Response({'error': 'Facultad no encontrada.'}, status=404)

    programa, created = Programa.objects.get_or_create(
        facultad=facultad, nombre=nombre,
        defaults={'nivel': nivel, 'activo': True},
    )
    return Response({'id': programa.id, 'nombre': programa.nombre,
                     'created': created},
                    status=201 if created else 200)


@api_view(['DELETE'])
@permission_classes([IsAdminUser])
def eliminar_programa(request, programa_id):
    """Desactiva (soft-delete) un programa. Solo admins."""
    try:
        programa = Programa.objects.get(pk=programa_id)
    except Programa.DoesNotExist:
        return Response({'error': 'Programa no encontrado.'}, status=404)
    programa.activo = False
    programa.save(update_fields=['activo'])
    return Response({'mensaje': f'Programa "{programa.nombre}" desactivado.'})
