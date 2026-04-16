from django.conf import settings
from django.db import models


class Conversacion(models.Model):
    usuario_1  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='conversaciones_1')
    usuario_2  = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='conversaciones_2')
    room_id    = models.CharField(max_length=40, unique=True, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        app_label       = 'kora_chat'
        db_table        = 'conversaciones'
        unique_together = [['usuario_1', 'usuario_2']]

    @staticmethod
    def get_or_create_room_id(user_a_id: int, user_b_id: int) -> str:
        ids = sorted([user_a_id, user_b_id])
        return f'chat_{ids[0]}_{ids[1]}'

    def __str__(self):
        return f'Chat {self.usuario_1_id} ↔ {self.usuario_2_id}'


class Mensaje(models.Model):
    TIPO_CHOICES = [
        ('mensaje',       'Mensaje normal'),
        ('ai_icebreaker', 'Icebreaker IA'),
        ('ai_coach',      'Consejo IA'),
        ('game_verdad',   'Juego — Verdad'),
        ('game_reto',     'Juego — Reto'),
        ('game_quien',    'Juego — ¿Quién?'),
        ('sistema',       'Sistema'),
    ]

    conversacion = models.ForeignKey(Conversacion, on_delete=models.CASCADE, related_name='mensajes')
    remitente    = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
                    related_name='mensajes_enviados')
    contenido    = models.TextField(max_length=2000)
    tipo         = models.CharField(max_length=20, choices=TIPO_CHOICES, default='mensaje')
    leido        = models.BooleanField(default=False)
    created_at   = models.DateTimeField(auto_now_add=True)

    class Meta:
        app_label = 'kora_chat'
        db_table  = 'mensajes'
        ordering  = ['created_at']
        indexes   = [models.Index(fields=['conversacion', 'created_at'])]

    def __str__(self):
        return f'{self.remitente_id}: {self.contenido[:40]}'

    @property
    def es_ia(self) -> bool:
        return self.tipo != 'mensaje' and self.tipo != 'sistema'
