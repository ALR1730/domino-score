# Plan de Ejecución — Mejoras del Proyecto Dominó Score

> Fecha de creación: 2026-10-20
> Objetivo: resolver de forma ordenada todos los hallazgos de la revisión del código
> (seguridad, integridad de datos, duplicación, código muerto, tests y pulido),
> documentando cada cambio en [`CAMBIOS.md`](./CAMBIOS.md).

## Convenciones

- Cada fase se ejecuta completa, se documenta en `CAMBIOS.md` y se cierra con un commit.
- Ningún cambio rompe el contrato de la API sin que el cliente Flutter se actualice en la misma fase.
- Antes de cada fase se ejecutan las pruebas existentes para confirmar el estado base.

---

## Fase 1 — Seguridad del backend

| # | Tarea | Estado |
|---|-------|--------|
| 1.1 | `GET /api/leagues/:id` deja de devolver el `pin` en la respuesta | ✅ |
| 1.2 | `POST /api/leagues/sync` exige PIN válido para ligas existentes y nunca sobrescribe el PIN almacenado | ✅ |
| 1.3 | `POST /api/leagues/:id/matches` valida el PIN (el cliente ya lo envía) | ✅ |
| 1.4 | Endpoints de participantes exigen PIN | ✅ |
| 1.5 | CORS restringido a lista de orígenes permitidos (app web + dev), requests sin `Origin` (APK) siguen funcionando | ✅ |
| 1.6 | Deshabilitar `X-Powered-By` y añadir cabeceras básicas de seguridad | ✅ |
| 1.7 | Rate limiting simple en memoria para endpoints con PIN (join/delete) | ✅ |
| 1.8 | `/health` reduce la información expuesta | ✅ |

## Fase 2 — Integridad de datos del backend

| # | Tarea | Estado |
|---|-------|--------|
| 2.1 | `save()` persiste en MongoDB de forma **awaited** y solo la liga afectada; los errores llegan al cliente como 500 en vez de responder "success" antes de persistir | ✅ |
| 2.2 | Fallo fatal al arrancar si `MONGODB_URI` está configurado pero la conexión falla (se acabó el fallback silencioso al disco efímero de Render) | ✅ |
| 2.3 | Fix del doble `decodeURIComponent` en `DELETE /:id/participants/:name` (crash con `%` en nombres) | ✅ |
| 2.4 | Validación real en `recordMatch`: scores enteros ≥ 0, `winnerTeam` ∈ {1,2}, miembros como strings → 400 en vez de coerción silenciosa | ✅ |
| 2.5 | IDs de partida con `crypto.randomUUID()` (sin colisiones prácticas) | ✅ |
| 2.6 | Eliminar los blocklists de ligas de prueba del código de producción (`store.js`); los tests usarán `DATA_DIR` temporal | ✅ |
| 2.7 | Unificar la agregación de rankings del backend en un módulo puro `src/utils/rankings.js` (elimina la copia entre `store.js` y `rankings.js`) y pasar a bucketing de mes en **UTC** | ✅ |

## Fase 3 — Flutter: eliminación de duplicación

| # | Tarea | Estado |
|---|-------|--------|
| 3.1 | Extraer diálogos compartidos de ligas (crear/unirse/eliminar) a `lib/widgets/league_dialogs.dart`; eliminar las copias en `league_home_screen.dart` y `league_manager_screen.dart` | ⬜ |
| 3.2 | Unificar la agregación de rankings en un módulo puro `lib/services/ranking_calculator.dart` usado por `League` y `LeagueService` (elimina 3 copias) | ⬜ |
| 3.3 | Reemplazar `ListView(children: ...)` por `itemBuilder` en las listas grandes y añadir `key`s a hijos dinámicos | ⬜ |
| 3.4 | Chrome de diálogo común (fondo, radio, botones) en un helper | ⬜ |

## Fase 4 — Flutter: código muerto y bugs

| # | Tarea | Estado |
|---|-------|--------|
| 4.1 | Conectar `LeaderboardService` (hoy siempre vacío): registrar partidas casuales y de liga finalizadas en el tablero local "En este Dispositivo" | ⬜ |
| 4.2 | Eliminar `ApiClient.updateBaseUrl` y `checkHealth` sin llamadas; corregir README | ⬜ |
| 4.3 | Eliminar `_checkAndRecordMatch` vacío y `_matchRecorded` no leído en `GameState` | ⬜ |
| 4.4 | Eliminar la purga hardcodeada de ligas de prueba en `LeagueService.loadData` | ⬜ |
| 4.5 | Fix del bug de iconos de posiciones 2/3 en `global_ranking_screen.dart` | ⬜ |
| 4.6 | `ApiClient`: enviar fechas en UTC (`Z`), timeout como constante única, quitar el PIN del query string y el workaround de redeploy en `deleteLeague` | ⬜ |
| 4.7 | `domino_game_screen`: registrar la partida en la liga correcta (capturada al inicio) y mostrar el SnackBar según el resultado real del sync | ⬜ |

## Fase 5 — Tests e infra

| # | Tarea | Estado |
|---|-------|--------|
| 5.1 | Tests Dart de `GameState` (marcador, rondas, ganador, persistencia con `SharedPreferences.setMockInitialValues`) | ⬜ |
| 5.2 | Tests Dart de `NameParser` y del nuevo `ranking_calculator` | ⬜ |
| 5.3 | Tests Dart de `LeagueService` (crear/unir/eliminar, merge con servidor vía `http.runWithClient` + cliente falso) | ⬜ |
| 5.4 | Reescribir los tests del backend con `node:test` + `fetch` contra servidor en puerto efímero y `DATA_DIR` temporal (sin mutar el repo, sin dependencias nuevas); cubrir validaciones 400/401 y rankings | ⬜ |
| 5.5 | CI: clave de caché npm correcta (`package-lock.json`), filtros de path para los workflows | ⬜ |

## Fase 6 — Pulido

| # | Tarea | Estado |
|---|-------|--------|
| 6.1 | `pubspec.yaml`: quitar `cupertino_icons`, subir constraint de SDK al mínimo real, subir `flutter_lints` | ⬜ |
| 6.2 | Activar reglas de lint adicionales en `analysis_options.yaml` y corregir las violaciones | ⬜ |
| 6.3 | Quitar `fontFamily: 'Roboto'` hardcodeado (no declarado en pubspec) | ⬜ |
| 6.4 | PINs por defecto aleatorios en los diálogos de creación (cliente y servidor) en lugar de `1234` | ⬜ |
| 6.5 | `usesCleartextTraffic="false"` en el manifest de release; documentar firma de release | ⬜ |
| 6.6 | Actualizar `README.md` (API, variables de entorno, versiones) y archivar `walkthrough.md` obsoleto | ⬜ |

---

## Riesgos conocidos y mitigaciones

- **PIN estricto en sync/matches (Fase 1)**: dispositivos con un PIN local desincronizado dejarán de sincronizar hasta que el usuario se una de nuevo con el PIN correcto. El error devuelto lo explica. Mitigación aceptada: era exactamente el fallo de seguridad a corregir.
- **Mes en UTC (Fase 2)**: partidas cercanas a medianoche pueden moverse de mes al re-agrupar. Mitigación: documentado; el bucketing anterior era inconsistente según el servidor.
- **Refactor de pantallas Flutter (Fase 3)**: son archivos grandes; se mantiene comportamiento idéntico y se verifica con `flutter analyze` + tests + comparación manual de la UI afectada.
