# Spec ALPHA — Fase 5B: Inversión de Dependencias (Regla BETA) y Consolidación de Rankings

## Alcance por Capa Arquitectónica

1. **`Domain` (`lib/domain/repositories/` — cero dependencias externas):**
   - `league_repository.dart`: contrato `ILeagueRepository` + value objects (`RankingSnapshot`, `LocalLeaguesState`, `JoinRemoteResult`, `DeleteRemoteResult`).
   - `leaderboard_repository.dart`: contrato `ILeaderboardRepository` + `LocalLeaderboardState`.
   - Ningún archivo en `lib/domain/` importa `flutter`, `http` ni `shared_preferences`.

2. **`Infrastructure` (`lib/infrastructure/`):**
   - `network/api_client.dart`: cliente HTTP REST con reutilización de `http.Client` por `Zone` (re-exportado en `lib/services/api_client.dart` para compatibilidad de pruebas unitarias HTTP).
   - `repositories/league_repository_impl.dart`: implementa `ILeagueRepository` usando `SharedPreferences` (claves `domino_leagues_registry_v1`, `domino_active_league_id_v1`) y `ApiClient`.
   - `repositories/leaderboard_repository_impl.dart`: implementa `ILeaderboardRepository` usando `SharedPreferences` (claves `domino_leaderboard_teams_v1`, `domino_leaderboard_players_v1`).

3. **`Application` (`lib/services/`):**
   - `league_service.dart` y `leaderboard_service.dart`: dependen exclusivamente de `ILeagueRepository` / `ILeaderboardRepository`, exponen constructores con DI (`withRepository`, `isolated`) y eliminan `resetForTesting()`.

4. **`Delivery` (`lib/screens/`, `lib/widgets/`):**
   - Consolidar `LeaderboardScreen` y `GlobalRankingScreen` en `GlobalRankingScreen` (modos `'En este Dispositivo'` y `'En el Servidor'` + filtro mensual en servidor + búsqueda), conservando `LeaderboardScreen` como wrapper delgado con `initialSource: RankingSource.device`.
   - Eliminar llamadas e imports directos de `ApiClient` y `SharedPreferences` en pantallas/widgets, recibiendo servicios inyectables opcionales.

5. **`Tests` (`test/`):**
   - Migrar `league_service_test.dart` y `screens_server_integration_test.dart` a `LeagueService.isolated()`.
   - Añadir `architecture_and_rankings_test.dart` con repositorios en memoria y guardarraíles estáticos BETA.

## Criterios de Aceptación (`GIVEN / WHEN / THEN`)

- **GIVEN** un repositorio en memoria que implementa `ILeagueRepository` o `ILeaderboardRepository`, **WHEN** se inyecta mediante `LeagueService.withRepository(...)` o `LeaderboardService.withRepository(...)`, **THEN** la aplicación opera sin `SharedPreferences` ni red HTTP y sin `resetForTesting()`.
- **GIVEN** la pantalla consolidada de clasificaciones, **WHEN** se abre desde `HeaderWidget`/`WinnerDialog` (`LeaderboardScreen`) inicia en `'En este Dispositivo'` con búsqueda y reinicio local; **WHEN** se abre desde `ModeSelectionScreen` (`GlobalRankingScreen`) inicia en `'En el Servidor'` con selector mensual (`tzOffsetMinutes`) y fallback local; en ambos casos el usuario puede alternar entre fuentes.
- **GIVEN** cualquier archivo en `lib/domain/` o `lib/screens/`/`lib/widgets/`, **WHEN** corre la auditoría BETA, **THEN** `lib/domain/` no tiene dependencias de infraestructura/Flutter y las pantallas/widgets no importan `api_client.dart` ni `shared_preferences`.

## Impacto en Producción / BD

- **Cero cambios en `backend/`** ni migraciones en MongoDB Atlas.
