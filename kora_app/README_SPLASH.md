# Configuración del Splash Screen nativo

El splash nativo de KORA usa `flutter_native_splash` para cubrir **todas las versiones de Android**
(incluyendo Android 12+ / API 31+ que usa la nueva SplashScreen API y **ignora** el `windowBackground`).

## Pasos obligatorios después de clonar

```bash
cd kora_app

# 1. Instalar dependencias
flutter pub get

# 2. Generar los archivos nativos del splash (OBLIGATORIO)
dart run flutter_native_splash:create
```

Ese comando genera automáticamente:
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `android/app/src/main/res/values/styles.xml` (incluye config para API 31+)
- `android/app/src/main/res/drawable-night/launch_background.xml`
- Los archivos de iOS equivalentes

## Si cambias el logo o el color

Edita `flutter_native_splash.yaml` y vuelve a ejecutar:
```bash
dart run flutter_native_splash:create
```

## Por qué no basta con editar los XML manualmente

Android 12+ (API 31+) usa la **SplashScreen API** del sistema, que tiene su propio
`windowSplashScreenBackground` y `windowSplashScreenAnimatedIcon`. Esos atributos
**solo** se pueden definir correctamente mediante `flutter_native_splash`,
que genera un `styles.xml` con los atributos del tema `Theme.SplashScreen`.
Editar el `windowBackground` directamente no tiene ningún efecto en Android 12+.
