# Plan de Ejecución v2 — Hardening, Corrección de Bugs y Estabilización en Producción (Dominó Score)

> **Protocolo:** `ALPHA` (ALR COMPANY)
> **Estado:** Borrador para revisión y aprobación de **Angel Luis Rosario** (no ejecutar código hasta aprobación)
> **Fecha:** 2026-11-20
> **Entorno vivo protegido:**
> - Backend REST en producción: `https://domino-score-backend.onrender.com` + MongoDB Atlas (colección `leagues`)
> - App Web desplegada: `https://alr1730.github.io/domino-score/`
> - APKs Android ya instalados en dispositivos con estado local en `SharedPreferences`

---

## 0. Principios Innegociables de Producción (Zero-Data-Loss & Zero-Downtime)

Todo cambio en este plan debe respetar las siguientes reglas para **no corromper data existente ni romper dispositivos ya instalados**:

1. **Orden de despliegue obligatorio (Expand → Deploy Backend → Verify → Deploy Flutter → Contract):**
   - El backend siempre mantiene retrocompatibilidad con APKs actuales antes de desplegar cambios en el cliente.
2. **Inmutabilidad de claves locales (`SharedPreferences`):**
   - Jamás renombrar ni borrar las 5 claves activas: `domino_casual_game_state_v2`, `domino_leagues_registry_v1`, `domino_active_league_id_v1`, `domino_leaderboard_teams_v1`, `domino_leaderboard_players_v1`.
   - Todo `fromMap()` tolera campos ausentes, fechas con o sin sufijo `Z`, y números `int`/`double`.
3. **Respeto a documentos existentes en MongoDB Atlas:**
   - Todos los documentos actuales (`_id`, `id: "LIG-####"`, `pin`, `participants`, `teams`, `players`, `matches`) siguen siendo válidos sin migraciones destructivas.
   - Ninguna migración de esquema de BD (Fase 4: `pin` → `pinHash`) se ejecuta sin **backup verificado de Atlas** y **aprobación explícita de Angel Luis Rosario**.
4. **Cero compilación local de APK:**
   - Validación local estrictamente vía `cd backend && npm test`, `cd backend && npm audit --omit=dev`, `flutter analyze`, `flutter test` y `dart format --output=none --set-exit-if-changed lib test` (regla `.agents/rules/no_local_apk_build.md`).
5. **Flujo TDD por fase:**
   - Para cada fase de código (Fases 1–5): escribir/delegar tests fallidos primero (**Red**, `alr-qa-tdd`), implementar mínimo para pasar (**Green**), refactorizar (**Refactor**) y cerrar con gate `alr-zeta`.
6. **Entrega obligatoria por Pull Request:**
   - Cada fase se desarrolla en una rama dedicada desde `main` y se integra mediante Pull Request para trazabilidad, revisión y validación automática en CI antes de mergear.

---

## Resumen de Prioridad y Secuencia de Despliegue

| Prioridad | Fase | Objetivo | Riesgo sobre prod/data | Requiere migración BD |
| :--- | :--- | :--- | :--- | :--- |
| **P0-A** | **Fase 0** ✅ Completada | Contención de seguridad e higiene (CVEs, Docker, secretos, graceful shutdown) | Nulo | No |
| **P0-B** | **Fase 1** ✅ Completada | Endurecimiento del backend e integridad Mongo-first (100% retrocompatible) | Muy bajo | No |
| **P0-C** | **Fase 2** ✅ Completada | Corrección de bugs silenciosos en Flutter (pérdida de partidas, Casual, GlobalRanking, race conditions) | Bajo | No |
| **P1** | **Fase 3** | Sincronización de participantes, eficiencia de red, pulido móvil/web y CI sin falsos verdes | Bajo | No |
| **P1/P2** | **Fase 4** | Migración de PINs a `scrypt` (`pinHash`) en MongoDB Atlas (Expand → Dual-Read → Migrate) | Medio (controlado con backup) | **Sí (aprobación explícita)** |
| **P2** | **Fase 5** | Refactorización arquitectónica gradual (BETA, dividir pantallas, repositorios Mongo directos) | Medio | No (índices aditivos) |

---

