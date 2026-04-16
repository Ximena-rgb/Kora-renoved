from django.urls import path
from . import views

urlpatterns = [
    # ── Estado ────────────────────────────────────────────────────
    path('estado/',          views.estado,         name='onboarding-estado'),

    # ── Pasos secuenciales ────────────────────────────────────────
    path('terminos/',        views.terminos,        name='onboarding-terminos'),
    path('basico/',          views.basico,          name='onboarding-basico'),
    path('intenciones/',     views.intenciones,     name='onboarding-intenciones'),
    path('preferencias/',    views.preferencias,    name='onboarding-preferencias'),
    path('personal/',        views.personal,        name='onboarding-personal'),
    path('institucional/',   views.institucional,   name='onboarding-institucional'),

    # ── Fotos ─────────────────────────────────────────────────────
    path('fotos/',                    views.subir_foto,   name='onboarding-subir-foto'),
    path('fotos/lista/',              views.listar_fotos, name='onboarding-listar-fotos'),
    path('fotos/<int:foto_id>/',      views.eliminar_foto, name='onboarding-eliminar-foto'),

    # ── Finalizar ─────────────────────────────────────────────────
    path('completar/',       views.completar,       name='onboarding-completar'),

    # ── Interno: api-media notifica foto procesada ────────────────
    path('interno/fotos/<int:foto_id>/procesada/',
         views.foto_procesada, name='onboarding-foto-procesada'),
]
