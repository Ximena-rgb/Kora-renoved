from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.http import HttpResponse
from django_prometheus import exports as prometheus_exports


def health_check(request):
    return HttpResponse('ok', content_type='text/plain')


urlpatterns = [
    path('admin/',   admin.site.urls),
    path('health/',  health_check, name='health'),

    # ── Auth ──────────────────────────────────────────────────────
    path('api/v1/auth/',          include('modules.auth.urls')),

    # ── Módulos core ─────────────────────────────────────────────
    path('api/v1/users/',         include('modules.user.urls')),
    path('api/v1/onboarding/',    include('modules.onboarding.urls')),
    path('api/v1/matching/',      include('modules.matching.urls')),
    path('api/v1/plans/',         include('modules.plans.urls')),
    path('api/v1/chat/',          include('modules.chat.urls')),
    path('api/v1/reputation/',    include('modules.reputation.urls')),
    path('api/v1/notifications/', include('modules.notifications.urls')),
    path('api/v1/ai/',            include('modules.ai_assistant.urls')),
    path('api/v1/desparche/',     include('modules.modo_desparche.urls')),

    # ── Observabilidad ────────────────────────────────────────────
    path('metrics/', prometheus_exports.ExportToDjangoView, name='prometheus-metrics'),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
