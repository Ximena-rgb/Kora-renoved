from django.apps import AppConfig

class PlansConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name  = 'modules.plans'
    label = 'kora_plans'
    verbose_name = 'Segmented Plans Module'
