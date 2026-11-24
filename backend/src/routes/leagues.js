const express = require("express");
const router = express.Router();
const store = require("../models/store");
const rateLimit = require("../middleware/rateLimit");
const asyncHandler = require("../middleware/asyncHandler");
const { generateRandomPin } = require("../utils/pin");
const {
  MAX_PARTICIPANT_LEN,
  cleanString,
  validateLeagueId,
  validatePin,
  validateCreateLeague,
  validateJoin,
  validateParticipant,
  validateMatchPayload,
  validateSyncPayload,
} = require("../validation/leagueSchemas");

const WINDOW_15_MIN_MS = 15 * 60 * 1000;

// Contabiliza únicamente intentos fallidos (401) para frenar fuerza bruta
// por IP y por liga sin interrumpir el polling válido de los clientes.
const failedPinByIpLimiter = rateLimit({
  windowMs: WINDOW_15_MIN_MS,
  max: 10,
  countOnlyStatus: 401,
});
const failedPinByLeagueLimiter = rateLimit({
  windowMs: WINDOW_15_MIN_MS,
  max: 25,
  countOnlyStatus: 401,
  keyGenerator: (req) => {
    const target =
      (req.params && req.params.id) ||
      (req.body && (req.body.id || req.body.nameOrId));
    return typeof target === "string" && target.trim()
      ? target.trim().toLowerCase()
      : null;
  },
});
const pinProtection = [failedPinByIpLimiter, failedPinByLeagueLimiter];

// Topes generales de tráfico por IP (anti-DoS)
const createLeagueLimiter = rateLimit({ windowMs: WINDOW_15_MIN_MS, max: 30 });
const joinTrafficLimiter = rateLimit({ windowMs: WINDOW_15_MIN_MS, max: 30 });
const syncTrafficLimiter = rateLimit({ windowMs: WINDOW_15_MIN_MS, max: 300 });
const matchTrafficLimiter = rateLimit({ windowMs: WINDOW_15_MIN_MS, max: 60 });

// Devuelve la liga SIN exponer secretos de PIN en la respuesta.
const toSafeLeague = (league) => {
  const safe = { ...league };
  delete safe.pin;
  delete safe.pinHash;
  delete safe.pinSalt;
  return safe;
};

// GET /api/leagues - Lista pública de ligas (sin PIN)
router.get("/", (req, res) => {
  const leagues = store.getAllLeaguesPublic();
  res.json({ success: true, leagues });
});

// POST /api/leagues - Crear nueva liga
router.post(
  "/",
  createLeagueLimiter,
  asyncHandler(async (req, res) => {
    const parsed = validateCreateLeague(req.body);
    if (!parsed.ok) {
      return res.status(parsed.status).json({ success: false, error: parsed.error });
    }

    const requestedPin = parsed.data.pin || generateRandomPin();

    const league = await store.createLeague({
      id: parsed.data.id,
      name: parsed.data.name,
      pin: requestedPin,
      initialParticipants: parsed.data.initialParticipants,
    });

    // El creador (única vez, igual que /join) recibe el PIN en claro que quedó protegido.
    res.status(201).json({
      success: true,
      league: toSafeLeague(league),
      pin: requestedPin,
    });
  })
);

// POST /api/leagues/sync - Sincronizar liga completa y todas sus partidas.
router.post(
  "/sync",
  syncTrafficLimiter,
  ...pinProtection,
  asyncHandler(async (req, res) => {
    const parsed = validateSyncPayload(req.body);
    if (!parsed.ok) {
      return res.status(parsed.status).json({ success: false, error: parsed.error });
    }

    const existing = store.getLeagueById(parsed.data.id);
    if (existing) {
      if (!(await store.verifyLeaguePin(existing, parsed.data.pin))) {
        return res.status(401).json({
          success: false,
          error:
            "PIN incorrecto para sincronizar la liga. Verifica la clave de acceso.",
        });
      }
    } else if (!parsed.data.pin) {
      return res.status(401).json({
        success: false,
        error: "Se requiere un PIN para crear la liga al sincronizar.",
      });
    }

    const league = await store.syncLeague(parsed.data);
    if (!league) {
      return res
        .status(500)
        .json({ success: false, error: "No se pudo sincronizar la liga." });
    }

    res.json({ success: true, league: toSafeLeague(league) });
  })
);

// POST /api/leagues/join - Validar PIN y unirse a liga desde otro dispositivo.
router.post(
  "/join",
  joinTrafficLimiter,
  ...pinProtection,
  asyncHandler(async (req, res) => {
    const parsed = validateJoin(req.body);
    if (!parsed.ok) {
      return res.status(parsed.status).json({ success: false, error: parsed.error });
    }

    const league = store.findLeagueByNameOrId(parsed.data.nameOrId);
    if (!league) {
      return res.status(404).json({
        success: false,
        error: "Liga no encontrada con el nombre o código ingresado.",
      });
    }

    if (!(await store.verifyLeaguePin(league, parsed.data.pin))) {
      return res
        .status(401)
        .json({ success: false, error: "Clave de acceso (PIN) incorrecta." });
    }

    const current = store.getLeagueById(league.id) || league;
    res.json({
      success: true,
      league: { ...toSafeLeague(current), pin: parsed.data.pin },
    });
  })
);

// GET /api/leagues/:id - Obtener liga con participantes y rankings (sin PIN)
router.get("/:id", (req, res) => {
  const idCheck = validateLeagueId(req.params.id);
  if (!idCheck.ok) {
    return res.status(idCheck.status).json({ success: false, error: idCheck.error });
  }

  const league = store.getLeagueById(idCheck.data);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }
  res.json({ success: true, league: toSafeLeague(league) });
});

