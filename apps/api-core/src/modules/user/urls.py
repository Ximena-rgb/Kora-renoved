from django.urls import path
from . import views

urlpatterns = [
    path('me/',              views.me,                   name='user-me'),
    path('me/profile/',      views.update_profile,       name='user-update-profile'),
    path('me/disponibilidad/', views.update_disponibilidad, name='user-disponibilidad'),
    path('me/foto/',         views.upload_foto,          name='user-upload-foto'),
    path('nearby/',          views.nearby_users,         name='user-nearby'),
    path('<int:pk>/',        views.user_detail,          name='user-detail'),
]
