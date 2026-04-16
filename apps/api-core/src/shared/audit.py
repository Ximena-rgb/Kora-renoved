import logging
from shared.broker import broker

logger = logging.getLogger('modules.audit')


class AuditLogger:
    USER_REGISTERED    = 'USER_REGISTERED'
    USER_LOGIN         = 'USER_LOGIN'
    USER_PARSE_SCORING = 'USER_PARSE_SCORING'
    MATCH_CREATED      = 'MATCH_CREATED'
    PLAN_CREATED       = 'PLAN_CREATED'
    PLAN_JOINED        = 'PLAN_JOINED'
    PLAN_LEFT          = 'PLAN_LEFT'
    AI_COACH_REQUEST   = 'AI_COACH_REQUEST'
    IMAGE_UPLOADED     = 'IMAGE_UPLOADED'
    SYSTEM_ALERT       = 'SYSTEM_ALERT'

    def log(self, request, action: str, context: dict = None) -> None:
        user_id    = getattr(getattr(request, 'user', None), 'id', None)
        ip_address = self._get_ip(request)
        ctx        = context or {}
        try:
            from modules.audit.models import AuditLog
            AuditLog.objects.create(
                user_id=user_id,
                action=action,
                context_json=ctx,
                ip_address=ip_address,
            )
        except Exception as exc:
            logger.error(f'[Audit] Error DB: {exc}')
        broker.publish('AUDIT_LOG', {
            'user_id':    user_id,
            'action':     action,
            'context':    ctx,
            'ip_address': ip_address,
        })
        logger.info(f'[Audit] action={action} user={user_id}')

    def _get_ip(self, request) -> str | None:
        if request is None:
            return None
        xff = request.META.get('HTTP_X_FORWARDED_FOR')
        if xff:
            return xff.split(',')[0].strip()
        return request.META.get('REMOTE_ADDR')


audit = AuditLogger()
