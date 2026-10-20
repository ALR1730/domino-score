const express = require("express");
const router = express.Router();
const store = require("../models/store");
const rateLimit = require("../middleware/rateLimit");

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

// GET /api/leagues - Lista pública de ligas (sin PIN)
router.get("/", (req, res) => {
  const leagues = store.getAllLeaguesPublic();
  res.json({ success: true, leagues });
});

// POST /api/leagues - Crear nueva liga
router.post("/", (req, res) => {
  const { id, name, pin, initialParticipants } = req.body;
  if (!name || !name.trim()) {
    return res.status(400).json({ success: false, error: "El nombre de la liga es obligatorio." });
  }

  const league = store.createLeague({
    id,
    name,
    pin: pin || "1234",
    initialParticipants: initialParticipants || [],
  });

  res.status(201).json({ success: true, league: toSafeLeague(league) });
});

// POST /api/leagues/sync - Sincronizar liga completa y todas sus partidas.
// Requiere el PIN correcto cuando la liga ya existe en el servidor; el PIN
// almacenado en el servidor NUNCA se sobreescribe desde aquí.
router.post("/sync", syncLimiter, (req, res) => {
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

  const league = store.syncLeague(leagueData);
  if (!league) {
    return res.status(500).json({ success: false, error: "No se pudo sincronizar la liga." });
  }

  res.json({ success: true, league: toSafeLeague(league) });
});

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

const handleDelete = (req, res) => {
  const id = req.params.id || (req.body && req.body.id);
  const pin = (req.body && req.body.pin) || req.query.pin;
  if (!id) {
    return res.status(400).json({ success: false, error: "ID de la liga es requerido." });
  }
  const result = store.deleteLeague(id, pin);
  if (!result.success) {
    const isNotFound = result.error && result.error.includes("no encontrada");
    return res.status(isNotFound ? 404 : 401).json(result);
  }
  res.json({ success: true, message: "Liga eliminada correctamente." });
};

// DELETE /api/leagues/:id - Eliminar liga (admin con PIN)
router.delete("/:id", pinAttemptLimiter, handleDelete);

// POST /api/leagues/:id/delete - Soporte alternativo POST
router.post("/:id/delete", pinAttemptLimiter, handleDelete);

// POST /api/leagues/delete - Soporte POST con { id, pin } en el body
router.post("/delete", pinAttemptLimiter, handleDelete);

// POST /api/leagues/:id/participants - Agregar participante (requiere PIN)
router.post("/:id/participants", pinAttemptLimiter, (req, res) => {
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

  const updated = store.addParticipant(req.params.id, name);
  res.json({ success: true, participants: updated.participants });
});

// DELETE /api/leagues/:id/participants/:name - Eliminar participante (requiere PIN)
// Nota: Express ya decodifica los parámetros de ruta; no volver a llamar
// a decodeURIComponent (rompía con nombres que contienen "%" -> URIError).
router.delete("/:id/participants/:name", pinAttemptLimiter, (req, res) => {
  const pin = (req.body && req.body.pin) || req.query.pin;
  const league = store.getLeagueById(req.params.id);
  if (!league) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }
  if (!pinMatches(league, pin)) {
    return res.status(401).json({ success: false, error: "PIN incorrecto." });
  }

  const updated = store.removeParticipant(req.params.id, req.params.name);
  res.json({ success: true, participants: updated.participants });
});

// POST /api/leagues/:id/matches - Registrar partida oficial (requiere PIN)
router.post("/:id/matches", matchLimiter, (req, res) => {
  const { id: matchId, date, team1DisplayName, team2DisplayName, team1Members, team2Members, score1, score2, winnerTeam, leagueName, pin } = req.body;

  if (!team1Members || !team2Members || team1Members.length === 0 || team2Members.length === 0) {
    return res.status(400).json({ success: false, error: "Se requieren los miembros de ambos equipos." });
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

  const match = store.recordMatch(leagueId, {
    id: matchId,
    date,
    team1DisplayName,
    team2DisplayName,
    team1Members,
    team2Members,
    score1: Number(score1) || 0,
    score2: Number(score2) || 0,
    winnerTeam: Number(winnerTeam) || 1,
    leagueName,
    pin,
  });

  if (!match) {
    return res.status(404).json({ success: false, error: "Liga no encontrada." });
  }

  const league = store.getLeagueById(leagueId);
  res.status(201).json({ success: true, match, league: toSafeLeague(league) });
});

module.exports = router;
