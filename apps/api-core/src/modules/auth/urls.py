from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path('google/',           views.google_login,    name='auth-google'),
    path('mfa/verify/',       views.mfa_verify,      name='auth-mfa-verify'),
    path('mfa/setup/',        views.mfa_setup,       name='auth-mfa-setup'),
    path('mfa/activate/',     views.mfa_activate,    name='auth-mfa-activate'),
    path('mfa/deactivate/',   views.mfa_deactivate,  name='auth-mfa-deactivate'),
    path('token/refresh/',    TokenRefreshView.as_view(), name='auth-token-refresh'),
    path('logout/',           views.logout,          name='auth-logout'),
    path('perfil/completar/', views.completar_perfil, name='auth-completar-perfil'),
    path('me/',               views.me,               name='auth-me'),
]
