from django.apps import AppConfig

class MatchingConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name  = 'modules.matching'
    label = 'kora_matching'
    verbose_name = 'Matching Engine Module'
