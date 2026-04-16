from django.urls import path
from . import views

urlpatterns = [
    # ── Core ──────────────────────────────────────────────────────
    path('deck/',                              views.deck,                   name='matching-deck'),
    path('swipe/',                             views.swipe,                  name='matching-swipe'),
    path('bandeja/',                           views.bandeja,                name='matching-bandeja'),
    path('responder/<int:like_id>/',           views.responder_like,         name='matching-responder'),
    path('contrapropuesta/<int:contra_id>/responder/',
                                               views.responder_contrapropuesta, name='matching-contra-responder'),
    path('matches/',                           views.mis_matches,            name='matching-matches'),
    path('bloquear/<int:user_id>/',            views.bloquear,               name='matching-bloquear'),
    path('likes-restantes/',                   views.likes_restantes,        name='matching-likes'),

    # ── 2pa2 ──────────────────────────────────────────────────────
    path('2pa2/crear/',                        views.crear_dupla,            name='matching-2pa2-crear'),
    path('2pa2/<int:dupla_id>/aceptar/',       views.aceptar_dupla,          name='matching-2pa2-aceptar'),
    path('2pa2/<int:dupla_id>/buscar/',        views.buscar_2pa2,            name='matching-2pa2-buscar'),
    path('2pa2/<int:match_id>/responder/',     views.responder_2pa2,         name='matching-2pa2-responder'),
    path('2pa2/mis-duplas/',                   views.mis_duplas,             name='matching-2pa2-duplas'),
]
