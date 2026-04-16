from django.urls import path
from . import views

urlpatterns = [
    path('icebreaker/', views.generar_icebreaker, name='ai-icebreaker'),
    path('coach/',      views.date_coach,         name='ai-date-coach'),
]
