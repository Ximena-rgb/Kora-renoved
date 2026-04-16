from urllib.parse import parse_qs
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import UntypedToken
from rest_framework_simplejwt.exceptions import TokenError
from jwt import decode as jwt_decode
from django.conf import settings


@database_sync_to_async
def get_user_from_token(token: str):
    from modules.user.models import User
    try:
        UntypedToken(token)
        decoded = jwt_decode(token, settings.SECRET_KEY, algorithms=['HS256'])
        user_id = decoded.get('user_id')
        return User.objects.get(pk=user_id, is_active=True)
    except Exception:
        return AnonymousUser()


class JWTAuthMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        # Token desde query string: ws://host/ws/chat/room/?token=...
        qs     = parse_qs(scope.get('query_string', b'').decode())
        tokens = qs.get('token', [])
        token  = tokens[0] if tokens else ''

        scope['user'] = await get_user_from_token(token) if token else AnonymousUser()
        return await self.app(scope, receive, send)
