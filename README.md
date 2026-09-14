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
- **Configurable**: Puedes verificar o cambiar la URL del servidor desde la app tocando el ícono de nube (☁️).

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
