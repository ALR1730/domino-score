# Regla: No compilar APKs localmente

- **PROHIBIDO** ejecutar `flutter build apk` o tareas de Gradle pesadas de Android de forma automática o proactiva en esta máquina local.
- Las compilaciones de APK consumen demasiada CPU, disco y memoria RAM en la máquina del usuario.
- La validación del código debe limitarse a `flutter analyze` y `flutter test`, que son instantáneos y ligeros.
- La generación de APKs se delega al pipeline de CI / GitHub Actions o únicamente si el usuario lo solicita explícitamente por escrito.