## FASE 0 (P0-A) — Contención Inmediata de Seguridad e Higiene Operativa ✅ Completada

**Por qué primero:** Cierra 1 CVE **Critical** (`proxy-addr` IP spoofing), 1 **High** (`body-parser` DoS), 1 **Moderate** (`qs`), evita fugas de `.env` en builds Docker y elimina credenciales de liga hardcodeadas sin alterar ni una sola ruta ni dato en MongoDB.

### Archivos afectados y capa
- `backend/package-lock.json` (`Infrastructure`) — `npm audit fix`
- `backend/.dockerignore` (`Infrastructure`) — excluir `.env`, `*.env`, `*.env.*`, `test/`, `scripts/`
- `backend/Dockerfile` (`Infrastructure`) — usar `npm ci --omit=dev`, crear `/app/data` con permisos para `node`, cambiar a `USER node`
- `backend/scripts/seed-league.js` (`Infrastructure`) — remover `EL MUNDO DE JULITO`, `LIG-9876` y `pin: "9876"` hardcodeados; leerlos de `SEED_LEAGUE_ID`, `SEED_LEAGUE_NAME`, `SEED_LEAGUE_PIN`
- `backend/src/server.js` (`WebAPI`) — `process.exit(1)` en fallo de `startServer()` + manejo de `SIGTERM`/`SIGINT` cerrando servidor HTTP y `mongo.close()`
- `render.yaml` (`Infrastructure`) — cambiar `npm install` por `npm ci --omit=dev` y declarar `NODE_ENV=production`
- `backend/.gitignore` y tracking Git de `backend/data/leagues.json` (`Infrastructure`) — `git rm --cached backend/data/leagues.json` e ignorar `data/*.json` para no ensuciar el repo en desarrollo local

### Criterios de aceptación (`GIVEN / WHEN / THEN`)
- **GIVEN** el lockfile actualizado del backend, **WHEN** se ejecuta `cd backend && npm audit --omit=dev`, **THEN** reporta 0 vulnerabilidades high/critical y `npm test` pasa al 100%.
- **GIVEN** un archivo `backend/.env` presente en disco, **WHEN** se construye la imagen Docker (`docker build ./backend`), **THEN** `.env` no entra al contexto de build y el proceso corre como usuario no-root (`node`).
- **GIVEN** que el proceso Node recibe `SIGTERM` (deploy en Render), **WHEN** está sirviendo tráfico con MongoDB conectado, **THEN** deja de aceptar nuevas conexiones, cierra `mongo.close()` y termina limpiamente con código `0`.

### Riesgos y Rollback
- **Acción operativa recomendada para Angel:** Si la liga `LIG-9876` (`EL MUNDO DE JULITO`) está activa en producción con PIN `9876`, rotar su PIN manualmente en Atlas tras limpiar `seed-league.js`.
- **Rollback:** `git revert` del commit de Fase 0; cero impacto en datos de Atlas.

---

## FASE 1 (P0-B) — Endurecimiento del Backend e Integridad Mongo-First (Retrocompatible) ✅ Completada

**Por qué segundo:** Cierra el bypass de fuerza bruta de PIN (60× más rápido vía `/sync`), elimina crashes 500 por inputs hostiles, impide que fallos de MongoDB corrompan la RAM del servidor y bloquea el DoS por creación masiva de ligas — **manteniendo el 100% del contrato esperado por los APKs actuales**.

### Guardarraíles de retrocompatibilidad (CRÍTICO)
- **NO** reducir el límite de tráfico legítimo de `/sync` por debajo de lo que consumen los APKs viejos (polling cada 12s = 75 req/15 min). En su lugar, separar el limitador en:
  1. `failedPinLimiter`: cuenta **solo respuestas `401`** (PIN incorrecto) con máximo `10` fallos / 15 min por IP **y** por `leagueId`, compartido entre `/join`, `/sync`, `/:id/matches`, `/:id/participants` y `DELETE`.
  2. `syncTrafficLimiter`: tope generoso (p. ej. 300 req/15 min por IP) para tráfico autenticado.
