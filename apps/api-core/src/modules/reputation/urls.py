from django.urls import path
from . import views

urlpatterns = [
    path('calificar/',           views.calificar,     name='rep-calificar'),
    path('mi-score/',            views.mi_score,      name='rep-mi-score'),
    path('usuario/<int:user_id>/', views.score_usuario, name='rep-usuario'),
]
