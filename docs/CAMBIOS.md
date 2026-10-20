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

---

## Fase 4 — Código muerto y bugs de Flutter (2026-10-20)

**Objetivo:** eliminar código sin llamadas, conectar el tablero local que nunca se poblaba y corregir los bugs funcionales detectados en la revisión.

| Tarea | Archivo | Cambio |
|-------|---------|--------|
| 4.1 | `lib/services/leaderboard_service.dart` | `recordMatch` ahora recibe un `LeagueMatch` listo y devuelve `bool`; se añade `late final _loadFuture` que se espera en `recordMatch`/`resetLeaderboard` para evitar carreras con la carga inicial de SharedPreferences (un registro rápido no podía pisar ni ser pisado por la carga). |
| 4.1 | `lib/screens/domino_game_screen.dart` | Al terminar una partida **casual o de liga**, el resultado se registra en `LeaderboardService` → por fin el tab "En este Dispositivo" de la tabla de clasificación se pobla (antes el servicio estaba cableado a la UI pero nadie llamaba `recordMatch`). |
| 4.3 + 4.1 | `lib/models/game_state.dart` | Se elimina `_checkAndRecordMatch()` (cuerpo vacío) y `_matchRecorded` (nunca leído fuera ni escrito con significado; también desaparece de la persistencia). A cambio, `GameState` detecta ahora la transición real "en juego → terminada" con `_wasGameOver`/`_justFinished` y `consumeJustFinished()` (flag de un solo consumo). La línea base se fija al cargar desde prefs → una partida restaurada **no** se re-registra; `eliminarRonda` actualiza el flag para permitir deshacer la ronda decisiva y volver a jugar. |
| 4.1 / 4.7 | `lib/screens/domino_game_screen.dart` | Flujo de registro reescrito: `_onGameStateChanged` consume la transición, aplica el guard de puntaje 0, construye el `LeagueMatch` (miembros reales de liga o `NameParser.extractMembers` en casual) y `_recordResults` **espera** ambos registros (dispositivo + liga) antes de mostrar el SnackBar, con mensaje según lo que realmente pasó: liga registrada / liga ya no existe / clasificación local / solo victoria. |
| 4.7 | `lib/services/league_service.dart` | `recordMatchForActiveLeague` (registraba en la liga *activa* al **final** de la partida → podía cambiarse durante el juego) se reemplaza por `recordMatchToLeague(leagueId, match)` que usa el `leagueId` capturado al inicio (campo inmutable del widget) y devuelve `bool` si la liga existe. |
| 4.2 | `lib/services/api_client.dart` | Eliminados `updateBaseUrl`, `checkHealth` y `loadSavedBaseUrl`/`_prefKeyBaseUrl` (la URL era editable pero ya no hay UI que la edite: `baseUrl` pasa a `final` = `defaultBaseUrl`); se quita el import de `SharedPreferences`. `isServerAvailable` se mantiene (lo usa el home de ligas). El README no referenciaba estos métulos. |
| 4.6 | `lib/services/api_client.dart` | Constante única `requestTimeout = 45s` (antes 45s/20s/10s dispersos); `deleteLeague` envía el PIN **solo en el body** (el backend acepta body u query, así que los APKs viejos siguen funcionando) y desaparecen el fallback `POST /delete` y el mensaje de "Manual Deploy" (workaround de redeploy superado). |
| 4.6 | `lib/models/league.dart` | `LeagueMatch.toMap` envía `date` en UTC con sufijo `Z` → el backend agrupa por mes en UTC (consistente con la Fase 2); `fromMap` convierte a `.toLocal()` → la UI sigue agrupando por mes local del usuario. Fechas naïvas antiguas se siguen interpretando como locales (compatibilidad total con datos previos y APKs viejas). |
| 4.4 | `lib/services/league_service.dart` | Eliminada la purga de "ligas de prueba/demo" con IDs y nombres hardcodeados (`LIG-1001`, `Liga de Campeones Dominó`, `Prueba CI`…) en `loadData`: borraba datos de usuarios reales que coincidieran. Se conserva la limpieza de duplicados accidentales (mismo nombre+PIN sin partidas). |
| 4.5 | `lib/screens/league/global_ranking_screen.dart` | ✅ Completada dentro de la Fase 3 (puestos 2/3 ahora muestran sus medallas). |

**Compatibilidad:** sin cambios de contrato; el backend ya aceptaba fechas con `Z` y PIN en body. **Verificación:** `flutter analyze` sin issues; `flutter test` en verde.

---

## Fase 5 — Tests y CI (2026-10-20)

**Objetivo:** pasar de 2 tests (un smoke test) + un script manual a una batería real de tests en ambos lados.

