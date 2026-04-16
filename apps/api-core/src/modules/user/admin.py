from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display   = ('email', 'nombre', 'carrera', 'semestre', 'disponible', 'reputacion', 'is_active')
    list_filter    = ('is_active', 'is_staff', 'disponible')
    search_fields  = ('email', 'nombre', 'carrera')
    ordering       = ('-created_at',)

    fieldsets = (
        (None,             {'fields': ('email', 'password')}),
        ('Perfil',         {'fields': ('nombre', 'foto_url', 'carrera', 'facultad', 'semestre', 'bio', 'intereses')}),
        ('Disponibilidad', {'fields': ('disponible', 'campus_zona', 'horarios')}),
        ('Reputación',     {'fields': ('reputacion', 'total_ratings')}),
        ('MFA',            {'fields': ('mfa_activo', 'mfa_secret')}),
        ('Permisos',       {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Fechas',         {'fields': ('last_login', 'created_at', 'updated_at')}),
    )
    readonly_fields = ('reputacion', 'total_ratings', 'created_at', 'updated_at', 'last_login')

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields':  ('email', 'nombre', 'password1', 'password2'),
        }),
    )
