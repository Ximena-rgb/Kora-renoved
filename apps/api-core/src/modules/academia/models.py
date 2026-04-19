"""
modules/academia/models.py
===========================
Facultades y Programas académicos del Pascual Bravo.
Administrables desde el panel de Django — se pueden agregar/eliminar
programas sin tocar código.
"""
from django.db import models


class Facultad(models.Model):
    nombre   = models.CharField(max_length=200, unique=True)
    slug     = models.SlugField(max_length=100, unique=True)
    activa   = models.BooleanField(default=True)
    orden    = models.PositiveSmallIntegerField(default=0)

    class Meta:
        app_label = 'academia'
        db_table  = 'academia_facultades'
        ordering  = ['orden', 'nombre']
        verbose_name        = 'Facultad'
        verbose_name_plural = 'Facultades'

    def __str__(self):
        return self.nombre


class Programa(models.Model):
    NIVEL_CHOICES = [
        ('tecnico',      'Técnico Profesional'),
        ('tecnologo',    'Tecnología'),
        ('profesional',  'Profesional Universitario'),
        ('especializacion', 'Especialización'),
        ('maestria',     'Maestría'),
    ]

    facultad  = models.ForeignKey(
        Facultad, on_delete=models.CASCADE, related_name='programas')
    nombre    = models.CharField(max_length=200)
    nivel     = models.CharField(max_length=20, choices=NIVEL_CHOICES,
                                 default='profesional')
    activo    = models.BooleanField(default=True)
    orden     = models.PositiveSmallIntegerField(default=0)

    class Meta:
        app_label = 'academia'
        db_table  = 'academia_programas'
        ordering  = ['facultad__orden', 'orden', 'nombre']
        unique_together     = [('facultad', 'nombre')]
        verbose_name        = 'Programa'
        verbose_name_plural = 'Programas'

    def __str__(self):
        return f'{self.nombre} — {self.facultad.nombre}'
