from django.apps import AppConfig

class AuditConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name  = 'modules.audit'
    label = 'kora_audit'
    verbose_name = 'Auditoría de Negocio 360°'
