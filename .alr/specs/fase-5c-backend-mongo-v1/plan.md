# Spec ALPHA — Fase 5C: Persistencia Directa/Atómica en MongoDB + `/api/v1` RFC 7807 + CI `mongo:7`

## Alcance por Capa Arquitectónica (`backend/`)

1. **`Infrastructure` (`backend/src/db/mongo.js`, `backend/src/repositories/leagueRepository.js`):**
   - Índice aditivo `{ "matches.id": 1 }` en `leagues` para idempotencia rápida de partidas.
   - `LeagueRepository`: desacopla el acceso a datos (`MongoDB` directo o almacenamiento local `DATA_FILE`). En MongoDB usa consultas directas (`findOne`, proyecciones públicas sin secretos de PIN, regex escapada en `findByNameOrId`) y actualizaciones atómicas (`$addToSet`, `$pullAll`, `$push`, `$inc`, `$unset`) sin precargar toda la base de datos en RAM.

2. **`Application` (`backend/src/services/leagueService.js` + fachada `backend/src/models/store.js`):**
   - `LeagueService`: encapsula lógica de ligas, PIN (`scrypt` + lazy upgrade), participantes, merge de sincronización, registro de partidas y rankings.
   - `models/store.js`: fachada retrocompatible para scripts/tests existentes.

3. **`WebAPI / Delivery` (`backend/src/utils/problemDetails.js`, `rateLimit.js`, `routes/leagues.js`, `routes/rankings.js`, `server.js`):**
   - Respuestas de error RFC 7807 (`application/problem+json`: `type`, `title`, `status`, `detail`, `instance`) en `/api/v1/*`, manteniendo `{ success: false, error }` intacto en `/api/*` para retrocompatibilidad con APKs actuales.
   - Montaje dual `/api/v1/*` y alias `/api/*`.

4. **`CI & Tests` (`backend/test/v1-and-repository.test.js`, `backend/test/mongo-integration.test.js`, `backend/package.json`, `.github/workflows/backend-ci.yml`):**
   - Tests de paridad `/api/v1`, RFC 7807, operadores atómicos e idempotencia.
   - Suite de integración contra contenedor `mongo:7` en `backend-ci.yml` y soporte de `workflow_dispatch`.

## Criterios de Aceptación (`GIVEN / WHEN / THEN`)

- **GIVEN** un error `400`, `401`, `404`, `429` o `500` bajo `/api/v1/*`, **WHEN** responde el servidor, **THEN** devuelve `Content-Type: application/problem+json` con formato RFC 7807; **WHEN** el mismo error ocurre bajo `/api/*`, **THEN** responde `{ success: false, error }`.
- **GIVEN** MongoDB conectado y caché en memoria vacía (`localLeagues.clear()`), **WHEN** llegan lecturas, participantes o múltiples `recordMatch` concurrentes (incluyendo reintentos duplicados con el mismo `match.id`), **THEN** las consultas van directo a MongoDB y los contadores (`wins`, `matchesPlayed`, `totalPoints`) e idempotencia se conservan sin pérdida.

## Impacto en Producción / BD

- Cero migraciones destructivas sobre Atlas (únicamente índice aditivo `{ "matches.id": 1 }`).
