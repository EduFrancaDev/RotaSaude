"""Configurações do backend do RotaSaúde.

Toda configuração sensível ou dependente do ambiente vem de variáveis de ambiente
(veja `.env.example`). Nada aqui é credencial real.
"""

import os
from pathlib import Path

from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent


def env_bool(name, default=False):
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_list(name, default=""):
    return [item.strip() for item in os.environ.get(name, default).split(",") if item.strip()]


DEBUG = env_bool("DJANGO_DEBUG", False)

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY")
if not SECRET_KEY:
    if not DEBUG:
        raise ImproperlyConfigured("Defina DJANGO_SECRET_KEY quando DJANGO_DEBUG for falso.")
    SECRET_KEY = "insecure-dev-only-key"

ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1" if DEBUG else "")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "apps.services",
    "apps.units",
    "apps.integrations",
    "apps.routing",
    "apps.demo",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("POSTGRES_DB", "rotasaude"),
        "USER": os.environ.get("POSTGRES_USER", "rotasaude"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", ""),
        "HOST": os.environ.get("POSTGRES_HOST", "localhost"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
    }
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "pt-br"
TIME_ZONE = "America/Sao_Paulo"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# --- API pública (somente leitura, sem autenticação de usuário final) ---
REST_FRAMEWORK = {
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.AllowAny"],
    "DEFAULT_PAGINATION_CLASS": "config.pagination.StandardPagination",
    "PAGE_SIZE": 20,
}

# Limite de requisições por credencial de integração (formato do DRF: N/sec|min|hour|day).
INTEGRATION_RATE_LIMIT = os.environ.get("INTEGRATION_RATE_LIMIT", "60/min")

# --- Roteamento (OSRM demo; futuro Google Routes) ---
ROUTING_PROVIDER = os.environ.get("ROUTING_PROVIDER", "osrm")
OSRM_BASE_URL = os.environ.get("OSRM_BASE_URL", "https://router.project-osrm.org")
OSRM_TIMEOUT_SECONDS = float(os.environ.get("OSRM_TIMEOUT_SECONDS", "10"))
ROUTING_CACHE_TTL = int(os.environ.get("ROUTING_CACHE_TTL", "120"))
ROUTING_RATE_LIMIT = os.environ.get("ROUTING_RATE_LIMIT", "30/min")
OSRM_MIN_REQUEST_INTERVAL = float(os.environ.get("OSRM_MIN_REQUEST_INTERVAL", "1.0"))
OSRM_OUTBOUND_LOCK_TTL = int(os.environ.get("OSRM_OUTBOUND_LOCK_TTL", "30"))

# --- Modo de demonstração acadêmica (apps.demo) ---
# Desligado por padrão. Só vale com DJANGO_DEBUG=true: ativá-lo em um ambiente sem debug é
# tratado como erro de configuração, para que dados simulados nunca cheguem a produção.
DEMO_MODE = env_bool("DEMO_MODE", False)
if DEMO_MODE and not DEBUG:
    raise ImproperlyConfigured("DEMO_MODE exige DJANGO_DEBUG=true; o modo de demonstração é bloqueado fora do debug.")
# Idade a partir da qual `show_demo_status` classifica uma leitura como desatualizada.
# Deve coincidir com OPERATIONAL_MAX_AGE_MINUTES do app Flutter (padrão 30).
DEMO_STALE_AFTER_MINUTES = int(os.environ.get("DEMO_STALE_AFTER_MINUTES", "30"))

REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"] = {
    "integration": INTEGRATION_RATE_LIMIT,
    "routes": ROUTING_RATE_LIMIT,
}

# --- CORS: somente origens explícitas, somente leitura ---
CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS")
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOW_METHODS = ["GET", "HEAD", "OPTIONS"]

# --- Logging básico para o console ---
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "simple": {"format": "{asctime} {levelname} {name}: {message}", "style": "{"},
    },
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "simple"},
    },
    "root": {
        "handlers": ["console"],
        "level": os.environ.get("DJANGO_LOG_LEVEL", "INFO"),
    },
}
