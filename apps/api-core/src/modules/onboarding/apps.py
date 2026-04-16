from django.apps import AppConfig


class OnboardingConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name         = 'modules.onboarding'
    label        = 'kora_onboarding'
    verbose_name = 'Onboarding — Perfil de Usuario'
