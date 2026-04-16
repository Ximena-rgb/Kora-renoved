# 🎓 Kora — University Social Platform

Plataforma universitaria de conexión social construida sobre una arquitectura
**Event-Driven Microservices** con Django como monolito modular.

```
university-social-platform/
├── apps/
│   ├── api-core/        # API Principal — Django (Los 4 Pilares)
│   ├── api-media/       # Worker de imágenes (Pillow + NSFW)
│   └── worker-ai/       # Worker LLM (Gemini)
├── infrastructure/      # Docker Compose, Nginx, Prometheus, Postgres
├── storage/             # Volumen persistente (uploads, logs)
└── .env                 # Variables de entorno
```

---

## ⚡ Levantar el proyecto (primera vez)

### 1. Clonar y configurar variables de entorno

```bash
cp .env.example .env
# Editar .env con tus valores reales (SECRET_KEY, GEMINI_API_KEY, etc.)
```

### 2. Construir y levantar todos los servicios

```bash
cd infrastructure
docker compose up --build
```

### 3. Crear superusuario Django (opcional)

```bash
docker compose exec api-core python manage.py createsuperuser
```

---

## 🧩 Servicios y puertos

| Servicio         | Puerto | Descripción                          |
|-----------------|--------|--------------------------------------|
| `api-core`       | 8000   | API REST + WebSockets (Daphne ASGI)  |
| `nginx`          | 80     | Reverse proxy + archivos estáticos   |
| `db`             | 5432   | PostgreSQL 16                        |
| `redis`          | 6379   | Cache + Broker (Streams)             |
| `prometheus`     | 9090   | Métricas                             |
| `grafana`        | 3000   | Dashboards (admin / kora_grafana_2024)|
| `api-media`      | 9102   | Métricas worker imágenes             |
| `worker-ai`      | 9103   | Métricas worker AI                   |

---

## 🗺️ Endpoints principales

### Auth (`/api/v1/auth/`)
| Método | Ruta              | Descripción              |
|--------|-------------------|--------------------------|
| POST   | `register/`       | Registro con dominio @uni|
| POST   | `login/`          | Login → JWT              |
| POST   | `token/refresh/`  | Renovar access token     |
| POST   | `firebase/verify/`| Verificar Firebase MFA   |

### Users (`/api/v1/users/`)
| Método | Ruta                | Descripción              |
|--------|---------------------|--------------------------|
| GET    | `me/`               | Mi perfil                |
| PATCH  | `me/profile/`       | Actualizar perfil        |
| PATCH  | `me/disponibilidad/`| Activar disponibilidad   |
| POST   | `me/foto/`          | Subir foto → api-media   |
| GET    | `nearby/`           | Usuarios disponibles     |
| GET    | `<id>/`             | Perfil público           |

### Matching (`/api/v1/matching/`)
| Método | Ruta           | Descripción                   |
|--------|----------------|-------------------------------|
| GET    | `candidatos/`  | Lista rankeada por score      |
| POST   | `swipe/`       | Like / Pass                   |
| GET    | `matches/`     | Mis matches confirmados       |

### Plans (`/api/v1/plans/`)
| Método     | Ruta              | Descripción                        |
|------------|-------------------|------------------------------------|
| GET/POST   | `/`               | Listar / Crear plan                |
| GET        | `mis-planes/`     | Mis planes creados y unidos        |
| GET/PATCH/DELETE | `<id>/`    | Detalle / Editar / Cancelar        |
| POST       | `<id>/unirse/`    | Unirse al plan                     |
| POST       | `<id>/salir/`     | Salir del plan                     |

**Tipos de plan:** `dates_1_1` · `study_group` · `social_hang`

### AI Assistant (`/api/v1/ai/`)
| Método | Ruta           | Descripción                          |
|--------|----------------|--------------------------------------|
| POST   | `icebreaker/`  | Generar icebreaker para un match     |
| POST   | `coach/`       | Consultar al Date Coach              |

### Chat (`/api/v1/chat/`)
| Método   | Ruta                              | Descripción       |
|----------|-----------------------------------|-------------------|
| GET/POST | `conversaciones/`                 | Listar / Crear    |
| GET      | `conversaciones/<room>/mensajes/` | Historial         |

**WebSocket Chat:** `ws://host/ws/chat/<room_id>/?token=<jwt>`

**WebSocket Notificaciones:** `ws://host/ws/notifications/?token=<jwt>`

### Reputación (`/api/v1/reputation/`)
| Método | Ruta                | Descripción              |
|--------|---------------------|--------------------------|
| POST   | `calificar/`        | Calificar participante   |
| GET    | `pendientes/`       | Planes pendientes        |
| GET    | `usuario/<id>/`     | Ver reputación           |

---

## 🔄 Flujo del Message Broker (Redis Streams)

```
api-core  ──XADD──▶  stream:user.registered       ──▶  (scoring futuro)
api-core  ──XADD──▶  stream:match.created          ──▶  stream-consumer → WS notif
api-core  ──XADD──▶  stream:system.alert           ──▶  stream-consumer → WS fan-out
api-core  ──XADD──▶  stream:image.process_task     ──▶  api-media → procesa imagen
api-core  ──XADD──▶  stream:ai.coach_request       ──▶  worker-ai → Gemini → WS
api-core  ──XADD──▶  stream:audit.log              ──▶  (persistencia asíncrona)
```

---

## 🔭 Observabilidad

- **Prometheus:** http://localhost:9090
- **Grafana:** http://localhost:3000 (admin / kora_grafana_2024)
- **Métricas Django:** http://localhost:8000/metrics
- **Logs:** `storage/logs/api-core.log` (JSON rotativo)
- **Django Admin:** http://localhost:8000/admin/

---

## 🛠️ Comandos útiles

```bash
# Ver logs en tiempo real
docker compose logs -f api-core

# Crear migraciones nuevas
docker compose exec api-core python manage.py makemigrations

# Ejecutar tests
docker compose exec api-core pytest

# Acceder a la shell de Django
docker compose exec api-core python manage.py shell

# Ver streams en Redis
docker compose exec redis redis-cli XLEN stream:match.created
docker compose exec redis redis-cli XINFO GROUPS stream:image.process_task
```