| Tarea | Archivo | Cambio |
|-------|---------|--------|
| 5.1 | `test/game_state_test.dart` *(nuevo, 18 tests)* | Marcador, rondas (alta/edición/borrado y tolerancia a índices inválidos), ganador, meta y la nueva transición de fin de partida (`consumeJustFinished`, una sola vez; deshacer la ronda decisiva; baseline al restaurar). Persistencia con `SharedPreferences.setMockInitialValues`, incluida una partida restaurada ya terminada que **no** debe re-registrarse. |
| 5.2 | `test/name_parser_test.dart` *(nuevo)* + `test/ranking_calculator_test.dart` *(nuevo)* | `NameParser`: separadores, mayúsculas, diacríticos, claves independientes del orden, formato de nombres. `RankingCalculator`: orden (victorias → winRate → puntos), agregación de equipos/jugadores, normalización, fusión sin aliasar y los atajos agregar+ordenar. |
| 5.3 | `test/league_service_test.dart` *(nuevo)* + `lib/services/league_service.dart` | Tests de `LeagueService` con `SharedPreferences` mockeado y un **cliente HTTP falso** inyectado con `http.runWithClient` + `MockClient` (sin tocar la red): crear, unirse (local, servidor y error de conexión), `recordMatchToLeague` en liga no activa, borrado (local y rechazo del servidor), merge de sync sin duplicar partidas y rankings globales/mensuales. Se añade `resetForTesting()` (`@visibleForTesting`) porque el servicio es un singleton y cada test necesita partir de cero. |
| 5.4 | `backend/test/api.test.js` *(reescrito, 21 tests)* + `backend/package.json` | Migrado del script `runTests()` a **`node:test` + `fetch`** global: servidor en puerto efímero, `DATA_DIR` temporal (`mkdtemp`), sin dependencias nuevas. Cubre healthcheck y cabeceras, CORS (origen permitido/bloqueado), 404 JSON, flujo completo de liga, validaciones 400/401, PIN en sync/join/matches/participantes, nombres con `%`, lista pública sin PIN y el bucketing **UTC** de rankings mensuales en el endpoint real. `npm test` = `node --test "test/**/*.test.js"`. |
| 5.5 | `.github/workflows/backend-ci.yml` y `flutter-build.yml` | Clave de caché de npm corregida (`backend/package-lock.json` en vez de `package.json`) + `npm ci` reproducible; filtros `paths:` en ambos workflows para no ejecutar CI completo en cambios irrelevantes. |

**Verificación:** `flutter analyze` sin issues; **53 tests** de Flutter y **21 tests** del backend, todos en verde.

---

## Fase 6 — Pulido final (2026-10-20)

**Objetivo:** cerrar los detalles de configuración, documentación y calidad que quedaron pendientes en la revisión inicial.

| Tarea | Archivo | Cambio |
|-------|---------|--------|
| 6.1 | `pubspec.yaml` | Se quita `cupertino_icons` (sin un solo uso en el código), el constraint de SDK sube a `>=3.6.0` (mínimo real: la UI usa `Color.withValues`, Flutter 3.27 / Dart 3.6) y `flutter_lints` pasa a `^5.0.0`. |
| 6.2 | `analysis_options.yaml` + todo `lib/` y `test/` | Se activan reglas adicionales: `prefer_final_locals`, `prefer_final_in_for_each`, `avoid_slow_async_io`, `avoid_type_to_string`, `cancel_subscriptions`, `close_sinks`, `comment_references`, `directives_ordering`, `prefer_single_quotes`, `sort_child_properties_last`, `unawaited_futures`, `use_super_parameters`. Se corrigieron las violaciones reales (`directives_ordering` en 9 archivos, `unawaited(_syncMatchToServer(...))`) y se aplicó **`dart format` a todo el repo** (26 archivos reformateados). Se descartó `require_trailing_commas` por ser incompatible con el comportamiento por defecto de `dart format` (generaba 274 avisos de ruido). |
| 6.3 | `lib/main.dart` | Se elimina `fontFamily: 'Roboto'` hardcodeado: la fuente no estaba declarada en `pubspec.yaml`, así que se usa la fuente por defecto de la plataforma. |
| 6.4 | `lib/widgets/league_dialogs.dart`, `lib/services/league_service.dart`, `backend/src/routes/leagues.js`, `backend/src/models/store.js` | Los PINs por defecto pasan de `1234` (adivinable) a **4 dígitos aleatorios**, en cliente y servidor. `POST /api/leagues` ahora devuelve el `pin` en la **respuesta** (igual que `/join`) para que el creador lo conozca, pero **nunca** dentro del objeto `league` (`toSafeLeague` sigue eliminándolo). El servicio Flutter conserva el PIN local aunque el servidor no lo devuelva en el objeto. |
| 6.5 | `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`, `README.md` | `usesCleartextTraffic="false"` (todo el tráfico es HTTPS). Se documenta la firma de release pendiente en `build.gradle.kts` y en el README (keystore, `key.properties`, secrets de CI). |
| 6.6 | `README.md`, `docs/archive/` | README actualizado: se elimina la afirmación falsa de "URL del servidor configurable", se añade la sección de **Seguridad** (PIN aleatorio, PIN nunca expuesto salvo creación/join, CORS/cabeceras/rate limit), una de **Pruebas** y una de **Arquitectura** con enlaces a `docs/`. El `walkthrough.md` obsoleto (migración web→Flutter) se archiva en `docs/archive/walkthrough-flutter-migracion.md`. |

**Verificación:** `flutter analyze` sin issues; **54 tests** de Flutter y **22 tests** del backend en verde tras los cambios de PIN.


