from django.urls import path
from . import views

urlpatterns = [
    path('facultades/',                          views.facultades_list,        name='academia-facultades'),
    path('facultades/<int:facultad_id>/programas/', views.programas_por_facultad, name='academia-programas'),
    path('programas/crear/',                     views.crear_programa,         name='academia-crear-programa'),
    path('programas/<int:programa_id>/eliminar/', views.eliminar_programa,     name='academia-eliminar-programa'),
]
