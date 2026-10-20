# 🎲 Dominó Score - App Móvil & Web con Modo Liga y Casual

Aplicación móvil y web de anotación y gestión de partidas de dominó desarrollada en **Flutter**, con backend REST en **Node.js/Express** y despliegue continuo en **GitHub Actions**.

[![Flutter Build & Deploy](https://github.com/ALR1730/domino-score/actions/workflows/flutter-build.yml/badge.svg)](https://github.com/ALR1730/domino-score/actions/workflows/flutter-build.yml)
[![Backend CI](https://github.com/ALR1730/domino-score/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/ALR1730/domino-score/actions/workflows/backend-ci.yml)

---

## 🌐 Probar la Versión Web en Vivo

Puedes probar la aplicación en tiempo real desde cualquier navegador móvil o de escritorio sin instalar nada:

🔗 **[https://alr1730.github.io/domino-score/](https://alr1730.github.io/domino-score/)**

---

## 📱 Descargar Instalador APK para Android

Cada vez que se sube un cambio a la rama `main`, GitHub Actions genera automáticamente el instalador **APK** para Android:

1. Ve a la pestaña **[Actions](https://github.com/ALR1730/domino-score/actions)** en tu repositorio de GitHub.
2. Haz clic en la ejecución más reciente del flujo **Flutter Build & Deploy (Android APK & Web)**.
3. Al final de la página, en la sección **Artifacts**, haz clic en **`domino-score-android-apk`** para descargar el archivo ZIP.
4. Descomprime el ZIP y obtendrás `app-release.apk`, listo para transferir e instalar en tu teléfono o emulador Android.

---

## ✨ Características Principales

### 1. Modos de Juego
- **Modo Casual**: Anotación rápida de partidas (Nosotros vs Ellos) con selector de límite de puntos (100, 200, 300, personalizado) y botones de suma rápida (+25, +30, +50, +60).
- **Modo Liga**:
  - Registro de participantes individuales.
  - Selección de alineación de 4 jugadores (2 vs 2) sin permitir duplicados.
  - Generación de claves de equipo independientes del orden (`"Carlos y Juan"` == `"Juan & Carlos"`).
  - Protección de ligas mediante **clave/PIN**.
  - Historial detallado de partidas jugadas con fecha y puntuaciones.

### 2. Tablas de Clasificación
- **Clasificación por Liga**: Tabla de mejores equipos y mejores jugadores individuales de la liga activa.
- **Ranking General del Servidor**: Estadísticas agregadas de todas las ligas registradas en el servidor REST.

### 3. Backend REST & Sincronización en la Nube
- **Servidor en la Nube por Defecto**: `https://domino-score-backend.onrender.com`
- Sincronización automática de ligas, partidas y rankings con el backend REST en tiempo real entre múltiples dispositivos (PC, móvil y tablet).
- **100% Resiliente Offline**: Si no hay conexión o el servidor está en reposo, funciona con almacenamiento local (`SharedPreferences`).
- **URL fija del backend** incrustada en la app (`ApiClient.defaultBaseUrl`): no hay que configurarla a mano.

### 4. Seguridad
- Cada liga se protege con un **PIN de 4 dígitos aleatorio** (ya no se usa `1234` por defecto).
- El PIN viaja siempre en el cuerpo de las peticiones y **nunca** se devuelve salvo en las respuestas de creación/unirse (`/join`), pensadas para el creador.
- El backend aplica **CORS con lista blanca** de orígenes, cabeceras de seguridad y **límite de intentos** por IP en los endpoints que validan PIN.

---

## 🚀 Ejecución en Desarrollo Local

### Requisitos
- Flutter SDK (3.27+)
- Node.js (20+)

### Iniciar el Backend REST
```bash
cd backend
npm install
npm test
npm start
```
El servidor escuchará en `http://localhost:3000`.

### Iniciar la App Flutter
```bash
# Obtener dependencias
flutter pub get

# Ejecutar en Web
flutter run -d chrome

# Ejecutar en Android (con dispositivo conectado o emulador)
flutter run -d android

# Compilar APK localmente
flutter build apk --release
```

---

## 🧪 Pruebas

Cada cambio se valida con dos baterías completas:

```bash
# App Flutter (análisis estático + tests unitarios/widget)
flutter analyze
flutter test

# Backend Node.js (node:test + fetch, sin dependencias extra)
cd backend && npm test
```

Los tests del backend arrancan el servidor en un **puerto efímero** con un `DATA_DIR` temporal, por lo que nunca tocan los datos reales.

---

## 📐 Arquitectura

- **`lib/models/`**: modelos de dominio (`GameState`, `League`, `LeagueMatch`, `TeamStats`, `PlayerStats`).
- **`lib/services/`**:
  - `ranking_calculator.dart` — agregación y orden de rankings **pura** (única fuente de verdad, compartida por liga, dispositivo y servidor-local).
  - `league_service.dart` / `leaderboard_service.dart` — estado de ligas y clasificación del dispositivo.
  - `api_client.dart` — cliente REST (URL fija, timeouts unificados).
- **`lib/screens/`** y **`lib/widgets/`**: UI; los diálogos de liga viven en `widgets/league_dialogs.dart`.
- **`backend/`**: Express + MongoDB Atlas con *fallback* a archivo local; rankings en `src/utils/rankings.js`.

El histórico de cambios por fases está en [`docs/CAMBIOS.md`](docs/CAMBIOS.md) y el plan en [`docs/PLAN_DE_EJECUCION.md`](docs/PLAN_DE_EJECUCION.md).

---

## 🔐 Firma de release (Android)

El APK de release se compila hoy con las **claves de debug** (`android/app/build.gradle.kts`), suficiente para pruebas internas pero **no** para publicar en Google Play. Para firmar en serio:

1. Genera un keystore: `keytool -genkey -v -keystore ~/domino-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias domino`.
2. Crea `android/key.properties` (ya está en `.gitignore`):
   ```properties
   storePassword=TU_PASSWORD
   keyPassword=TU_PASSWORD
   keyAlias=domino
   storeFile=/ruta/absoluta/domino-release.jks
   ```
3. En `android/app/build.gradle.kts`, carga ese archivo y usa un `signingConfig` de release en `buildTypes.release`.
4. Guarda los secretos como *secrets* de GitHub Actions si quieres que el CI firme automáticamente.

> El `AndroidManifest.xml` fija `android:usesCleartextTraffic="false"`: todo el tráfico es HTTPS (el backend de Render ya lo es).
