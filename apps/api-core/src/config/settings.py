from decouple import config, Csv
from pathlib import Path
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

SECRET_KEY    = config('SECRET_KEY', default='dev-secret-key-cambiar-en-produccion')
DEBUG         = config('DEBUG', default=True, cast=bool)
ALLOWED_HOSTS = config('ALLOWED_HOSTS', default='*', cast=Csv())

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'corsheaders',
    'channels',
    'django_filters',
    'django_prometheus',
    'modules.audit.apps.AuditConfig',
    'modules.auth.apps.AuthConfig',
    'modules.user.apps.UserConfig',
    'modules.matching.apps.MatchingConfig',
    'modules.plans.apps.PlansConfig',
    'modules.ai_assistant.apps.AIAssistantConfig',
    'modules.chat.apps.ChatConfig',
    'modules.notifications.apps.NotificationsConfig',
    'modules.reputation.apps.ReputationConfig',
    'modules.onboarding.apps.OnboardingConfig',
    'modules.modo_desparche.apps.ModoDesparcheConfig',
    'modules.academia.apps.AcademiaConfig',
]

MIDDLEWARE = [
    'django_prometheus.middleware.PrometheusBeforeMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
    'django_prometheus.middleware.PrometheusAfterMiddleware',
]

ROOT_URLCONF     = 'config.urls'
WSGI_APPLICATION = 'config.wsgi.application'
ASGI_APPLICATION = 'config.asgi.application'

DATABASES = {
    'default': {
        'ENGINE':       'django.db.backends.postgresql',
        'NAME':         config('DB_NAME',     default='kora_db'),
        'USER':         config('DB_USER',     default='kora_user'),
        'PASSWORD':     config('DB_PASSWORD', default='kora_password'),
        'HOST':         config('DB_HOST',     default='db'),
        'PORT':         config('DB_PORT',     default='5432'),
        'CONN_MAX_AGE': 60,
        'OPTIONS':      {'connect_timeout': 10},
    }
}

REDIS_URL = config('REDIS_URL', default='redis://redis:6379/0')

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG':  {'hosts': [REDIS_URL], 'capacity': 1500, 'expiry': 10},
    },
}

CACHES = {
    'default': {
        'BACKEND':  'django.core.cache.backends.redis.RedisCache',
        'LOCATION': REDIS_URL,
        'TIMEOUT':  600,
    }
}

REDIS_STREAMS = {
    'USER_REGISTERED':    'stream:user.registered',
    'USER_PARSE_SCORING': 'stream:user.parse_scoring',
    'MATCH_CREATED':      'stream:match.created',
    'AI_COACH_REQUEST':   'stream:ai.coach_request',
    'AI_GAME_REQUEST':    'stream:ai.game_request',
    'IMAGE_PROCESS_TASK': 'stream:image.process_task',
    'SYSTEM_ALERT':       'stream:system.alert',
    'AUDIT_LOG':          'stream:audit.log',
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME':    timedelta(hours=1),
    'REFRESH_TOKEN_LIFETIME':   timedelta(days=30),
    'ROTATE_REFRESH_TOKENS':    True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN':        True,
    'ALGORITHM':                'HS256',
    'SIGNING_KEY':              config('JWT_SIGNING_KEY', default=SECRET_KEY),
    'AUTH_HEADER_TYPES':        ('Bearer',),
    'USER_ID_FIELD':            'id',
    'USER_ID_CLAIM':            'user_id',
}

FIREBASE_CREDENTIALS_PATH = config('FIREBASE_CREDENTIALS_PATH', default='')
FIREBASE_WEB_API_KEY      = config('FIREBASE_WEB_API_KEY', default='')  # Solo para debug login
ALLOWED_EMAIL_DOMAIN      = config('ALLOWED_EMAIL_DOMAIN',       default='')
SERVICE_TOKEN             = config('SERVICE_TOKEN',               default='dev-service-token')
MFA_ISSUER_NAME           = config('MFA_ISSUER_NAME',            default='Kora University')
MFA_TOKEN_TTL             = 300
MFA_REDIS_PREFIX          = 'mfa_pending:'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'modules.auth.authentication.KoraJWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'EXCEPTION_HANDLER': 'shared.exceptions.kora_exception_handler',
}

CORS_ALLOW_ALL_ORIGINS  = True
CORS_ALLOW_CREDENTIALS  = True
AUTH_USER_MODEL         = 'kora_user.User'

STATIC_URL  = '/static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
MEDIA_URL   = '/media/'
MEDIA_ROOT  = config('MEDIA_ROOT', default='/storage/uploads')

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '%(asctime)s [%(levelname)s] %(name)s: %(message)s',
        },
        'simple': {
            'format': '%(asctime)s %(levelname)s %(name)s %(message)s',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'verbose',
        },
    },
    'loggers': {
        # Auth module — DEBUG para ver todo
        'modules.auth': {
            'handlers': ['console'],
            'level': 'DEBUG',
            'propagate': False,
        },
        # Django request warnings
        'django.request': {
            'handlers': ['console'],
            'level': 'WARNING',
            'propagate': False,
        },
        # DRF exceptions
        'rest_framework': {
            'handlers': ['console'],
            'level': 'WARNING',
            'propagate': False,
        },
    },
    'root': {
        'handlers': ['console'],
        'level': 'INFO',
    },
}

LANGUAGE_CODE      = 'es-co'
TIME_ZONE          = 'America/Bogota'
USE_I18N           = True
USE_TZ             = True
DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

TEMPLATES = [{
    'BACKEND': 'django.template.backends.django.DjangoTemplates',
    'DIRS': [],
    'APP_DIRS': True,
    'OPTIONS': {'context_processors': [
        'django.template.context_processors.debug',
        'django.template.context_processors.request',
        'django.contrib.auth.context_processors.auth',
        'django.contrib.messages.context_processors.messages',
    ]},
}]

GEMINI_API_KEY = config('GEMINI_API_KEY', default='')
OPENAI_API_KEY = config('OPENAI_API_KEY', default='')

OLLAMA_URL   = config('OLLAMA_URL', default='https://santiagoherazo.ddns.net:11435')
OLLAMA_MODEL = config('OLLAMA_MODEL', default='')
