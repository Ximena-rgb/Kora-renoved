"""
management/commands/expirar_likes.py
=====================================
Expira likes sin respuesta después de 24h.
Ejecutar cada hora con cron o celery beat:
  python manage.py expirar_likes
"""
import logging
from django.core.management.base import BaseCommand
from modules.matching.engine import expirar_likes_vencidos

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = 'Expira likes, contrapropuestas y matches 2pa2 sin respuesta'

    def handle(self, *args, **options):
        n = expirar_likes_vencidos()
        self.stdout.write(f'[expirar_likes] {n} items expirados ✅')
