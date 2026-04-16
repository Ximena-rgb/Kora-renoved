#!/bin/sh
set -e

# ── Sincronizar reloj con NTP (evita "Token used too early") ──────
# El reloj del contenedor Docker puede quedar desfasado después de
# que el host duerme o hiberna, causando fallos en Firebase Auth.
echo "⏰ Sincronizando reloj..."
if command -v ntpdate >/dev/null 2>&1; then
    ntpdate -s pool.ntp.org 2>/dev/null || true
elif command -v chronyd >/dev/null 2>&1; then
    chronyc makestep 2>/dev/null || true
fi
echo "   Hora actual: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"

echo "⏳ Esperando PostgreSQL..."
until pg_isready -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-kora_user}" -q; do
    sleep 1
done
echo "✅ PostgreSQL listo"

echo "⏳ Esperando Redis..."
until redis-cli -u "${REDIS_URL:-redis://redis:6379/0}" ping 2>/dev/null | grep -q PONG; do
    sleep 1
done
echo "✅ Redis listo"

echo "🔄 Ejecutando migraciones..."
python manage.py migrate --noinput

echo "📦 Archivos estáticos..."
python manage.py collectstatic --noinput --clear 2>/dev/null || true

# Crear superusuario dev si no existe
if [ "${DEBUG:-True}" = "True" ] && [ -n "${DJANGO_SUPERUSER_EMAIL:-}" ]; then
    python manage.py shell -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(email='${DJANGO_SUPERUSER_EMAIL}').exists():
    User.objects.create_superuser(
        email='${DJANGO_SUPERUSER_EMAIL}',
        password='${DJANGO_SUPERUSER_PASSWORD:-admin123}',
        nombre='Admin'
    )
    print('Superusuario creado ✅')
" 2>/dev/null || true
fi

echo "🚀 Arrancando Daphne..."
exec daphne -b 0.0.0.0 -p 8000 config.asgi:application
