from django.apps import AppConfig

class ChatConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name  = 'modules.chat'
    label = 'kora_chat'
    verbose_name = 'Chat en Tiempo Real'
