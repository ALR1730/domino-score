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

