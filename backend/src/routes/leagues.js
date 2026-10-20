const express = require("express");
const router = express.Router();
const store = require("../models/store");
const rateLimit = require("../middleware/rateLimit");
const asyncHandler = require("../middleware/asyncHandler");

// Fuerza bruta de PINs: muy poco espacio de maniobra (4 dígitos),
// así que limitamos los intentos por IP en los endpoints sensibles.
// OJO: /sync lo llama el cliente automáticamente cada pocos segundos,
// por eso tiene su propio límite (muy superior), solo como freno anti-DoS.
const pinAttemptLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 10 });
const syncLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 600 });
// Las partidas se registran al terminar cada juego: límite holgado,
// pero evita usar el endpoint como vector de fuerza bruta contra el PIN.
const matchLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 60 });

// Devuelve la liga SIN exponer el PIN en la respuesta.
const toSafeLeague = (league) => {
  const safe = { ...league };
  delete safe.pin;
  return safe;
};

const pinMatches = (league, pin) =>
  pin != null && String(pin).trim() === String(league.pin).trim();

/** Entero >= 0 desde string/número; null si no es válido. */
const toScore = (value, fallback = 0) => {
  if (value === undefined || value === null || value === "") return fallback;
  const n = Number(value);
  if (!Number.isInteger(n) || n < 0) return null;
  return n;
};

/** Lista de nombres no vacíos; null si el formato es inválido. */
const toMemberList = (value) => {
  if (!Array.isArray(value) || value.length === 0) return null;
  const members = value.map((m) => (typeof m === "string" ? m.trim() : "")).filter(Boolean);
  return members.length > 0 ? members : null;
};

// GET /api/leagues - Lista pública de ligas (sin PIN)
router.get("/", (req, res) => {
  const leagues = store.getAllLeaguesPublic();
  res.json({ success: true, leagues });
});

// Genera un PIN de 4 dígitos aleatorio (nunca el adivinable "1234").
const randomPin = () => String(1000 + Math.floor(Math.random() * 9000));

// POST /api/leagues - Crear nueva liga
router.post("/", asyncHandler(async (req, res) => {
  const { id, name, pin, initialParticipants } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, error: "El nombre de la liga es obligatorio." });
  }

  const requestedPin = pin && String(pin).trim() ? String(pin).trim() : randomPin();

  const league = await store.createLeague({
    id,
    name,
    pin: requestedPin,
    initialParticipants: initialParticipants || [],
  });

  // El creador (única vez, igual que /join) recibe el PIN que quedó guardado.
  res.status(201).json({
    success: true,
    league: toSafeLeague(league),
    pin: league.pin,
  });
}));

// POST /api/leagues/sync - Sincronizar liga completa y todas sus partidas.
// Requiere el PIN correcto cuando la liga ya existe en el servidor; el PIN
// almacenado en el servidor NUNCA se sobreescribe desde aquí.
router.post("/sync", syncLimiter, asyncHandler(async (req, res) => {
  const leagueData = req.body;
  if (!leagueData || !leagueData.id) {
    return res.status(400).json({ success: false, error: "Datos de liga requeridos (incluyendo id)." });
  }

  const existing = store.getLeagueById(String(leagueData.id).trim());
  if (existing && !pinMatches(existing, leagueData.pin)) {
    return res.status(401).json({
      success: false,
      error: "PIN incorrecto para sincronizar la liga. Verifica la clave de acceso.",
    });
  }

  const league = await store.syncLeague(leagueData);
  if (!league) {
    return res.status(500).json({ success: false, error: "No se pudo sincronizar la liga." });
  }

  res.json({ success: true, league: toSafeLeague(league) });
}));

// POST /api/leagues/join - Validar PIN y unirse a liga desde otro dispositivo.
// (Es el único endpoint que devuelve el PIN: solo responde con él a quien ya
// lo acertó, y el cliente lo necesita para sincronizar/eliminar la liga.)
router.post("/join", pinAttemptLimiter, (req, res) => {
  const { nameOrId, pin } = req.body;
  if (!nameOrId || !pin) {
    return res.status(400).json({ success: false, error: "Nombre/código de liga y PIN son requeridos." });
  }

  const league = store.findLeagueByNameOrId(nameOrId);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada con el nombre o código ingresado." });
  }

  if (!pinMatches(league, pin)) {
    return res.status(401).json({ success: false, error: "Clave de acceso (PIN) incorrecta." });
  }

  res.json({ success: true, league });
});