- **NO** eliminar todavía `req.query.pin` en `DELETE` (se mantiene deprecado con log de aviso sin imprimir el PIN, para no romper APKs viejos).
- **NO** rechazar en `/sync` partidas antiguas válidas con fecha sin `Z` o sin `team1Members` si `team1DisplayName` permite derivarlos (mismo fallback que `rankings.js`).

### Archivos afectados y capa
- `backend/src/middleware/rateLimit.js` (`WebAPI`) — añadir tope máximo de claves (`maxKeys`, p. ej. 10,000 con evicción FIFO para evitar OOM), `keyGenerator` configurable y modo `onlyOnStatus` (ej. contar solo `401`).
- `backend/src/validation/leagueSchemas.js` *(nuevo)* (`Application`) — validadores puros sin dependencias nuevas:
  - `validateString(val, { min, max })` (evita `TypeError` si llega objeto/número).
  - `validateLeagueCreate`, `validateJoin`, `validateParticipant`, `validateMatch` (`score1`/`score2` enteros `0..10000`, `winnerTeam ∈ {1,2}`, `members` 1..10 strings ≤ 60 chars), `validateSyncPayload` (tope de 2,000 partidas, exige `pin` incluso al crear nueva liga), `validateMonthQuery` (`year` `1970..2100`, `month` `1..12`).
- `backend/src/routes/leagues.js` (`WebAPI`) — conectar validadores en todas las rutas (incluido `/sync`), añadir `createLeagueLimiter` (20 req/15 min por IP) en `POST /api/leagues`, aplicar `failedPinLimiter` a todas las rutas con PIN, usar `crypto.randomInt(1000, 10000)` excluyendo `"1234"` y comparación de PIN en tiempo constante (`crypto.timingSafeEqual` sobre hash SHA-256).
- `backend/src/routes/rankings.js` (`WebAPI`) — validar `year`/`month` (400 si formato inválido) y no reflejar valores arbitrarios/arrays sin sanitizar.
- `backend/src/models/store.js` (`Infrastructure` / `Domain`) —
  - **Mongo-first write:** en `createLeague`, `syncLeague`, `addParticipant`, `removeParticipant`, `recordMatch`, construir clon candidato, ejecutar `await this._upsertInMongo(col, candidate)` **antes** de actualizar `this.leagues.set(...)`. Si Atlas falla, la RAM no queda sucia.
  - **No bloquear event loop en producción:** en `save()`, omitir `saveLocal()` (`fs.writeFileSync`) cuando `mongo.connected === true`.
  - **Eliminar fallback `"1234"`** en `syncLeague` (línea 207) y `recordMatch` (línea 282).
  - **Eliminar bucle infinito de ID:** `createLeague` intenta hasta 20 veces `LIG-<4 dígitos>` vía `crypto.randomInt(1000, 10000)` y hace fallback a `LIG-<6 hex>` vía `crypto.randomBytes(3)`.
  - **Normalización coherente de participantes:** deduplicación usando `removeDiacritics(p.toLowerCase())` y `await` explícito al llamar `addParticipant` dentro de `syncLeague`.
- `backend/test/api.test.js` (`Tests`) — ampliar batería (Red → Green): payloads maliciosos (objetos/números → 400, jamás 500), `/sync` con partidas inválidas → 400, `/sync` sin PIN en liga nueva → 401/400, bloqueo de `failedPinLimiter` tras 10 intentos fallidos en `/sync` sin bloquear tráfico válido, integridad RAM ante fallo simulado de persistencia, determinismo del PIN sin `"1234"`.

### Criterios de aceptación (`GIVEN / WHEN / THEN`)
- **GIVEN** un cliente envía `{ "name": 123 }` o `{ "name": {} }` a `POST /api/leagues` o `POST /:id/participants`, **WHEN** el servidor procesa la petición, **THEN** responde `400` con JSON estructurado (nunca `500`).
- **GIVEN** un atacante envía 11 intentos con PIN incorrecto a `POST /api/leagues/sync` o `POST /:id/matches`, **WHEN** llega el intento 11, **THEN** responde `429` con `Retry-After`; mientras otro cliente con PIN válido sigue sincronizando con `200`.
- **GIVEN** un payload `/sync` con una liga existente y MongoDB rechaza `updateOne`, **WHEN** el endpoint devuelve `500`, **THEN** `store.getLeagueById(id)` conserva el estado anterior exacto sin mutación parcial.
- **GIVEN** un APK antiguo enviando `POST /api/leagues/sync` o `DELETE /api/leagues/:id?pin=...` con datos reales válidos, **WHEN** llega al backend desplegado, **THEN** responde `200` exactamente igual que antes.

