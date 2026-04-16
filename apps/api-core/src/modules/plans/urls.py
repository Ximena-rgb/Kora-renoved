from django.urls import path
from . import views

urlpatterns = [
    path('',                        views.planes_feed,        name='planes-feed'),
    path('crear/',                  views.crear_plan,         name='planes-crear'),
    path('mis-planes/',             views.mis_planes,         name='planes-mis'),
    path('pendientes-calificar/',   views.pendientes_calificar, name='planes-pendientes'),
    path('<int:pk>/',               views.plan_detail,        name='planes-detail'),
    path('<int:pk>/asistir/',       views.asistir,            name='planes-asistir'),
    path('<int:pk>/cancelar/',      views.cancelar_asistencia, name='planes-cancelar'),
    path('<int:pk>/checkin/',       views.checkin,            name='planes-checkin'),
]
