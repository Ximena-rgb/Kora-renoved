"""
modules/modo_desparche/models.py
=================================
Sistema de juegos para el Modo Desparche.

Juegos disponibles:
  - verdad_o_reto       → preguntas/retos alternados
  - quien_mas_probable  → votar quién de los participantes
  - adivina_la_foto     → adivinar a quién pertenece una foto
"""
from django.conf import settings
from django.db import models


class SesionJuego(models.Model):
    class TipoJuego(models.TextChoices):
        VERDAD_O_RETO      = 'verdad_o_reto',      'Verdad o Reto'
        QUIEN_MAS_PROBABLE = 'quien_mas_probable',  '¿Quién es más probable?'
        ADIVINA_FOTO       = 'adivina_foto',        'Adivina la Foto'

    class Estado(models.TextChoices):
        ESPERANDO  = 'esperando',  'Esperando jugadores'
        EN_CURSO   = 'en_curso',   'En curso'
        TERMINADA  = 'terminada',  'Terminada'
        CANCELADA  = 'cancelada',  'Cancelada'

    tipo_juego   = models.CharField(max_length=20, choices=TipoJuego.choices)
    room_id      = models.CharField(max_length=100, db_index=True,
                      help_text='Room del chat donde se juega')
    creador      = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                      related_name='juegos_creados')
    estado       = models.CharField(max_length=12, choices=Estado.choices,
                      default=Estado.ESPERANDO)
    ronda_actual = models.PositiveSmallIntegerField(default=0)
    max_rondas   = models.PositiveSmallIntegerField(default=10)
    created_at   = models.DateTimeField(auto_now_add=True)
    updated_at   = models.DateTimeField(auto_now=True)

    class Meta:
        app_label = 'kora_desparche'
        db_table  = 'sesiones_juego'
        ordering  = ['-created_at']

    def __str__(self):
        return f'[{self.get_tipo_juego_display()}] room={self.room_id} [{self.estado}]'

    @property
    def hay_mas_rondas(self) -> bool:
        return self.ronda_actual < self.max_rondas


class JugadorSesion(models.Model):
    sesion  = models.ForeignKey(SesionJuego, on_delete=models.CASCADE,
                related_name='jugadores')
    usuario = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                related_name='sesiones_juego')
    puntos  = models.PositiveSmallIntegerField(default=0)
    activo  = models.BooleanField(default=True)
    unido_en = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label       = 'kora_desparche'
        db_table        = 'jugadores_sesion'
        unique_together = [['sesion', 'usuario']]

    def __str__(self):
        return f'{self.usuario_id} en sesión {self.sesion_id}'


class RondaJuego(models.Model):
    class TipoContenido(models.TextChoices):
        VERDAD    = 'verdad',    'Verdad'
        RETO      = 'reto',      'Reto'
        PREGUNTA  = 'pregunta',  'Pregunta (¿Quién?)'
        FOTO      = 'foto',      'Foto para adivinar'

    sesion          = models.ForeignKey(SesionJuego, on_delete=models.CASCADE,
                        related_name='rondas')
    numero          = models.PositiveSmallIntegerField()
    tipo_contenido  = models.CharField(max_length=12, choices=TipoContenido.choices)
    contenido       = models.TextField(help_text='La pregunta, reto o descripción')
    # Para verdad_o_reto: quién le toca
    destinatario    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL,
                        null=True, blank=True, related_name='rondas_destinatario')
    # Para adivina_foto
    foto_url        = models.URLField(blank=True, default='')
    respuesta_correcta = models.CharField(max_length=200, blank=True, default='')
    completada      = models.BooleanField(default=False)
    generada_por_ia = models.BooleanField(default=False)
    created_at      = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label       = 'kora_desparche'
        db_table        = 'rondas_juego'
        unique_together = [['sesion', 'numero']]
        ordering        = ['numero']

    def __str__(self):
        return f'Ronda {self.numero} [{self.tipo_contenido}] sesión {self.sesion_id}'


class VotoJuego(models.Model):
    """Voto de un jugador en una ronda de ¿Quién es más probable?"""
    ronda    = models.ForeignKey(RondaJuego, on_delete=models.CASCADE, related_name='votos')
    votante  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                 related_name='votos_juego')
    votado   = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                 related_name='votos_recibidos_juego')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label       = 'kora_desparche'
        db_table        = 'votos_juego'
        unique_together = [['ronda', 'votante']]

    def __str__(self):
        return f'{self.votante_id} vota por {self.votado_id} en ronda {self.ronda_id}'
