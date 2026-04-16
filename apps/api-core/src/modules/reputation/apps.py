from django.apps import AppConfig

class ReputationConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name  = 'modules.reputation'
    label = 'kora_reputation'
    verbose_name = 'Reputación y Calificaciones'