// GET /api/leagues/:id - Obtener liga con participantes y rankings (sin PIN)
router.get("/:id", (req, res) => {
  const league = store.getLeagueById(req.params.id);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }
  res.json({ success: true, league: toSafeLeague(league) });
});

const handleDelete = asyncHandler(async (req, res) => {
  const id = req.params.id || (req.body && req.body.id);
  const pin = (req.body && req.body.pin) || req.query.pin;
  if (!id) {
    return res.status(400).json({ success: false, error: "ID de la liga es requerido." });
  }
  const result = await store.deleteLeague(id, pin);
  if (!result.success) {
    const isNotFound = result.error && result.error.includes("no encontrada");
    return res.status(isNotFound ? 404 : 401).json(result);
  }
  res.json({ success: true, message: "Liga eliminada correctamente." });
});

// DELETE /api/leagues/:id - Eliminar liga (admin con PIN)
router.delete("/:id", pinAttemptLimiter, handleDelete);

// POST /api/leagues/:id/delete - Soporte alternativo POST
router.post("/:id/delete", pinAttemptLimiter, handleDelete);

// POST /api/leagues/delete - Soporte POST con { id, pin } en el body
router.post("/delete", pinAttemptLimiter, handleDelete);

// POST /api/leagues/:id/participants - Agregar participante (requiere PIN)
router.post("/:id/participants", pinAttemptLimiter, asyncHandler(async (req, res) => {
  const { name, pin } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, error: "Nombre de participante requerido." });
  }

  const league = store.getLeagueById(req.params.id);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }
  if (!pinMatches(league, pin)) {
    return res.status(401).json({ success: false, error: "PIN incorrecto." });
  }

  const updated = await store.addParticipant(req.params.id, name);
  res.json({ success: true, participants: updated.participants });
}));

// DELETE /api/leagues/:id/participants/:name - Eliminar participante (requiere PIN)
// Nota: Express ya decodifica los parámetros de ruta; no volver a llamar
// a decodeURIComponent (rompía con nombres que contienen "%" -> URIError).
router.delete("/:id/participants/:name", pinAttemptLimiter, asyncHandler(async (req, res) => {
  const pin = (req.body && req.body.pin) || req.query.pin;
  const league = store.getLeagueById(req.params.id);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }
  if (!pinMatches(league, pin)) {
    return res.status(401).json({ success: false, error: "PIN incorrecto." });
  }

  const updated = await store.removeParticipant(req.params.id, req.params.name);
  res.json({ success: true, participants: updated.participants });
}));

// POST /api/leagues/:id/matches - Registrar partida oficial (requiere PIN)
router.post("/:id/matches", matchLimiter, asyncHandler(async (req, res) => {
  const { id: matchId, date, team1DisplayName, team2DisplayName, team1Members, team2Members, score1, score2, winnerTeam, leagueName, pin } = req.body;

  const members1 = toMemberList(team1Members);
  const members2 = toMemberList(team2Members);
  if (!members1 || !members2) {
    return res.status(400).json({ success: false, error: "Se requieren los miembros de ambos equipos." });
  }

  const s1 = toScore(score1);
  const s2 = toScore(score2);
  if (s1 === null || s2 === null) {
    return res.status(400).json({ success: false, error: "Los puntajes deben ser enteros mayores o iguales a 0." });
  }

  const winner = Number(winnerTeam);
  if (winner !== 1 && winner !== 2) {
    return res.status(400).json({ success: false, error: "winnerTeam debe ser 1 o 2." });
  }

  const leagueId = String(req.params.id).trim();
  const existing = store.getLeagueById(leagueId);
  if (existing) {
    if (!pinMatches(existing, pin)) {
      return res.status(401).json({ success: false, error: "PIN incorrecto para registrar partidas en esta liga." });
    }
  } else if (!pin || !String(pin).trim()) {
    // Auto-creación de la liga: exige un PIN explícito, nunca se crea sin clave.
    return res.status(401).json({ success: false, error: "Se requiere un PIN para crear la liga al registrar la partida." });
  }

  const match = await store.recordMatch(leagueId, {
    id: matchId,
    date,
    team1DisplayName,
    team2DisplayName,
    team1Members: members1,
    team2Members: members2,
    score1: s1,
    score2: s2,
    winnerTeam: winner,
    leagueName,
    pin,
  });

  const league = store.getLeagueById(leagueId);
  res.status(201).json({ success: true, match, league: toSafeLeague(league) });
}));

module.exports = router;
