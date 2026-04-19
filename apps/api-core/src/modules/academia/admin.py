from django.contrib import admin
from .models import Facultad, Programa


class ProgramaInline(admin.TabularInline):
    model   = Programa
    extra   = 1
    fields  = ('nombre', 'nivel', 'activo', 'orden')


@admin.register(Facultad)
class FacultadAdmin(admin.ModelAdmin):
    list_display  = ('nombre', 'slug', 'activa', 'orden')
    list_editable = ('activa', 'orden')
    prepopulated_fields = {'slug': ('nombre',)}
    inlines = [ProgramaInline]


@admin.register(Programa)
class ProgramaAdmin(admin.ModelAdmin):
    list_display  = ('nombre', 'facultad', 'nivel', 'activo', 'orden')
    list_editable = ('activo', 'orden')
    list_filter   = ('facultad', 'nivel', 'activo')
    search_fields = ('nombre',)