function extractPinForDelete(req, routeLabel) {
  const bodyPin = req.body && req.body.pin;
  if (bodyPin !== undefined && bodyPin !== null) {
    return validatePin(bodyPin, { required: false });
  }
  if (req.query && req.query.pin !== undefined) {
    console.warn(`⚠️ Uso deprecado de PIN en query string en ${routeLabel}`);
    return validatePin(req.query.pin, { required: false });
  }
  return { ok: true, data: null };
}

const handleDelete = asyncHandler(async (req, res) => {
  const rawId =
    req.params.id !== undefined ? req.params.id : req.body && req.body.id;
  const idCheck = validateLeagueId(rawId);
  if (!idCheck.ok) {
    return res
      .status(400)
      .json({ success: false, error: "ID de la liga es requerido." });
  }

  const pinCheck = extractPinForDelete(req, "DELETE /api/leagues");
  if (!pinCheck.ok) {
    return res.status(pinCheck.status).json({ success: false, error: pinCheck.error });
  }

  const result = await store.deleteLeague(idCheck.data, pinCheck.data);
  if (!result.success) {
    const isNotFound = result.error && result.error.includes("no encontrada");
    return res.status(isNotFound ? 404 : 401).json(result);
  }
  res.json({ success: true, message: "Liga eliminada correctamente." });
});

// DELETE /api/leagues/:id - Eliminar liga (admin con PIN)
router.delete("/:id", ...pinProtection, handleDelete);

// POST /api/leagues/:id/delete - Soporte alternativo POST
router.post("/:id/delete", ...pinProtection, handleDelete);

// POST /api/leagues/delete - Soporte POST con { id, pin } en el body
router.post("/delete", ...pinProtection, handleDelete);

// POST /api/leagues/:id/participants - Agregar participante (requiere PIN)
router.post(
  "/:id/participants",
  ...pinProtection,
  asyncHandler(async (req, res) => {
    const idCheck = validateLeagueId(req.params.id);
    if (!idCheck.ok) {
      return res.status(idCheck.status).json({ success: false, error: idCheck.error });
    }

    const parsed = validateParticipant(req.body);
    if (!parsed.ok) {
      return res.status(parsed.status).json({ success: false, error: parsed.error });
    }

    const league = store.getLeagueById(idCheck.data);
    if (!league) {
      return res.status(404).json({ success: false, error: "Liga no encontrada." });
    }
    if (!(await store.verifyLeaguePin(league, parsed.data.pin))) {
      return res.status(401).json({ success: false, error: "PIN incorrecto." });
    }

    const updated = await store.addParticipant(idCheck.data, parsed.data.name);
    res.json({ success: true, participants: updated.participants });
  })
);

// DELETE /api/leagues/:id/participants/:name - Eliminar participante (requiere PIN)
router.delete(
  "/:id/participants/:name",
  ...pinProtection,
  asyncHandler(async (req, res) => {
    const idCheck = validateLeagueId(req.params.id);
    if (!idCheck.ok) {
      return res.status(idCheck.status).json({ success: false, error: idCheck.error });
    }

    const nameCheck = cleanString(req.params.name, {
      min: 1,
      max: MAX_PARTICIPANT_LEN,
      required: true,
      label: "Nombre de participante",
    });
    if (!nameCheck.ok) {
      return res.status(nameCheck.status).json({ success: false, error: nameCheck.error });
    }

    const pinCheck = extractPinForDelete(
      req,
      "DELETE /api/leagues/:id/participants"
    );
    if (!pinCheck.ok) {
      return res.status(pinCheck.status).json({ success: false, error: pinCheck.error });
    }

    const league = store.getLeagueById(idCheck.data);
    if (!league) {
      return res.status(404).json({ success: false, error: "Liga no encontrada." });
    }
    if (!(await store.verifyLeaguePin(league, pinCheck.data))) {
      return res.status(401).json({ success: false, error: "PIN incorrecto." });
    }

    const updated = await store.removeParticipant(idCheck.data, nameCheck.value);
    res.json({ success: true, participants: updated.participants });
  })
);

// POST /api/leagues/:id/matches - Registrar partida oficial (requiere PIN)
router.post(
  "/:id/matches",
  matchTrafficLimiter,
  ...pinProtection,
  asyncHandler(async (req, res) => {
    const idCheck = validateLeagueId(req.params.id);
    if (!idCheck.ok) {
      return res.status(idCheck.status).json({ success: false, error: idCheck.error });
    }

    const parsed = validateMatchPayload(req.body);
    if (!parsed.ok) {
      return res.status(parsed.status).json({ success: false, error: parsed.error });
    }

    const pinCheck = validatePin(req.body && req.body.pin, { required: false });
    if (!pinCheck.ok) {
      return res.status(pinCheck.status).json({ success: false, error: pinCheck.error });
    }

    const leagueId = idCheck.data;
    const existing = store.getLeagueById(leagueId);
    if (existing) {
      if (!(await store.verifyLeaguePin(existing, pinCheck.data))) {
        return res.status(401).json({
          success: false,
          error: "PIN incorrecto para registrar partidas en esta liga.",
        });
      }
    } else if (!pinCheck.data) {
      return res.status(401).json({
        success: false,
        error: "Se requiere un PIN para crear la liga al registrar la partida.",
      });
    }

    const match = await store.recordMatch(leagueId, {
      ...parsed.data,
      pin: pinCheck.data,
    });

    const league = store.getLeagueById(leagueId);
    res.status(201).json({ success: true, match, league: toSafeLeague(league) });
  })
);

module.exports = router;