### Despliegue y Rollback
- Desplegar backend en Render → verificar `GET /health` (`database: "mongodb"`) → probar lectura y sync de una liga real desde la app desplegada.
- **Rollback:** redeploy del commit previo en Render (sin cambios de esquema en Atlas).

---

## FASE 2 (P0-C) — Corrección de Bugs Silenciosos Críticos en Flutter ✅ Completada

**Por qué tercero:** Resuelve los 5 bugs confirmados que hoy pierden partidas, pierden configuración de Modo Casual, dejan el "Ranking General del Servidor" vacío y exponen a `LeagueService` a race conditions al arrancar.

### Guardarraíles de datos locales
- Todas las partidas, ligas y clasificaciones ya almacenadas en `SharedPreferences` se leen sin migración destructiva.
- Si una liga sincronizada viene sin `pin` desde el servidor, jamás sobrescribir el `pin` local con `'1234'`.

### Archivos afectados y capa
- `lib/models/game_state.dart` (`Domain`) —
  - Separar defaults de nombres personalizados en `GameState.casual()` (`preserveCustomNames: isLeagueMode`) para que Modo Casual restaure `nombreE1`, `nombreE2` y `metaPuntos` guardados.
  - Bloquear `agregarRonda` cuando `isGameOver == true` (evita cambiar retroactivamente el ganador).
- `lib/screens/domino_game_screen.dart` (`Delivery`) —
  - Eliminar la bandera redundante `_resultRecorded` que quedaba pegada en `true` tras reiniciar desde `WinnerDialog` o deshacer la ronda decisiva; confiar en `widget.gameState.consumeJustFinished()` como fuente única de transición.
  - Mover la apertura de `WinnerDialog` al listener de `DominoGameScreen` (resuelve el `showDialog` sobre `context` popeado en `PointsDialog` y cubre ganar cambiando `metaPuntos` en `SettingsDialog`).
  - Generar `LeagueMatch.id` con identificador único (`match_<timestamp>_<randomSecureHex>` o UUID v4) en vez de `millisecondsSinceEpoch`.
  - Hacer `dispose()` del `GameState` cuando la pantalla es dueña de la instancia.
- `lib/widgets/points_dialog.dart` y `lib/widgets/winner_dialog.dart` (`Delivery`) —
  - Quitar `showDialog(WinnerDialog)` de `PointsDialog._save()`.
  - Corregir el texto contradictorio de Modo Casual en `WinnerDialog` (`"Guardado en este dispositivo (no afecta ligas)"`).
- `lib/models/league.dart` y `lib/models/leaderboard_entry.dart` (`Domain`) —
  - Casteos seguros `(map[...] as num?)?.toInt() ?? 0` en todos los `fromMap`.
  - En `League.fromMap`: `pin: map['pin'] as String? ?? ''` (nunca inventar `'1234'`).
  - Deduplicación de `addParticipant` usando `NameParser.removeDiacritics(...toLowerCase())`.
