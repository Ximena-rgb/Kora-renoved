# CHANGELOG — KORA

Todos los cambios notables entre versiones se documentan aquí.

---

## [v2] — 2026-04-19

### 🆕 Nuevas funcionalidades

#### Backend — Módulo `academia`
- Nuevo módulo Django con modelos `Facultad` y `Programa` para gestionar la oferta académica del Pascual Bravo directamente desde el panel admin.
- Endpoints públicos: `GET /api/v1/academia/` (facultades activas con sus programas), `GET /api/v1/academia/<id>/programas/`.
- CRUD de admin (solo superusuarios): crear y desactivar programas.
- 2 migraciones incluidas: esquema inicial + datos iniciales con todas las facultades y programas de la institución.

#### Backend — Estado del usuario
- Nuevo campo `User.estado_usuario` con opciones: `activo`, `ocupado`, `inactivo`, `en_clases`.
- Indexado en BD para consultas eficientes de matching/presencia.
- Migración `0002_user_estado_usuario` incluida.

#### Backend — Perfil expandido (`UserProfile`)
- Campo `sexo_biologico` para validación de fotos (hombre / mujer / intersexual / prefiero no decir).
- Nuevos hábitos: `ejercicio`, `mascotas`, `cuales_mascotas`, `estilo_comunicacion`, `lenguaje_amor`, `nivel_escolaridad`.
- Campo `categorias_gustos` (ArrayField, hasta 14 categorías).
- Campo `horario_clases` (JSONField) para activar automáticamente el estado `en_clases`.
- Migraciones `0002_expand_profile_fields` y `0003_userprofile_sexo_biologico` incluidas.

#### Flutter — Splash screen nativo
- Integración de `flutter_native_splash` para splash nativo en Android 12+ e iOS.
- Fondo oscuro `#0A0A0F` con logo centrado. Configuración en `flutter_native_splash.yaml`.
- Asset principal: `assets/images/splash_logo.png`.

#### Flutter — `SplashScreen` (pantalla de bienvenida)
- Nueva pantalla mostrada solo en el primer arranque (sin sesión previa).
- Animaciones: fade-in del logo, slide-up del texto, pulso de escala, fade-out al continuar.
- Botón "Comenzar" que lleva al login.

#### Flutter — `EstadoBoton` (`widget_estado_boton.dart`)
- Widget en la barra superior para que el usuario cambie su estado en tiempo real.
- Muestra el estado actual con chip de color. Al tocar abre un bottom sheet con las 4 opciones.

#### Flutter — `widget_campus_map.dart`
- Nuevo widget de mapa del campus universitario.

#### Flutter — `screen_debug_login.dart`
- Pantalla de login rápido para desarrollo (solo DEBUG=True en backend).

---

### 🔧 Cambios y mejoras

#### Backend — Auth
- Lógica de separación `nombre/apellido` mejorada con convención colombiana: 1 parte = nombre; 2 = 1+1; 3 = 1+2; 4 = 2+2; 5 = 2+3; 6+ = 3+resto.
- Endpoints de debug: `POST /auth/debug/login/` y `POST /auth/debug/register/` (activos solo con `DEBUG=True`).
- JWT con clave de firma independiente (`JWT_SIGNING_KEY`).
- `FIREBASE_WEB_API_KEY` configurable para login de debug.

#### Backend — Settings y `.env.example`
- Variables nuevas: `JWT_SIGNING_KEY`, `FIREBASE_WEB_API_KEY`, `MFA_ISSUER_NAME`, `DJANGO_SUPERUSER_EMAIL`, `DJANGO_SUPERUSER_PASSWORD`, `OLLAMA_URL`, `OLLAMA_MODEL`.
- Documentación mejorada en el `.env.example`.

#### Flutter — `main.dart`
- Flujo de arranque: detecta si había sesión previa con `AuthService.getAccessToken()`. Si no había sesión → `SplashScreen`; si había → `LoginScreen`.
- `_KoraLoadingScreen`: loading animado con anillo giratorio de gradiente (SweepGradient) y pulso del logo con glow. Reemplaza el loader estático de v1.

#### Flutter — `screen_home.dart`
- Barra superior persistente con logo KORA (ShaderMask con gradiente) y `EstadoBoton`.
- Layout: `Column` → `SafeArea` → barra → `Divider` → `Expanded(IndexedStack(...))`.

#### Flutter — `pubspec.yaml`
- Dependencia añadida: `flutter_native_splash: ^2.4.1`.
- Configuración del splash embebida directamente en `pubspec.yaml`.

#### Flutter — Android
- Package renombrado de `com.example.kora_app` a `com.kora.app`.
- Drawables de splash actualizados (`splash_logo.png` en drawable y drawable-v21).
- `colors.xml` con colores de marca KORA.
- Estilos de ventana actualizados para splash nativo.

#### Flutter — Web
- `web/index.html` actualizado con meta splash y configuración mejorada del manifest.

---

### 🗂 Infraestructura / DevOps

#### `.gitignore` (nuevo)
- Cubre Python/Django, Flutter/Dart, Docker, Firebase, secretos, IDEs y storage.
- `storage/uploads/*` y `storage/logs/*` excluidos; los `.gitkeep` están incluidos.

#### Archivos de ejemplo para secretos
- `apps/api-core/src/firebase-credentials.example.json` — plantilla de credenciales Firebase.
- `kora_app/android/app/google-services.example.json` — plantilla de Google Services para Android.
- `kora_app/.env.example` — variables de entorno del cliente Flutter.

#### Storage
- `storage/logs/.gitkeep` y `storage/uploads/.gitkeep` para que git trackee los directorios vacíos.

---

## [v1] — 2026-04-15 *(versión inicial en GitHub)*

- Setup inicial del monorepo: `apps/api-core`, `apps/api-media`, `apps/worker-ai`.
- Módulos Django: `auth`, `chat`, `matching`, `onboarding`, `plans`, `reputation`, `user`, `audit`, `ai_assistant`, `modo_desparche`, `notifications`.
- App Flutter con login Google/Firebase, onboarding, discovery, chat, matching, planes y perfil.
- Infraestructura Docker con PostgreSQL, Redis, Nginx, Prometheus.
