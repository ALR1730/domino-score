# Registro de Cambios — Plan de Mejoras

> Cada fase del [`PLAN_DE_EJECUCION.md`](./PLAN_DE_EJECUCION.md) documenta aquí sus cambios,
> con los archivos tocados y el motivo de cada uno.

---

## Fase 1 — Seguridad del backend (2026-10-20)

**Objetivo:** cerrar la autenticación decorativa por PIN, el CORS abierto y la exposición de información.

| Archivo | Cambio |
|---------|--------|
| `backend/src/middleware/rateLimit.js` *(nuevo)* | Limitador de intentos en memoria sin dependencias (fuerza bruta de PINs). Ventana de 15 min por IP, con limpieza periódica y `Retry-After`. |
| `backend/src/server.js` | CORS con lista blanca (`CORS_ORIGINS`, por defecto `https://alr1730.github.io` + localhost en desarrollo). Requests sin cabecera `Origin` (APK Flutter, curl) no se ven afectados. Se deshabilita `X-Powered-By`, se añaden `nosniff`/`X-Frame-Options`/`Referrer-Policy`/HSTS, se activa `trust proxy` (Render) y un manejador global de errores que nunca filtra stack traces. `/health` deja de listar `features`. |
| `backend/src/routes/leagues.js` | `GET /:id` ya **no devuelve el PIN** (solo `/join`, que exige acertarlo, lo sigue devoliendo porque el cliente lo necesita para sync/borrar). `POST /sync` exige PIN correcto si la liga existe. `POST /:id/matches` exige PIN (o PIN explícito para auto-creación). Endpoints de participantes exigen PIN. Rate limiting: 10 intentos/15 min en join/delete/participants, 60 en matches y 600 en sync (este lo llama el cliente cada 12 s). Se eliminó el doble `decodeURIComponent` del nombre de participante (crash con `%`). |
| `backend/src/models/store.js` | `syncLeague` ya **nunca sobrescribe el PIN almacenado** desde el payload del cliente. |
| `backend/test/api.test.js` | El test de partidas ahora envía PIN (nuevo contrato) + 5 aserciones nuevas: PIN no expuesto en `GET /:id`, sync con PIN inválido → 401, sync no sobrescribe PIN, partida sin PIN → 401, participante sin PIN → 401. |

**Verificación:** 17/17 tests backend en verde; CORS comprobado manualmente (GitHub Pages reflejado, origen malicioso sin cabecera, requests sin Origin intactos).

**Nota de compatibilidad:** el APK publicado envía el PIN en sync y partidas, así que sigue funcionando. Dispositivos con un PIN local desincronizado recibirán un error claro de sync hasta unirse de nuevo con el PIN correcto (era el fallo de seguridad a corregir).

---

## Fase 2 — Integridad de datos del backend (2026-10-20)

**Objetivo:** que una respuesta "success" signifique que los datos quedaron persistidos, y eliminar la duplicación de la agregación de rankings.

| Archivo | Cambio |
|---------|--------|
| `backend/src/utils/rankings.js` *(nuevo)* | Módulo puro único de agregación (équipos/individuales, mensual/histórico, meses disponibles). **Bucketing de mes en UTC** para que el resultado no dependa de la TZ del servidor. Elimina la copia que existía entre `store.js` y `routes/rankings.js`. |
| `backend/src/models/store.js` | `save()` ahora es **async y awaited**: la escritura en MongoDB se confirma antes de responder y sus errores se propagan (→ 500 al cliente, que conserva sus datos locales y reintenta). Solo se persiste la liga afectada en vez de todas en cada escritura. `deleteLeague` borra de Mongo primero (sin estados a medias). IDs de partida con `crypto.randomUUID()`. Eliminados los blocklists hardcodeados de ligas de prueba (LIG-1001, "Liga de Prueba CI", …) del código de producción. Colisión de ID de liga resuelta con regeneración en vez de sobrescritura silenciosa. |
| `backend/src/middleware/asyncHandler.js` *(nuevo)* | Wrapper para que los handlers async propaguen errores a un manejador global (Express 4 no lo hace solo). |
| `backend/src/routes/leagues.js` | Handlers async + **validación real**: scores enteros ≥ 0, `winnerTeam` ∈ {1,2}, miembros como strings no vacíos → 400 en vez de coerción silenciosa (`Number("banana") || 0`). |
| `backend/src/routes/rankings.js` | Usa el módulo compartido; pierde 110 líneas de duplicación. |
| `backend/src/server.js` | **Arranque con fallo fatal** si `MONGODB_URI` está definido pero la conexión falla: antes caía en silencio al archivo efímero de Render (datos perdidos en cada redeploy). Override de emergencia: `ALLOW_LOCAL_FALLBACK=true`. |
| `render.yaml` | `healthCheckPath: /health` para que Render detecte servicios caídos. |
| `backend/test/api.test.js` | Usa `DATA_DIR` temporal (deja de mutar el `leagues.json` commiteado), limpieza async y 3 tests nuevos: 400 por puntaje inválido, 400 por `winnerTeam` inválido y regresión del crash con `%` en nombres de participantes. |

