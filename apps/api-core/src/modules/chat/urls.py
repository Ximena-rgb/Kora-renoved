from django.urls import path
from . import views
from . import internal_views

urlpatterns = [
    path('conversaciones/',                    views.conversaciones,       name='chat-convs'),
    path('conversaciones/<str:room_id>/mensajes/', views.historial_mensajes, name='chat-historial'),
    # Interno (llamado por worker-ai)
    path('interno/inyectar/',                  internal_views.inyectar_mensaje, name='chat-inyectar'),
]
