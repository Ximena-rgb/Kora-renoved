import os
import django
from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from modules.chat.middleware import JWTAuthMiddleware
from modules.chat.routing import websocket_urlpatterns as chat_ws
from modules.notifications.routing import websocket_urlpatterns as notif_ws

application = ProtocolTypeRouter({
    'http': get_asgi_application(),
    'websocket': JWTAuthMiddleware(
        URLRouter(chat_ws + notif_ws)
    ),
})