- `lib/services/league_service.dart` (`Application`) —
  - Añadir `late final Future<void> _loadFuture;` y hacer `await _loadFuture` al inicio de todos los métodos que leen/mutan `_leagues` (evita que `loadData()` borre ligas recién creadas/unidas).
  - Reemplazar el descarte silencioso en `_syncMatchToServer` (`if (_isSyncingServer) return;`) por cola/reintento de partidas pendientes (`_pendingMatches` o re-disparo al liberar el lock).
  - Respetar el semáforo `_isSyncingServer` en `syncAllLeaguesWithServer()` y devolver `bool` con resultado real.
  - Usar `Random.secure()` para generar PINs aleatorios (excluyendo `'1234'`), alineado con [league_dialogs.dart](file:///c:/Users/DELL/Desktop/wordspace/domino/lib/widgets/league_dialogs.dart#L131).
- `lib/services/api_client.dart` (`Infrastructure`) —
  - Añadir soporte opcional `year`/`month` en `fetchGlobalTeams`, `fetchGlobalPlayers` y nuevo `fetchLeagueRankings(leagueId, {year, month})`.
  - Distinguir error de red vs lista vacía en `fetchServerLeagues()` (devolver `List<Map<String, dynamic>>?`, `null` en error de conexión).
- `lib/screens/league/global_ranking_screen.dart` (`Delivery`) —
  - Consultar el backend vía `LeagueService` / `ApiClient` al abrir el Ranking General del Servidor (y por liga con filtro mensual), con fallback offline transparente a los datos locales e indicador visual claro (`Servidor` / `Solo local`).
  - Esperar `LeagueService.ensureLoaded()` antes de inicializar `_selectedMonth`.
- `lib/screens/league/league_manager_screen.dart` (`Delivery`) —
  - Manejar `null` de `fetchServerLeagues()` activando `_serverError` y el botón **Reintentar**; proteger todos los `setState` post-`await` con `if (!mounted) return;`.
- `lib/screens/leaderboard_screen.dart` (`Delivery`) —
  - Mostrar SnackBar verde o amarillo según el `bool` real de `syncAllLeaguesWithServer()`.
- `lib/screens/league/match_setup_screen.dart` y `lib/widgets/team_card_widget.dart` (`Delivery`) —
  - `MatchSetupScreen._addQuickParticipant` agrega al `widget.league.id` (no a `activeLeague`).
  - `TeamCardWidget` deja `readOnly: widget.gameState.isLeagueMode` para que el nombre oficial no se desincronice de `team1Members`/`team2Members`.
- `test/` (`Tests`) —
  - Nuevos tests TDD: `GameState.casual()` persistencia de nombres/meta; widget test de `DominoGameScreen` + `WinnerDialog` registrando 2 partidas consecutivas; `LeagueService` espera `_loadFuture` y no pierde partidas si coincide con sync; `LeagueManagerScreen` muestra error cuando `fetchServerLeagues` falla; corregir formato en `test/league_service_test.dart`.

### Criterios de aceptación (`GIVEN / WHEN / THEN`)
- **GIVEN** una partida terminada en `DominoGameScreen`, **WHEN** el usuario pulsa "Iniciar Nueva Partida" en `WinnerDialog` y completa una 2ª partida, **THEN** ambas partidas quedan registradas en `LeaderboardService` y (en modo liga) en `LeagueService`.
- **GIVEN** Modo Casual con nombres `"Ana y Luis"` vs `"Pedro y Juan"` y `metaPuntos = 100`, **WHEN** el usuario sale y vuelve a entrar a `GameState.casual()`, **THEN** conserva los nombres personalizados y la meta `100` junto con sus rondas.
- **GIVEN** un dispositivo sin ligas locales pero con conexión al backend, **WHEN** abre "Ver Ranking General del Servidor" (`GlobalRankingScreen`), **THEN** muestra el ranking real del servidor y permite filtrar por mes.
- **GIVEN** `LeagueManagerScreen` sin conexión a internet, **WHEN** carga la pestaña "En el Servidor", **THEN** muestra el estado de error con botón "Reintentar" y no crashea si el usuario navega atrás antes del timeout.

### Despliegue y Rollback
- Validar localmente `flutter analyze`, `flutter test` y `dart format --output=none --set-exit-if-changed lib test`.
- Push a `main` → GitHub Actions genera Web y APK release.
- **Rollback:** `git revert` en `main` (los datos locales en `SharedPreferences` siguen 100% compatibles).

---

## FASE 3 (P1) — Sincronización Completa, Eficiencia de Red, Pulido y CI Confiable

**Por qué cuarto:** Cierra la desincronización de participantes entre dispositivos, elimina el consumo innecesario de batería/ancho de banda del polling cada 12s, corrige detalles visibles de producto y asegura que el CI jamás vuelva a dar falsos verdes.

### Archivos afectados y capa
- `lib/services/api_client.dart` y `lib/services/league_service.dart` (`Infrastructure` / `Application`) —
  - Reutilizar instancia única `http.Client` en `ApiClient`.
  - Sincronizar `addParticipant` y `removeParticipant` contra `POST/DELETE /api/leagues/:id/participants` (con PIN en body, tolerando offline).
  - En `_syncLeagueWithServer`, hacer merge también de `serverLeague.participants` y `serverLeague.name` sin perder datos locales.
- `lib/screens/league/league_home_screen.dart` (`Delivery`) —
  - Cambiar polling de `12s` a `45–60s` + sync al volver a primer plano (`WidgetsBindingObserver`) + eliminar la doble sincronización redundante en `_checkServerStatus`.
  - Prevenir overflows en filas de historial (`Expanded` + `TextOverflow.ellipsis`, igual en `rounds_history_widget.dart`).
- `backend/src/utils/rankings.js` y `backend/src/routes/rankings.js` (`Domain` / `WebAPI`) —
  - Soportar parámetro opcional `tzOffsetMinutes` (default `0` = UTC, 100% retrocompatible) si se elige unificación por zona horaria local del usuario (ver Decisión #3).
- Pulido de plataforma (`Delivery` / `Config`):
  - `android/app/src/main/AndroidManifest.xml`: `android:label="Dominó Score"`.
  - `android/app/build.gradle.kts`: limpiar `TODO` de plantilla.
  - `web/manifest.json`: nombre `"Dominó Score"`, descripción real y colores `#020617`.
  - `web/index.html`: retirar `maximum-scale=1.0, user-scalable=no`.
  - Quitar referencias al proveedor `"Render"` en textos de UI (`leaderboard_screen.dart`, `league_home_screen.dart`, `league_manager_screen.dart`).
- CI/CD (`Infra`):
  - `.github/workflows/flutter-build.yml`: quitar `continue-on-error: true` en deploy a Pages y Release; agregar `dart format --output=none --set-exit-if-changed lib test`; leer versión desde `pubspec.yaml` para el release en lugar de sobrescribir siempre `v1.0.0`.
  - `.github/workflows/backend-ci.yml`: agregar `npm audit --omit=dev --audit-level=high` y `curl -fsS -X POST "$RENDER_DEPLOY_HOOK"`.

### Criterios de aceptación (`GIVEN / WHEN / THEN`)
- **GIVEN** Dispositivo A agrega un participante en una liga sincronizada, **WHEN** Dispositivo B sincroniza esa liga, **THEN** el participante aparece automáticamente en Dispositivo B.
- **GIVEN** un error de formato Dart o vulnerabilidad `high/critical` en `backend`, **WHEN** se abre PR o push a `main`, **THEN** el pipeline de CI falla explícitamente (sin falsos verdes).

---

## FASE 4 (P1/P2) — Migración de PINs a Hash `scrypt` en MongoDB Atlas *(REQUIERE APROBACIÓN + BACKUP)*

**Por qué quinto:** Elimina el último riesgo grave de base de datos (PINs en texto plano en Atlas) **sin romper una sola liga existente ni ningún APK ya instalado**.

### Guardarraíl obligatorio de Migración (Protocolo ALPHA)
- **DETENER antes de ejecutar:** Requiere autorización escrita explícita de **Angel Luis Rosario** y **backup verificado en frío** de la colección `leagues` de MongoDB Atlas guardado fuera del repositorio.

### Estrategia Expand → Dual-Read → Migrate → Contract
1. **Backup previo:** Script de exportación read-only de la colección `leagues` a archivo local fuera de Git + conteo verificado de documentos y checksum.
2. **Expand + Dual-Read (`backend/src/utils/pinCrypto.js` + `store.js` + `routes/leagues.js`):**
   - Nuevas ligas guardan `pinHash` (`scrypt` + `salt` de 16 bytes) y **no** guardan campo `pin` en MongoDB.
   - `verifyPin(league, candidate)` soporta:
     - Si `league.pinHash` existe → verifica con `scrypt` + `timingSafeEqual`.
     - Si solo existe `league.pin` (documento legado) → verifica con `timingSafeEqual` y actualiza automáticamente el documento a `pinHash` + `$unset: { pin: "" }` (*lazy upgrade*).
   - En `POST /api/leagues/join`: tras validar el PIN enviado en `req.body.pin`, devuelve `{ ...toSafeLeague(league), pin: String(pin).trim() }` para que el cliente Flutter (APKs viejos y nuevos) siga guardando su PIN local sin romper el contrato.
3. **Migrate (opcional tras confirmar Dual-Read estable 48–72h en producción):**
   - Ejecutar script idempotente `backend/scripts/migrate-pins.js --dry-run` y luego `--apply` para migrar ligas inactivas restantes.
4. **Contract (en una versión futura cuando todos los dispositivos hayan actualizado):**
   - Retirar `req.query.pin` en `DELETE` y el soporte de lectura del campo `pin` legado.

### Criterios de aceptación (`GIVEN / WHEN / THEN`)
- **GIVEN** una liga creada antes de la migración (con `pin` en texto plano en Atlas), **WHEN** un usuario se une vía `POST /api/leagues/join` con su PIN actual, **THEN** accede con `200`, su documento se actualiza a `pinHash` y el campo `pin` se elimina de MongoDB sin perder partidas ni participantes.
- **GIVEN** una liga nueva creada vía `POST /api/leagues`, **WHEN** se inspecciona su documento en MongoDB, **THEN** contiene `pinHash` + `pinSalt` y ningún campo `pin` en texto plano.

---

## FASE 5 (P2) — Refactorización Arquitectónica Gradual (Regla BETA y Escalabilidad)

**Por qué al final:** Con producción segura, libre de bugs críticos y con suites TDD robustas, se paga la deuda estructural sin riesgo de regresiones.

### Alcance (dividido en PRs pequeños e independientes)
1. **Flutter — Descomposición de pantallas monolíticas (SRP):**
   - Extraer widgets cohesivos de `league_home_screen.dart` (971 LOC), `league_manager_screen.dart` (863 LOC), `global_ranking_screen.dart` (861 LOC, unificando podios y listas) y `league_dialogs.dart` (724 LOC).
   - Consolidar `LeaderboardScreen` y `GlobalRankingScreen` en una sola pantalla de clasificaciones coherente (tab Dispositivo vs Servidor + selector mensual).
2. **Flutter — Inversión de dependencias (Regla BETA):**
   - Definir contratos `ILeagueRepository` / `ILeaderboardRepository` en `Domain`/`Application`, mover `SharedPreferences` y `ApiClient` a `Infrastructure`, eliminar llamadas directas de `screens/` a `ApiClient` y retirar `resetForTesting()` al soportar DI en tests.
3. **Backend — Persistencia directa en MongoDB + Contratos estándar ALR:**
   - Dividir `store.js` (God Object) en `LeagueRepository` (consultas/actualizaciones atómicas `$push`/`$set` directas en MongoDB sin depender de tener toda la BD en RAM → habilita escalado horizontal) y `LeagueService`.
   - Mantener `/api/*` como alias retrocompatible mientras se introducen rutas versionadas `/api/v1/*` con formato de error RFC 7807 (`ProblemDetails`).
   - Añadir suite de integración con MongoDB en CI (contenedor `mongo:7` en `backend-ci.yml`).

---

## Decisiones Requeridas de Angel Luis Rosario antes de Iniciar

1. **Orden de ejecución:** ¿Arrancamos ejecutando **Fase 0 + Fase 1** (backend primero, verificación en producción) y luego **Fase 2** (Flutter), o prefieres ejecutar una fase a la vez?
2. **Privacidad de `GET /api/leagues/:id` (Fase 1/3):** Hoy cualquier persona con el ID (`LIG-####`) puede leer participantes e historial sin PIN. ¿Lo mantenemos público de solo lectura (100% compatible con APKs actuales) o planificamos exigir PIN/token también para lectura en una versión posterior?
3. **Zona horaria en rankings mensuales (Fase 3):** ¿Preferimos **Opción A** (parámetro opcional `tzOffsetMinutes` en backend, default `0` UTC, para que el servidor coincida con el mes local del jugador sin romper clientes viejos) o **Opción B** (estandarizar 100% en UTC en cliente y servidor)?
4. **Migración de BD (Fase 4):** Confirmar que cuentas con acceso para hacer backup de MongoDB Atlas antes de aprobar Fase 4 (y rotar el PIN de `LIG-9876` si esa liga está viva en Atlas).
