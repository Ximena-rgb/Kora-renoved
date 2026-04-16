from django.db import migrations, models
import django.utils.timezone


class Migration(migrations.Migration):
    """
    audit_logs is pre-created by infrastructure/postgres/init.sql before
    Django runs migrate. We use SeparateDatabaseAndState so Django registers
    the model in its ORM state without issuing a CREATE TABLE (which would
    fail with DuplicateTable). The indexes are also skipped at the DB level
    because init.sql already creates them.
    """

    initial = True
    dependencies = []

    operations = [
        migrations.SeparateDatabaseAndState(
            # ── ORM state: Django knows about the model and all its fields ──
            state_operations=[
                migrations.CreateModel(
                    name='AuditLog',
                    fields=[
                        ('id',           models.BigAutoField(auto_created=True, primary_key=True, serialize=False)),
                        ('timestamp',    models.DateTimeField(db_index=True, default=django.utils.timezone.now)),
                        ('user_id',      models.BigIntegerField(blank=True, db_index=True, null=True)),
                        ('action',       models.CharField(db_index=True, max_length=80)),
                        ('context_json', models.JSONField(default=dict)),
                        ('ip_address',   models.GenericIPAddressField(blank=True, null=True)),
                    ],
                    options={
                        'db_table': 'audit_logs', 'app_label': 'kora_audit',
                        'ordering': ['-timestamp'],
                    },
                ),
                migrations.AddIndex(
                    model_name='auditlog',
                    index=models.Index(fields=['action', 'timestamp'], name='audit_action_ts_idx'),
                ),
                migrations.AddIndex(
                    model_name='auditlog',
                    index=models.Index(fields=['user_id', 'timestamp'], name='audit_user_ts_idx'),
                ),
            ],
            # ── Database: do nothing — init.sql already created the table ──
            database_operations=[],
        ),
    ]