**Verificación:** 20/20 tests backend en verde; el árbol de trabajo ya no ensucia `backend/data/leagues.json`. Neto: **-159 líneas**.

---

## Fase 3 — Flutter: eliminación de duplicación (2026-10-20)

**Objetivo:** una sola implementación de cada diálogo y de cada cálculo de ranking; listas grandes con `itemBuilder`.

| Archivo | Cambio |
|---------|--------|
| `lib/widgets/league_dialogs.dart` *(nuevo)* | Los 6 diálogos duplicados entre `league_home_screen` y `league_manager_screen` (crear ×2, unirse ×2, eliminar ×3 + eliminar-del-servidor, agregar participante) viven ahora en un solo lugar, con chrome común (`showAppDialog`), fila de botones común (`DialogActionButtons`), callbacks desacoplados y `TextEditingController` que se liberan en `dispose` (antes se filtraban en cada apertura). El diálogo de unirse acepta modo preseleccionado (gestor) o de búsqueda (home). |
| `lib/services/ranking_calculator.dart` *(nuevo)* | Implementación única de agregación (equipos/individual) y orden (victorias → winRate → puntos). Funciones puras reutilizables. |
| `lib/models/league.dart` | `getTeamsRankedForMonth` / `getPlayersRankedForMonth` delegan en el calculador; se elimina la copia local de agregación y orden (~120 líneas). Nuevo helper público `matchesForMonth`. |
| `lib/services/league_service.dart` | `getGlobalTeamsRanked` / `getGlobalPlayersRanked` delegan en el calculador (agregar en mapa compartido + fusionar estadísticas almacenadas como fallback histórico) — elimina la 2ª copia (~130 líneas). |
| `lib/services/leaderboard_service.dart` | `recordMatch` delega en el calculador (elimina la 3ª copia: putIfAbsent + contadores + `_updatePlayersFromTeam`); `teamsRanked` / `playersRanked` delegan en los ordenadores compartidos. |
| `lib/screens/league/league_home_screen.dart` | Los 3 diálogos + agregar participante reemplazados por llamadas a los compartidos (la pantalla pierde ~380 líneas); lista de participantes pasa a `ListView.builder` con `key` por participante; keys en rankings. |
| `lib/screens/league/league_manager_screen.dart` | Los 4 diálogos reemplazados por los compartidos (pierde ~470 líneas); listas local y del servidor a `ListView.builder` con `key` por liga. |
| `lib/screens/league/global_ranking_screen.dart` | Listas de Parejas/Individual a `ListView.builder` con `key` por equipo/jugador. **Fix del bug de insignias:** los puestos 2 y 3 ahora muestran sus iconos `looks_two`/`looks_3` (antes solo el puesto 1 mostraba icono; era la tarea 4.5, aprovechada aquí). |
| `lib/screens/leaderboard_screen.dart` | `key` por equipo/jugador en ambas listas. |
| `lib/screens/league/match_setup_screen.dart` | Defensa con `toSet()` contra participantes duplicados en el `DropdownButton` (crash por `values` duplicados). |

**Verificación:** `flutter analyze` sin issues; `flutter test` en verde (el test de ranking mensual confirma que la refactorización no cambia resultados). Los 3 archivos fuertemente reescritos (`league_home_screen`, `league_manager_screen`, `league_dialogs`) quedaron con formato `dart format` interno, aunque el resto del repo no lo cumple aún (se aborda en la Fase 6).


