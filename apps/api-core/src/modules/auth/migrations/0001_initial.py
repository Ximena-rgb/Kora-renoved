"""
La app rest_framework_simplejwt.token_blacklist tiene sus propias
migraciones que Django corre automáticamente. Este archivo existe
para satisfacer el sistema de migraciones de kora_auth que no
tiene modelos propios.
"""
from django.db import migrations


class Migration(migrations.Migration):
    initial      = True
    dependencies  = []
    operations   = []
