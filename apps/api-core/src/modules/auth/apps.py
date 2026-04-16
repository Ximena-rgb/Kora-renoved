from django.apps import AppConfig

class AuthConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name  = 'modules.auth'
    label = 'kora_auth'
    verbose_name = 'Auth & Security Module'
