from django.db import models
from django.utils import timezone


class AuditLog(models.Model):
    """
    Tabla audit_logs — inmutable, nunca se borra.
    timestamp · user_id · action · context_json · ip_address
    """
    timestamp    = models.DateTimeField(default=timezone.now, db_index=True)
    user_id      = models.BigIntegerField(null=True, blank=True, db_index=True)
    action       = models.CharField(max_length=80, db_index=True)
    context_json = models.JSONField(default=dict)
    ip_address   = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        app_label = 'kora_audit'
        db_table  = 'audit_logs'
        ordering  = ['-timestamp']
        indexes   = [
            models.Index(fields=['action', 'timestamp']),
            models.Index(fields=['user_id', 'timestamp']),
        ]

    def __str__(self):
        return f'[{self.timestamp:%Y-%m-%d %H:%M}] {self.action} user={self.user_id}'
