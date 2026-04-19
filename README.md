<div align="center">

# 💜 KORA
### Conexiones universitarias en tiempo real

**Plataforma de matching social para comunidades universitarias**  
Flutter · Django · Firebase · Docker · WebSockets · IA

</div>

---

## Tabla de contenido

1. [¿Qué es KORA?](#qué-es-kora)
2. [Arquitectura](#arquitectura)
3. [Estructura del repositorio](#estructura-del-repositorio)
4. [Requisitos previos](#requisitos-previos)
5. [Configuración de Firebase](#configuración-de-firebase)
6. [Instalación del backend](#instalación-del-backend)
7. [Instalación de la app Flutter](#instalación-de-la-app-flutter)
8. [Variables de entorno](#variables-de-entorno)
9. [API — Referencia de endpoints](#api--referencia-de-endpoints)
10. [WebSockets](#websockets)
11. [Monitoreo (Prometheus + Grafana)](#monitoreo)
12. [Modo debug (login email/password)](#modo-debug)
13. [Flujo de autenticación](#flujo-de-autenticación)
14. [Seguridad y producción](#seguridad-y-producción)

---

## ¿Qué es KORA?

KORA es una aplicación de matching social pensada exclusivamente para comunidades universitarias. Solo pueden acceder usuarios con correo institucional verificado (configurable por dominio). La plataforma permite:

- **Matching individual y en pareja (2pa2):** swipe de perfiles, likes, contrapropuestas y matches.
- **Planes universitarios:** crear y unirse a planes de estudio, deporte, salidas, etc.
- **Chat en tiempo real** vía WebSockets.
- **Modo Desparche:** sesiones de rondas grupales con votación y análisis de IA.
- **Asistente IA:** icebreakers personalizados y date coach.
- **Sistema de reputación:** calificaciones post-plan que construyen un score de confianza.
- **MFA opcional** con Google Authenticator (TOTP).

---

## Arquitectura

```
┌─────────────────────────────────────────────────────────┐
│                    KORA App (Flutter)                    │
│         Android · iOS · Web · Windows · macOS           │
└────────────────────────┬────────────────────────────────┘
                         │ HTTP / WebSocket
                         ▼
┌─────────────────────────────────────────────────────────┐
│                    Nginx (reverse proxy)                 │
│              Puerto 80  ·  rutas /api/ /ws/ /media/     │
└──────┬───────────────────────────────┬──────────────────┘
       │                               │
       ▼                               ▼
┌─────────────┐                ┌──────────────┐
│  api-core   │                │  api-media   │
│  Django +   │◄──────────────►│  FastAPI     │
│  Channels   │   Redis pub/sub │  procesado   │
│  Puerto 8000│                │  de imágenes │
└──────┬──────┘                └──────────────┘
       │                               
       ▼                               
┌─────────────┐   ┌──────────┐   ┌─────────────┐
│  PostgreSQL │   │  Redis   │   │  worker-ai  │
│  Puerto 5432│   │  :6379   │   │  Ollama/LLM │
└─────────────┘   └──────────┘   └─────────────┘
       
┌──────────────────────────────────────────────┐
│  Monitoreo: Prometheus :9090 · Grafana :3000  │
└──────────────────────────────────────────────┘
```

**Servicios Docker:**

| Servicio         | Imagen / Build       | Puerto   | Descripción                              |
|------------------|----------------------|----------|------------------------------------------|
| `db`             | postgres:16-alpine   | 5432     | Base de datos principal                  |
| `redis`          | redis:7-alpine       | 6379     | Cache, colas, pub/sub WebSocket          |
| `api-core`       | Build propio         | 8000     | API REST + WebSocket (Django Channels)   |
| `stream-consumer`| Build propio (core)  | —        | Consumidor de eventos Redis              |
| `api-media`      | Build propio         | —        | Procesado y redimensionado de imágenes   |
| `worker-ai`      | Build propio         | —        | Generación IA (icebreakers, coach)       |
| `nginx`          | nginx:alpine         | 80       | Reverse proxy, archivos estáticos        |
| `prometheus`     | prom/prometheus      | 9090     | Métricas                                 |
| `grafana`        | grafana/grafana      | 3000     | Dashboards de monitoreo                  |

---

## Estructura del repositorio

```
Kora/
├── .env.example                    ← Variables del backend (copiar como .env)
├── .gitignore
├── README.md
│
├── apps/
│   ├── api-core/                   ← Backend principal (Django 5 + DRF + Channels)
│   │   ├── Dockerfile
│   │   ├── requirements.txt
│   │   └── src/
│   │       ├── config/             ← Settings, URLs, ASGI, WSGI
│   │       ├── modules/
│   │       │   ├── auth/           ← Google Sign-In, JWT, MFA
│   │       │   ├── onboarding/     ← Flujo de perfil inicial
│   │       │   ├── user/           ← Perfil, fotos, disponibilidad
│   │       │   ├── matching/       ← Swipe, likes, matches, 2pa2
│   │       │   ├── plans/          ← Planes universitarios
│   │       │   ├── chat/           ← Mensajería en tiempo real
│   │       │   ├── reputation/     ← Sistema de calificaciones
│   │       │   ├── notifications/  ← Notificaciones push/WS
│   │       │   ├── ai_assistant/   ← Icebreakers y date coach
│   │       │   └── modo_desparche/ ← Sesiones grupales con IA
│   │       └── shared/             ← Utilidades: audit, broker, etc.
│   │
│   ├── api-media/                  ← Servicio de procesado de imágenes (FastAPI)
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   │
│   └── worker-ai/                  ← Worker IA (Ollama/LLM)
│       ├── Dockerfile
│       └── requirements.txt
│
├── infrastructure/
│   ├── docker-compose.yml          ← Orquestación completa
│   ├── nginx/default.conf          ← Configuración Nginx
│   ├── postgres/init.sql           ← Inicialización de la BD
│   └── prometheus/prometheus.yml   ← Configuración de métricas
│
├── kora_app/                       ← App Flutter
│   ├── .env.example                ← Variables de la app (copiar como .env)
│   ├── pubspec.yaml
│   ├── android/
│   │   └── app/
│   │       └── google-services.example.json   ← Plantilla (ver configuración Firebase)
│   └── lib/
│       ├── main.dart               ← Punto de entrada, routing principal
│       ├── theme.dart              ← Colores, gradientes, tema global
│       ├── provider_auth.dart      ← Estado de autenticación
│       ├── provider_chat.dart      ← Estado del chat
│       ├── provider_matching.dart  ← Estado del matching
│       ├── provider_plans.dart     ← Estado de planes
│       ├── api_client.dart         ← Cliente HTTP + refresh automático de JWT
│       ├── services/
│       │   ├── auth_service.dart   ← Llamadas HTTP de auth, tokens en SharedPrefs
│       │   └── notification_service.dart
│       ├── screen_splash.dart      ← Pantalla de bienvenida + T&C
│       ├── screen_login.dart       ← Login con Google institucional
│       ├── screen_onboarding.dart  ← Flujo de perfil inicial
│       ├── screen_home.dart        ← Navegación principal
│       ├── screen_discovery.dart   ← Discovery / swipe
│       ├── screen_chat_*.dart      ← Lista de chats y detalle
│       ├── screen_mfa.dart         ← Verificación MFA
│       ├── screen_debug_login.dart ← Login email/password (solo DEBUG)
│       └── ...
│
└── storage/
    ├── uploads/                    ← Imágenes subidas (montado en Docker)
    └── logs/                       ← Logs de la API
```

---

## Requisitos previos

### Backend
- [Docker](https://www.docker.com/) >= 24.x
- [Docker Compose](https://docs.docker.com/compose/) >= 2.x
- Cuenta de [Firebase](https://firebase.google.com/) con un proyecto creado

### App Flutter
- [Flutter](https://flutter.dev/) >= 3.22 (SDK `>=3.3.0 <4.0.0`)
- Android Studio o VS Code con extensión Flutter
- Emulador Android / dispositivo físico / Chrome (para web)

---

## Configuración de Firebase

KORA usa Firebase para autenticación (Google Sign-In). Necesitas un proyecto de Firebase configurado.

### 1. Crear proyecto en Firebase Console

1. Ve a [Firebase Console](https://console.firebase.google.com/) y crea un nuevo proyecto.
2. En **Authentication** → **Sign-in method**, habilita **Google**.
3. Añade el dominio `localhost` (y tu dominio de producción) en **Dominios autorizados**.

### 2. Credenciales del backend (Firebase Admin SDK)

1. Firebase Console → **Configuración del proyecto** → **Cuentas de servicio**.
2. Clic en **Generar nueva clave privada** → descarga el archivo JSON.
3. Renómbralo a `firebase-credentials.json` y colócalo en:
   ```
   apps/api-core/src/firebase-credentials.json
   ```
   > ⚠️ Este archivo está en `.gitignore`. Nunca lo subas a git. Usa `firebase-credentials.example.json` como referencia de la estructura.

### 3. google-services.json (app Android)

1. Firebase Console → **Configuración del proyecto** → **Tus apps** → Añade una app Android.
2. Package name: el que tengas en `kora_app/android/app/build.gradle` (ej. `com.tuempresa.kora`).
3. Descarga el `google-services.json` y colócalo en:
   ```
   kora_app/android/app/google-services.json
   ```
   > ⚠️ También está en `.gitignore`. Usa `google-services.example.json` como referencia.

### 4. Web API Key

La encuentras en Firebase Console → **Configuración del proyecto** → **General** → **Clave de API web**. La necesitas para el `.env` del backend (`FIREBASE_WEB_API_KEY`), únicamente en modo debug.

---

## Instalación del backend

### 1. Clonar y preparar variables de entorno

```bash
git clone https://github.com/tu-org/kora.git
cd kora

# Copiar y editar el .env
cp .env.example .env
nano .env   # o tu editor preferido
```

Variables mínimas que **debes** cambiar:
- `SECRET_KEY` — clave secreta de Django (genera una con `python -c "import secrets; print(secrets.token_hex(50))"`)
- `DB_PASSWORD` — password de PostgreSQL
- `JWT_SIGNING_KEY` — clave para firmar JWT
- `ALLOWED_EMAIL_DOMAIN` — dominio institucional de tu universidad
- `FIREBASE_WEB_API_KEY` — solo si usarás el modo debug

### 2. Colocar credenciales de Firebase

```bash
# Copia tu archivo descargado de Firebase Console
cp ~/Downloads/tu-proyecto-firebase-adminsdk-xxxxx.json \
   apps/api-core/src/firebase-credentials.json
```

### 3. Levantar con Docker Compose

```bash
cd infrastructure
docker compose up -d --build
```

La primera vez Docker construirá las imágenes y ejecutará las migraciones automáticamente. Espera ~1 minuto.

### 4. Verificar que todo está corriendo

```bash
docker compose ps
# Todos los servicios deben aparecer como "healthy" o "running"

# Verificar health check de la API
curl http://localhost:80/health/
# → {"status": "ok"}
```

### 5. Acceder al panel de administración

Con `DEBUG=True`, se crea automáticamente un superusuario con las credenciales definidas en `.env`:

```
http://localhost:80/admin/
Usuario: DJANGO_SUPERUSER_EMAIL
Password: DJANGO_SUPERUSER_PASSWORD
```

### Comandos útiles de Docker

```bash
# Ver logs de la API
docker compose logs -f api-core

# Reiniciar solo la API (tras un cambio de código)
docker compose restart api-core

# Detener todo
docker compose down

# Detener y borrar volúmenes (⚠️ borra la base de datos)
docker compose down -v

# Ejecutar migraciones manualmente
docker compose exec api-core python manage.py migrate

# Abrir shell de Django
docker compose exec api-core python manage.py shell
```

---

## Instalación de la app Flutter

### 1. Variables de entorno de la app

```bash
cd kora_app
cp .env.example .env
```

El `.env` de la app controla las URLs del backend:

```env
API_URL=http://10.0.2.2:8000      # Android emulator → host
API_URL_WEB=http://localhost:8000  # Web / desktop
WS_URL=ws://10.0.2.2:8000
WS_URL_WEB=ws://localhost:8000
```

> `10.0.2.2` es la IP especial que el emulador de Android usa para referirse al localhost de tu máquina.

### 2. Colocar google-services.json

```bash
cp ~/Downloads/google-services.json kora_app/android/app/google-services.json
```

### 3. Instalar dependencias y ejecutar

```bash
flutter pub get
flutter run
```

Para web:
```bash
flutter run -d chrome
```

### Dependencias principales de Flutter

| Paquete                     | Uso                                      |
|-----------------------------|------------------------------------------|
| `firebase_core`             | Inicialización de Firebase               |
| `firebase_auth`             | Autenticación Firebase                   |
| `google_sign_in`            | Flujo nativo de Google Sign-In           |
| `provider`                  | Gestión de estado                        |
| `http`                      | Llamadas HTTP al backend                 |
| `web_socket_channel`        | Chat en tiempo real                      |
| `shared_preferences`        | Persistencia local de tokens JWT         |
| `flutter_dotenv`            | Lectura del `.env`                       |
| `cached_network_image`      | Carga y caché de imágenes de perfil      |
| `image_picker`              | Selección de fotos para el perfil        |
| `flutter_local_notifications`| Notificaciones locales                  |
| `flutter_animate`           | Animaciones declarativas                 |

---

## Variables de entorno

### Backend — `.env` (raíz del proyecto)

| Variable                  | Obligatoria | Descripción                                                  |
|---------------------------|-------------|--------------------------------------------------------------|
| `SECRET_KEY`              | ✅          | Clave secreta de Django. Cámbiala en producción.             |
| `DEBUG`                   | ✅          | `True` en desarrollo, `False` en producción.                 |
| `ALLOWED_HOSTS`           | ✅          | Hosts permitidos. En producción, pon tu dominio.             |
| `DB_NAME`                 | ✅          | Nombre de la base de datos PostgreSQL.                       |
| `DB_USER`                 | ✅          | Usuario de PostgreSQL.                                       |
| `DB_PASSWORD`             | ✅          | Password de PostgreSQL.                                      |
| `DB_HOST`                 | ✅          | Host de PostgreSQL (usa `db` dentro de Docker).              |
| `REDIS_URL`               | ✅          | URL de Redis.                                                |
| `ALLOWED_EMAIL_DOMAIN`    | ✅          | Dominio institucional (ej. `universidad.edu.co`). Vacío = cualquier Google (solo dev). |
| `FIREBASE_CREDENTIALS_PATH` | ✅        | Ruta al JSON de Firebase Admin SDK.                          |
| `FIREBASE_WEB_API_KEY`    | Solo debug  | Web API Key de Firebase. Solo para `/auth/debug/login/`.     |
| `JWT_SIGNING_KEY`         | ✅          | Clave para firmar tokens JWT.                                |
| `SERVICE_TOKEN`           | ✅          | Token interno entre microservicios.                          |
| `MFA_ISSUER_NAME`         | No          | Nombre mostrado en Google Authenticator.                     |
| `DJANGO_SUPERUSER_EMAIL`  | Dev         | Email del admin creado automáticamente en DEBUG.             |
| `DJANGO_SUPERUSER_PASSWORD` | Dev       | Password del admin creado automáticamente en DEBUG.          |
| `GRAFANA_USER`            | No          | Usuario de Grafana.                                          |
| `GRAFANA_PASSWORD`        | No          | Password de Grafana.                                         |
| `OLLAMA_URL`              | No          | URL de Ollama para IA local.                                 |
| `GEMINI_API_KEY`          | No          | API Key de Google Gemini (alternativa de IA).                |

### App Flutter — `kora_app/.env`

| Variable        | Descripción                                               |
|-----------------|-----------------------------------------------------------|
| `API_URL`       | URL del backend para Android emulator (`http://10.0.2.2:8000`). |
| `API_URL_WEB`   | URL del backend para web/desktop (`http://localhost:8000`). |
| `WS_URL`        | URL WebSocket para Android emulator.                      |
| `WS_URL_WEB`    | URL WebSocket para web/desktop.                           |

---

## API — Referencia de endpoints

Base URL: `http://localhost:80/api/v1/`

Todos los endpoints protegidos requieren el header:
```
Authorization: Bearer <access_token>
```

### Autenticación — `/api/v1/auth/`

| Método | Endpoint               | Auth | Descripción                                           |
|--------|------------------------|------|-------------------------------------------------------|
| POST   | `google/`              | No   | Login con Google. Recibe `id_token` de Firebase.      |
| GET    | `me/`                  | ✅   | Datos del usuario autenticado.                        |
| POST   | `token/refresh/`       | No   | Refresca el access token con el refresh token.        |
| POST   | `logout/`              | ✅   | Invalida el refresh token (blacklist).                |
| GET    | `mfa/setup/`           | ✅   | Genera QR para configurar Google Authenticator.       |
| POST   | `mfa/activate/`        | ✅   | Activa MFA verificando el primer código TOTP.         |
| POST   | `mfa/verify/`          | No   | Verifica código MFA al iniciar sesión.                |
| POST   | `mfa/deactivate/`      | ✅   | Desactiva MFA.                                        |
| POST   | `debug/login/`         | No   | ⚠️ Solo DEBUG. Login con email+password de Firebase.  |
| POST   | `debug/register/`      | No   | ⚠️ Solo DEBUG. Registro con email+password.           |

**Ejemplo — Login con Google:**
```json
POST /api/v1/auth/google/
{ "id_token": "<firebase_id_token>" }

→ 200 OK
{
  "access": "eyJ...",
  "refresh": "eyJ...",
  "user": { "id": 1, "email": "usuario@universidad.edu.co", ... }
}
```

---

### Usuarios — `/api/v1/users/`

| Método | Endpoint                  | Auth | Descripción                          |
|--------|---------------------------|------|--------------------------------------|
| GET    | `me/`                     | ✅   | Perfil completo del usuario actual.  |
| PATCH  | `me/profile/`             | ✅   | Actualiza datos del perfil.          |
| PATCH  | `me/disponibilidad/`      | ✅   | Activa/desactiva disponibilidad.     |
| POST   | `me/foto/`                | ✅   | Sube foto de perfil.                 |
| GET    | `nearby/`                 | ✅   | Usuarios cercanos al campus.         |
| GET    | `<id>/`                   | ✅   | Perfil público de otro usuario.      |

---

### Onboarding — `/api/v1/onboarding/`

Flujo de configuración del perfil tras el primer login. Los pasos son secuenciales.

| Método | Endpoint          | Auth | Descripción                                  |
|--------|-------------------|------|----------------------------------------------|
| GET    | `estado/`         | ✅   | Estado actual del onboarding.                |
| POST   | `terminos/`       | ✅   | Aceptar términos y condiciones.              |
| POST   | `basico/`         | ✅   | Nombre, fecha de nacimiento, género.         |
| POST   | `intenciones/`    | ✅   | Qué busca el usuario (pareja, amigos, etc.). |
| POST   | `preferencias/`   | ✅   | Preferencias de matching.                    |
| POST   | `personal/`       | ✅   | Bio e intereses.                             |
| POST   | `institucional/`  | ✅   | Carrera, facultad, semestre.                 |
| POST   | `fotos/`          | ✅   | Subir fotos adicionales del perfil.          |
| GET    | `fotos/lista/`    | ✅   | Listar fotos del perfil.                     |
| DELETE | `fotos/<id>/`     | ✅   | Eliminar una foto.                           |
| POST   | `completar/`      | ✅   | Marcar onboarding como completado.           |

---

### Matching — `/api/v1/matching/`

| Método | Endpoint                          | Auth | Descripción                                    |
|--------|-----------------------------------|------|------------------------------------------------|
| GET    | `deck/`                           | ✅   | Deck de perfiles para hacer swipe.             |
| POST   | `swipe/`                          | ✅   | Registrar un swipe (like/dislike/superlike).   |
| GET    | `bandeja/`                        | ✅   | Bandeja de likes recibidos.                    |
| POST   | `responder/<like_id>/`            | ✅   | Aceptar o rechazar un like.                    |
| POST   | `contrapropuesta/<id>/responder/` | ✅   | Responder una contrapropuesta.                 |
| GET    | `matches/`                        | ✅   | Listado de matches activos.                    |
| POST   | `bloquear/<user_id>/`             | ✅   | Bloquear a un usuario.                         |
| GET    | `likes-restantes/`                | ✅   | Cuántos likes quedan hoy.                      |
| POST   | `2pa2/crear/`                     | ✅   | Crear una dupla para matching en pareja.       |
| POST   | `2pa2/<id>/aceptar/`              | ✅   | Aceptar invitación a dupla.                    |
| POST   | `2pa2/<id>/buscar/`               | ✅   | Buscar otras duplas para hacer match.          |
| POST   | `2pa2/<match_id>/responder/`      | ✅   | Responder match de dupla.                      |
| GET    | `2pa2/mis-duplas/`                | ✅   | Duplas activas del usuario.                    |

---

### Planes — `/api/v1/plans/`

| Método | Endpoint                       | Auth | Descripción                                   |
|--------|--------------------------------|------|-----------------------------------------------|
| GET    | ``                             | ✅   | Feed de planes disponibles.                   |
| POST   | `crear/`                       | ✅   | Crear un nuevo plan.                          |
| GET    | `mis-planes/`                  | ✅   | Planes creados o a los que asistirás.         |
| GET    | `pendientes-calificar/`        | ✅   | Planes pasados pendientes de calificación.    |
| GET    | `<id>/`                        | ✅   | Detalle de un plan.                           |
| POST   | `<id>/asistir/`                | ✅   | Unirse a un plan.                             |
| POST   | `<id>/cancelar/`               | ✅   | Cancelar asistencia a un plan.               |
| POST   | `<id>/checkin/`                | ✅   | Hacer check-in al llegar al plan.             |

---

### Chat — `/api/v1/chat/`

| Método | Endpoint                               | Auth | Descripción                          |
|--------|----------------------------------------|------|--------------------------------------|
| GET    | `conversaciones/`                      | ✅   | Lista de conversaciones activas.     |
| GET    | `conversaciones/<room_id>/mensajes/`   | ✅   | Historial de mensajes de una sala.   |

El chat en tiempo real usa **WebSocket** (ver sección WebSockets).

---

### Reputación — `/api/v1/reputation/`

| Método | Endpoint               | Auth | Descripción                              |
|--------|------------------------|------|------------------------------------------|
| POST   | `calificar/`           | ✅   | Calificar a un usuario tras un plan.     |
| GET    | `mi-score/`            | ✅   | Score de reputación propio.              |
| GET    | `usuario/<id>/`        | ✅   | Score de reputación de otro usuario.     |

---

### IA — `/api/v1/ai/`

| Método | Endpoint       | Auth | Descripción                                           |
|--------|----------------|------|-------------------------------------------------------|
| POST   | `icebreaker/`  | ✅   | Genera preguntas icebreaker para iniciar conversación.|
| POST   | `coach/`       | ✅   | Date coach: sugerencias para una cita.                |

---

### Modo Desparche — `/api/v1/desparche/`

Sesiones grupales con rondas de presentación y votación asistida por IA.

| Método | Endpoint                                   | Auth | Descripción                                 |
|--------|--------------------------------------------|------|---------------------------------------------|
| POST   | `sesiones/crear/`                          | ✅   | Crear una sesión de desparche.              |
| GET    | `sesiones/<id>/`                           | ✅   | Estado de la sesión.                        |
| POST   | `sesiones/<id>/unirse/`                    | ✅   | Unirse a una sesión.                        |
| POST   | `sesiones/<id>/iniciar/`                   | ✅   | Iniciar la sesión (organizador).            |
| POST   | `sesiones/<id>/siguiente/`                 | ✅   | Pasar a la siguiente ronda.                 |
| GET    | `sesiones/<id>/resultados/`                | ✅   | Resultados finales de la sesión.            |
| POST   | `rondas/<id>/completar/`                   | ✅   | Completar una ronda.                        |
| POST   | `rondas/<id>/votar/`                       | ✅   | Emitir voto en una ronda.                   |

---

## WebSockets

### Chat en tiempo real

```
ws://localhost:80/ws/chat/<room_id>/?token=<access_token>
```

**Enviar mensaje:**
```json
{ "type": "message", "content": "Hola!" }
```

**Recibir mensaje:**
```json
{
  "type": "message",
  "message_id": 42,
  "content": "Hola!",
  "sender_id": 7,
  "timestamp": "2024-11-15T20:30:00Z"
}
```

### Notificaciones

```
ws://localhost:80/ws/notifications/?token=<access_token>
```

Recibe notificaciones push en tiempo real (nuevos likes, matches, mensajes, etc.).

---

## Monitoreo

Con el stack levantado, accede a:

- **Grafana:** [http://localhost:3000](http://localhost:3000)  
  Usuario: `GRAFANA_USER` · Password: `GRAFANA_PASSWORD` (ver `.env`)
  
- **Prometheus:** [http://localhost:9090](http://localhost:9090)

- **Métricas de la API:** [http://localhost:8000/metrics/](http://localhost:8000/metrics/)

---

## Modo debug

Cuando `DEBUG=True`, están disponibles dos endpoints especiales que permiten autenticarse con email y contraseña sin necesidad de un correo institucional. Útil durante el desarrollo.

### Registro debug

```json
POST /api/v1/auth/debug/register/
{
  "email": "test@cualquierdominio.com",
  "password": "mipassword123",
  "nombre": "Nombre de prueba"
}
```

### Login debug

```json
POST /api/v1/auth/debug/login/
{
  "email": "test@cualquierdominio.com",
  "password": "mipassword123"
}
```

Requiere que `FIREBASE_WEB_API_KEY` esté configurada en el `.env`.

En la app Flutter, el botón de debug **solo aparece cuando la app corre en modo debug** (`kDebugMode = true`), es decir, nunca en un build de release.

---

## Flujo de autenticación

```
Usuario toca "Continuar con correo institucional"
        │
        ▼
Google Sign-In (nativo en móvil / popup en web)
        │
        ├── Usuario cancela → vuelve al login
        │
        ▼
Firebase: obtiene ID Token (JWT firmado por Google)
        │
        ▼
POST /api/v1/auth/google/  { id_token }
        │
        ├── Dominio no institucional → 403 PermissionDenied
        ├── Email no verificado     → 403 PermissionDenied
        ├── Token inválido          → 401 AuthenticationFailed
        │
        ▼
Backend valida token con Firebase Admin SDK
        │
        ├── Usuario nuevo → se crea en BD + perfil de onboarding
        └── Usuario existente → se recupera
        │
        ├── MFA activo → devuelve { mfa_required: true, mfa_token }
        │       │
        │       ▼
        │   App navega a MfaScreen
        │   Usuario ingresa código TOTP
        │   POST /api/v1/auth/mfa/verify/
        │
        └── Sin MFA → devuelve { access, refresh, user }
                │
                ▼
        App guarda tokens en SharedPreferences
                │
                ├── perfil_completo = false → OnboardingScreen
                └── perfil_completo = true  → HomeScreen
```

### Refresh automático de tokens

`ApiClient` intercepta errores `401` y automáticamente llama a `POST /auth/token/refresh/` con el refresh token. Si el refresh también falla, cierra la sesión y redirige al login.

---

## Seguridad y producción

Antes de llevar KORA a producción, asegúrate de:

- [ ] `DEBUG=False` en el `.env`
- [ ] `SECRET_KEY` única y larga (mínimo 50 caracteres aleatorios)
- [ ] `JWT_SIGNING_KEY` única y diferente al `SECRET_KEY`
- [ ] `ALLOWED_HOSTS` con tu dominio real (no `*`)
- [ ] `ALLOWED_EMAIL_DOMAIN` configurado con el dominio de tu universidad
- [ ] HTTPS habilitado en Nginx (añadir certificado SSL/TLS)
- [ ] `DB_PASSWORD` segura y no la default
- [ ] `GRAFANA_PASSWORD` cambiada
- [ ] Credenciales de Firebase (`firebase-credentials.json`) fuera del repositorio
- [ ] Los endpoints `/auth/debug/*` inactivos (requieren `DEBUG=True`)
- [ ] Backups automáticos de PostgreSQL configurados

---

<div align="center">
Hecho con 💜 para comunidades universitarias
</div>
