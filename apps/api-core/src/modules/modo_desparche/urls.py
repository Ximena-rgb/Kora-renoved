from django.urls import path
from . import views

urlpatterns = [
    path('sesiones/crear/',               views.crear_sesion,      name='desparche-crear'),
    path('sesiones/<int:sesion_id>/',      views.estado_sesion,     name='desparche-estado'),
    path('sesiones/<int:sesion_id>/unirse/',    views.unirse_sesion,    name='desparche-unirse'),
    path('sesiones/<int:sesion_id>/iniciar/',   views.iniciar_sesion,   name='desparche-iniciar'),
    path('sesiones/<int:sesion_id>/siguiente/', views.siguiente_ronda,  name='desparche-siguiente'),
    path('sesiones/<int:sesion_id>/resultados/', views.resultados_sesion, name='desparche-resultados'),
    path('rondas/<int:ronda_id>/completar/', views.completar_ronda, name='desparche-completar'),
    path('rondas/<int:ronda_id>/votar/',     views.votar_ronda,     name='desparche-votar'),
    path('interno/rondas/<int:ronda_id>/ia/', views.actualizar_ronda_ia, name='desparche-ronda-ia'),
]
